import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/api/catalog_api.dart';
import '../../core/api/watch_api.dart';
import '../../core/player/player_service.dart';
import '../../core/player/subtitle_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/episode.dart';
import '../../shared/models/media.dart';
import '../../ui/focus/tv_focusable.dart';
import '../../ui/focus/tv_keys.dart';

bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

String _fmt(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  final mm = m.toString().padLeft(2, '0'), ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

class WatchPage extends StatefulWidget {
  final String animeId;
  final String episodeId;
  const WatchPage({super.key, required this.animeId, required this.episodeId});
  @override
  State<WatchPage> createState() => _WatchPageState();
}

class _WatchPageState extends State<WatchPage> {
  final _watchApi = WatchApi();
  final _catalog = CatalogApi();

  bool _loading = true;
  String? _error;
  WatchData? _wd;
  List<Segment> _segments = const [];
  Map<String, String> _headers = const {};
  String? _prevId, _nextId;
  int? _fileDuration;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final wd = await _watchApi.watch(widget.animeId, widget.episodeId);
      if (wd.hlsUrl == null || wd.hlsUrl!.isEmpty) {
        setState(() { _error = 'Aucun fichier disponible.'; _loading = false; });
        return;
      }
      final headers = await ApiClient.instance.getVideoHeaders();
      final segs = await _watchApi.segments(widget.episodeId);
      final fileDur = wd.sourceId != null ? await _watchApi.hlsDuration(wd.sourceId!) : null;
      _computeAdjacent();
      if (!mounted) return;
      setState(() { _wd = wd; _headers = headers; _segments = segs; _fileDuration = fileDur; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Impossible de charger la vidéo.'; _loading = false; });
    }
  }

  Future<void> _computeAdjacent() async {
    try {
      final d = await _catalog.animeDetail(widget.animeId);
      final playable = d.episodes.where((e) => d.hasFile(e.id)).toList()
        ..sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
      final idx = playable.indexWhere((e) => e.id == widget.episodeId);
      if (idx < 0 || !mounted) return;
      setState(() {
        _prevId = idx > 0 ? playable[idx - 1].id : null;
        _nextId = idx < playable.length - 1 ? playable[idx + 1].id : null;
      });
    } catch (_) {}
  }

  void _go(String episodeId) => context.pushReplacement('/watch/${widget.animeId}/$episodeId');

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: AppTheme.foreground)));
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 22)),
            const SizedBox(height: 20),
            TvFocusable(autofocus: true, onSelect: () => context.pop(), builder: (_, f) => _pill('Retour', f)),
          ]),
        ),
      );
    }
    if (_isDesktop) {
      return _DesktopStub(url: _wd!.hlsUrl!, onBack: () => context.pop());
    }
    return _Player(
      wd: _wd!,
      headers: _headers,
      segments: _segments,
      fileDurationSeconds: _fileDuration,
      onBack: () => context.pop(),
      onPrev: _prevId == null ? null : () => _go(_prevId!),
      onNext: _nextId == null ? null : () => _go(_nextId!),
      saveProgress: (pos, dur, finished) => _watchApi.saveProgress(
        widget.episodeId, animeId: widget.animeId, positionSeconds: pos, durationSeconds: dur, finished: finished),
    );
  }

  static Widget _pill(String label, bool focused) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: focused ? AppTheme.primary : AppTheme.materialLight16,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Text(label, style: TextStyle(color: focused ? AppTheme.primaryForeground : AppTheme.foreground, fontSize: 22, fontWeight: FontWeight.w600)),
      );
}

// ── Lecteur ──────────────────────────────────────────────────────────────────

class _Player extends StatefulWidget {
  final WatchData wd;
  final Map<String, String> headers;
  final List<Segment> segments;
  final int? fileDurationSeconds;
  final VoidCallback onBack;
  final VoidCallback? onPrev, onNext;
  final Future<void> Function(int pos, int dur, bool finished) saveProgress;
  const _Player({
    required this.wd,
    required this.headers,
    required this.segments,
    required this.onBack,
    required this.saveProgress,
    this.fileDurationSeconds,
    this.onPrev,
    this.onNext,
  });
  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> {
  final _watchApi = WatchApi();
  late final PlayerService _svc;
  late final SubtitleController _subs;
  final _seekFocus = FocusNode(debugLabel: 'seek');
  final _skipFocus = FocusNode(debugLabel: 'skip');
  final _videoKey = GlobalKey<VideoState>();

  bool _ready = false, _playing = false, _controls = true;
  Duration _pos = Duration.zero, _dur = Duration.zero;
  List<Track> _audios = const [];  // pistes audio backend (libellés serveur)
  int _audioIndex = 0;             // index de la piste active (param `?audio=`)
  Timer? _hide, _save;
  StreamSubscription? _sPos, _sPlay, _sDur, _sDone;

  // Sous-titres relevés au-dessus de la barre quand les contrôles sont visibles.
  static const _subPadShown = EdgeInsets.fromLTRB(80, 0, 80, 360);
  static const _subPadHidden = EdgeInsets.fromLTRB(80, 0, 80, 60);

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _svc = PlayerService();
    _subs = SubtitleController(_svc.player);
    HardwareKeyboard.instance.addHandler(_onKey);
    WidgetsBinding.instance.addPostFrameCallback((_) => _seekFocus.requestFocus());

    _sPlay = _svc.playing.listen((p) { if (mounted) { setState(() => _playing = p); p ? _scheduleHide() : _reveal(); } });
    _sPos = _svc.position.listen((p) {
      if (!mounted) return;
      setState(() => _pos = p);
      // Passage sautable apparu alors que les contrôles sont masqués : on le
      // focus pour qu'un simple OK saute (cf. _onKey).
      if (!_controls && _activeSegment != null && !_skipFocus.hasFocus) _skipFocus.requestFocus();
    });
    _sDur = _svc.duration.listen((d) { if (mounted) setState(() => _dur = d); });
    _sDone = _svc.completed.listen((c) { if (c && mounted) { _saveNow(finished: true); widget.onNext?.call(); } });

    _start();
  }

  static const _audioPrefKey = 'audio_pref_lang'; // préférence de langue (cross-épisode)

  Future<void> _start() async {
    // Pistes audio d'abord → on démarre directement sur la piste préférée
    // (évite une ré-ouverture juste après le lancement).
    if (widget.wd.sourceId != null) {
      _audios = await _watchApi.audioTracks(widget.wd.sourceId!);
      _audioIndex = await _preferredAudioIndex(_audios);
    }
    await _svc.open(_audioUrl(_audioIndex), headers: widget.headers, startSeconds: widget.wd.startPosition);
    if (mounted) setState(() => _ready = true);
    _scheduleHide();
    _save = Timer.periodic(const Duration(seconds: 10), (_) => _saveNow());
    _subs.load(episodeId: widget.wd.episode.id, sourceId: widget.wd.sourceId);
  }

  /// URL HLS pour la piste audio [index] (le serveur transcode la piste choisie).
  String _audioUrl(int index) =>
      _audios.length < 2 ? widget.wd.hlsUrl! : '${widget.wd.hlsUrl!}?audio=$index';

  /// Défaut : préférence de langue mémorisée, sinon français, sinon 1ʳᵉ piste.
  Future<int> _preferredAudioIndex(List<Track> tracks) async {
    if (tracks.isEmpty) return 0;
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_audioPrefKey);
      if (saved != null) {
        final m = tracks.indexWhere((t) => (t.lang ?? '').toLowerCase() == saved.toLowerCase());
        if (m >= 0) return tracks[m].index;
      }
    } catch (_) {}
    final fr = tracks.indexWhere((t) => (t.lang ?? '').toLowerCase() == 'fr');
    return fr >= 0 ? tracks[fr].index : tracks.first.index;
  }

  /// Mémorise la langue choisie manuellement (suivie d'un épisode à l'autre).
  Future<void> _persistAudioLang(int index) async {
    final t = _audios.firstWhere((a) => a.index == index, orElse: () => _audios.first);
    if (t.lang == null) return;
    try { await (await SharedPreferences.getInstance()).setString(_audioPrefKey, t.lang!); } catch (_) {}
  }

  /// Bascule de piste audio : ré-ouvre le HLS à 0 (le `?audio=N` transcode la
  /// piste), repositionne, puis ré-applique le sous-titre (le reload l'a vidé).
  Future<void> _switchAudio(int index) async {
    if (index == _audioIndex || _audios.length < 2) return;
    final pos = _svc.currentPosition;
    setState(() => _audioIndex = index);
    _persistAudioLang(index);
    await _svc.open(_audioUrl(index), headers: widget.headers, startSeconds: 0);
    if (pos.inSeconds > 5) await _resumeTo(pos);
    await _subs.select(_subs.active);
    if (mounted) setState(() {});
  }

  /// Flux rouvert à 0. mpv n'honore pas l'offset `start` sur une 2ᵉ ouverture,
  /// mais `seek` marche (cf. bouton Passer l'intro) une fois le flux en lecture.
  /// On attend donc que le nouveau flux JOUE réellement (position repartie bas
  /// et qui avance) — un seek émis pendant l'ouverture est ignoré par mpv — puis
  /// on repositionne. HLS VOD + ENDLIST = seekable.
  Future<void> _resumeTo(Duration pos) async {
    final target = pos.inMilliseconds;
    for (var i = 0; i < 60 && mounted; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      final cur = _svc.currentPosition.inMilliseconds;
      if (cur > 300 && cur < target - 2000) break; // nouveau flux en lecture, prêt à seek
    }
    if (mounted) await _svc.seek(pos);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _hide?.cancel(); _save?.cancel();
    _sPos?.cancel(); _sPlay?.cancel(); _sDur?.cancel(); _sDone?.cancel();
    _seekFocus.dispose();
    _skipFocus.dispose();
    _svc.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || !mounted) return false;
    if (!_controls) {
      // Passage sautable affiché et focus : laisse le bouton gérer OK (= passer).
      if (_activeSegment != null && TvKeys.isSelect(e.logicalKey)) return false;
      // Sinon : OK = play/pause direct, toute autre touche = réafficher.
      if (TvKeys.isSelect(e.logicalKey)) _svc.playOrPause();
      _reveal();
      return true; // consomme la touche de réveil (pas d'action sur l'ancien bouton)
    }
    _scheduleHide(); // activité : repousse le masquage
    return false;
  }

  void _reveal() { _setControls(true); _scheduleHide(); }

  void _scheduleHide() {
    _hide?.cancel();
    if (!_playing) return;
    _hide = Timer(const Duration(seconds: 4), () { if (_playing) _setControls(false); });
  }

  /// Centralise l'affichage des contrôles : padding des sous-titres + focus.
  /// Masqué avec un passage sautable actif → focus le bouton (OK = passer).
  void _setControls(bool v) {
    if (!mounted || _controls == v) return;
    setState(() => _controls = v);
    _applySubtitlePadding();
    if (v) {
      _seekFocus.requestFocus();
    } else if (_activeSegment != null) {
      _skipFocus.requestFocus();
    }
  }

  /// Fait monter/descendre les sous-titres selon la visibilité des contrôles
  /// (setPadding anime en interne via l'AnimatedContainer de la SubtitleView).
  void _applySubtitlePadding() => _videoKey.currentState
      ?.setSubtitleViewPadding(_controls ? _subPadShown : _subPadHidden, duration: AppTheme.motion);

  Future<void> _saveNow({bool finished = false}) async {
    final pos = _svc.currentPosition.inSeconds, dur = _svc.totalDuration.inSeconds;
    if (pos <= 0) return;
    await widget.saveProgress(pos, dur, finished || (dur > 0 && pos >= dur - 5));
  }

  /// Durée effective : celle du player si connue, sinon celle de l'épisode (API).
  /// Les flux HLS render-engine ne rapportent pas toujours une durée immédiate.
  Duration get _effectiveDur {
    if (_dur.inSeconds > 0) return _dur;
    final f = widget.fileDurationSeconds ?? widget.wd.episode.duration;
    return f != null && f > 0 ? Duration(seconds: f) : Duration.zero;
  }

  void _seekBy(int s) {
    final max = _effectiveDur.inSeconds;
    _svc.seek(Duration(seconds: (_pos.inSeconds + s).clamp(0, max > 0 ? max : _pos.inSeconds + s)));
  }

  void _showSubtitlePicker() {
    if (!_subs.hasSubtitles) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _SidePicker(
        title: 'Sous-titres',
        options: [
          for (final o in _subs.options)
            _PickerOption(
              label: o.label,
              selected: o == _subs.active,
              onTap: () async {
                Navigator.of(context).pop();
                await _subs.select(o);
                if (mounted) setState(() {});
              },
            ),
        ],
      ),
    );
  }

  /// Libellé court pour le bouton (nom de langue, sinon code, sinon label complet).
  String get _audioButtonLabel {
    final t = _audios.firstWhere((a) => a.index == _audioIndex, orElse: () => _audios.first);
    return t.langName ?? t.lang?.toUpperCase() ?? t.label;
  }

  void _showAudioPicker() {
    if (_audios.length < 2) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _SidePicker(
        title: 'Audio',
        options: [
          for (final a in _audios)
            _PickerOption(
              label: a.label,
              selected: a.index == _audioIndex,
              onTap: () async {
                Navigator.of(context).pop();
                await _switchAudio(a.index);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _exit() async { _save?.cancel(); await _saveNow(); if (mounted) widget.onBack(); }

  /// Segment (intro/outro) couvrant la position courante, s'il existe.
  Segment? get _activeSegment {
    final ms = _pos.inMilliseconds;
    for (final s in widget.segments) {
      if ((s.kind == 'intro' || s.kind == 'outro') && ms >= s.startMs && ms < s.endMs - 500) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    final ep = widget.wd.episode;
    final seg = _activeSegment;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (did, _) { if (!did) _exit(); },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(fit: StackFit.expand, children: [
          // Vidéo + sous-titres rendus par la SubtitleView de media_kit (VTT).
          Video(
            key: _videoKey,
            controller: _svc.controller,
            controls: NoVideoControls,
            subtitleViewConfiguration: const SubtitleViewConfiguration(
              // Style Netflix : texte blanc + ombre douce, sans rectangle de fond.
              style: TextStyle(
                color: Colors.white,
                fontSize: 44,
                fontWeight: FontWeight.w600,
                backgroundColor: Color(0x00000000),
                height: 1.3,
                // Contour noir net (8 directions) + halo doux → lisible même sur image claire.
                shadows: [
                  Shadow(offset: Offset(-2, -2), color: Colors.black),
                  Shadow(offset: Offset(2, -2), color: Colors.black),
                  Shadow(offset: Offset(-2, 2), color: Colors.black),
                  Shadow(offset: Offset(2, 2), color: Colors.black),
                  Shadow(offset: Offset(0, -2), color: Colors.black),
                  Shadow(offset: Offset(0, 2), color: Colors.black),
                  Shadow(offset: Offset(-2, 0), color: Colors.black),
                  Shadow(offset: Offset(2, 0), color: Colors.black),
                  Shadow(blurRadius: 12, color: Color(0xCC000000)),
                ],
              ),
              padding: _subPadShown,
            ),
          ),

          // Overlay pause
          if (!_playing)
            Center(
              child: Container(
                width: 168, height: 168,
                decoration: const BoxDecoration(color: Color(0x4D000000), shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 90),
              ),
            ),

          // Haut
          _TopFade(visible: _controls, title: ep.displayTitle),

          // Bouton Passer (intro/outro) — reste focusable contrôles masqués
          // (OK = passer directement, cf. _onKey).
          if (seg != null)
            Positioned(
              right: 96, bottom: 300,
              child: TvFocusable(
                focusNode: _skipFocus,
                onSelect: () => _svc.seek(Duration(milliseconds: seg.endMs)),
                builder: (_, f) => _WatchPageState._pill(seg.kind == 'intro' ? 'Passer l’intro' : 'Passer l’outro', f),
              ),
            ),

          // Bas : barre + boutons
          _BottomFade(
            visible: _controls,
            pos: _pos, dur: _effectiveDur,
            seekFocus: _seekFocus,
            playing: _playing,
            onSeekKey: (k) {
              if (TvKeys.isLeft(k)) { _seekBy(-10); return true; }
              if (TvKeys.isRight(k)) { _seekBy(10); return true; }
              return false;
            },
            onPlayPause: _svc.playOrPause,
            onBack10: () => _seekBy(-10),
            onFwd10: () => _seekBy(10),
            subsLabel: _subs.activeLabel,
            onSubs: _showSubtitlePicker,
            audioLabel: _audios.length >= 2 ? _audioButtonLabel : null,
            onAudio: _audios.length >= 2 ? _showAudioPicker : null,
            onNext: widget.onNext == null ? null : () { _saveNow(); widget.onNext!(); },
          ),
        ]),
      ),
    );
  }
}

// ── Haut ─────────────────────────────────────────────────────────────────────
class _TopFade extends StatelessWidget {
  final bool visible;
  final String title;
  const _TopFade({required this.visible, required this.title});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final clock = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: AppTheme.motion,
      child: Container(
        height: 260,
        padding: const EdgeInsets.fromLTRB(96, 64, 96, 0),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xB3000000), Color(0x00000000)]),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800))),
            Text(clock, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── Bas ──────────────────────────────────────────────────────────────────────
class _BottomFade extends StatelessWidget {
  final bool visible, playing;
  final Duration pos, dur;
  final FocusNode seekFocus;
  final bool Function(LogicalKeyboardKey) onSeekKey;
  final VoidCallback onPlayPause, onBack10, onFwd10, onSubs;
  final VoidCallback? onNext, onAudio;
  final String subsLabel;
  final String? audioLabel;
  const _BottomFade({
    required this.visible,
    required this.playing,
    required this.pos,
    required this.dur,
    required this.seekFocus,
    required this.onSeekKey,
    required this.onPlayPause,
    required this.onBack10,
    required this.onFwd10,
    required this.onSubs,
    required this.subsLabel,
    this.audioLabel,
    this.onAudio,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final frac = dur.inMilliseconds == 0 ? 0.0 : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: AppTheme.motion,
        child: Container(
          padding: const EdgeInsets.fromLTRB(96, 120, 96, 64),
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Color(0xE6000000), Color(0x99000000), Color(0x00000000)], stops: [0.0, 0.45, 1.0]),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Barre de progression focusable
            TvFocusable(
              focusNode: seekFocus,
              onSelect: onPlayPause,
              onKeyEvent: (node, e) {
                if (e is KeyDownEvent || e is KeyRepeatEvent) {
                  if (onSeekKey(e.logicalKey)) return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              builder: (context, focused) {
                return Column(children: [
                  // Barre Lumen : grossit au focus + halo, remplissage proportionnel.
                  SizedBox(
                    height: 24,
                    child: Center(
                      child: AnimatedContainer(
                        duration: AppTheme.motion,
                        height: focused ? 16 : 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: focused ? const [BoxShadow(color: Color(0x26FFFFFF), spreadRadius: 4)] : null,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(children: [
                          const Positioned.fill(child: ColoredBox(color: Color(0x4DFFFFFF))),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: frac, heightFactor: 1,
                              child: const ColoredBox(color: AppTheme.foreground),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Text(_fmt(pos), style: const TextStyle(color: Colors.white, fontSize: 23, fontFeatures: [FontFeature.tabularFigures()])),
                    const Spacer(),
                    Text(dur.inSeconds > 0 ? _fmt(dur) : '--:--', style: const TextStyle(color: Colors.white70, fontSize: 23, fontFeatures: [FontFeature.tabularFigures()])),
                  ]),
                ]);
              },
            ),
            const SizedBox(height: 18),
            // Boutons
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _IconBtn(icon: Icons.replay_10_rounded, onTap: onBack10),
              const SizedBox(width: 18),
              _IconBtn(icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded, onTap: onPlayPause, big: true),
              const SizedBox(width: 18),
              _IconBtn(icon: Icons.forward_10_rounded, onTap: onFwd10),
              const SizedBox(width: 18),
              _LabelBtn(label: 'Sous-titres : $subsLabel', onTap: onSubs),
              if (onAudio != null) ...[
                const SizedBox(width: 18),
                _LabelBtn(label: 'Audio : ${audioLabel ?? ''}', onTap: onAudio!),
              ],
              if (onNext != null) ...[
                const SizedBox(width: 18),
                _LabelBtn(label: 'Épisode suivant ›', onTap: onNext!),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool big;
  const _IconBtn({required this.icon, required this.onTap, this.big = false});
  @override
  Widget build(BuildContext context) {
    final size = big ? 76.0 : 68.0;
    return TvFocusable(
      onSelect: onTap,
      builder: (_, f) => AnimatedScale(
        scale: f ? 1.1 : 1.0, duration: AppTheme.motion, curve: AppTheme.ease,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(color: f ? AppTheme.primary : AppTheme.materialLight16, shape: BoxShape.circle),
          child: Icon(icon, color: f ? AppTheme.primaryForeground : AppTheme.foreground, size: big ? 44 : 36),
        ),
      ),
    );
  }
}

class _LabelBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LabelBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onSelect: onTap,
      builder: (_, f) => AnimatedScale(
        scale: f ? 1.08 : 1.0, duration: AppTheme.motion, curve: AppTheme.ease,
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 30),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: f ? AppTheme.primary : AppTheme.materialLight16, borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
          child: Text(label, style: TextStyle(color: f ? AppTheme.primaryForeground : AppTheme.foreground, fontSize: 24, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

// ── Sélecteur latéral (sous-titres / audio) ──────────────────────────────────
class _PickerOption {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PickerOption({required this.label, required this.selected, required this.onTap});
}

class _SidePicker extends StatelessWidget {
  final String title;
  final List<_PickerOption> options;
  const _SidePicker({required this.title, required this.options});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 460,
          margin: const EdgeInsets.all(48),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xF21A1A1E),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: AppTheme.borderFaint),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
                child: Text(title, style: const TextStyle(color: AppTheme.foreground, fontSize: 30, fontWeight: FontWeight.w700)),
              ),
              for (final o in options)
                _SubOption(label: o.label, selected: o.selected, autofocus: o.selected, onTap: o.onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubOption extends StatelessWidget {
  final String label;
  final bool selected;
  final bool autofocus;
  final VoidCallback onTap;
  const _SubOption({required this.label, required this.selected, required this.autofocus, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      autofocus: autofocus,
      onSelect: onTap,
      builder: (_, f) => Container(
        color: f ? AppTheme.primary : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        child: Row(children: [
          SizedBox(width: 32, child: selected ? Icon(Icons.check_rounded, color: f ? AppTheme.primaryForeground : AppTheme.foreground, size: 26) : null),
          Expanded(
            child: Text(label,
                style: TextStyle(
                  color: f ? AppTheme.primaryForeground : (selected ? AppTheme.foreground : AppTheme.textSecondary),
                  fontSize: 26, fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                )),
          ),
        ]),
      ),
    );
  }
}

// ── Desktop stub (media_kit desktop à réparer) ───────────────────────────────
class _DesktopStub extends StatelessWidget {
  final String url;
  final VoidCallback onBack;
  const _DesktopStub({required this.url, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.desktop_windows_rounded, color: AppTheme.textMuted, size: 48),
          const SizedBox(height: 16),
          const Text('Lecture indisponible sur desktop (build à réparer).',
              style: TextStyle(color: Colors.white70, fontSize: 20)),
          const SizedBox(height: 20),
          TvFocusable(autofocus: true, onSelect: onBack, builder: (_, f) => _WatchPageState._pill('Retour', f)),
        ]),
      ),
    );
  }
}
