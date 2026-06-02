import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/episode.dart';
import '../../shared/widgets/tv_button.dart';
import '../../shared/widgets/tv_nav.dart';
import 'player_controls.dart';

bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

class WatchPage extends StatefulWidget {
  final String animeId;
  final String episodeId;

  const WatchPage({super.key, required this.animeId, required this.episodeId});

  @override
  State<WatchPage> createState() => _WatchPageState();
}

class _WatchPageState extends State<WatchPage> {
  final _api = ApiClient.instance;

  bool     _loading  = true;
  bool     _error    = false;
  String?  _errorMsg;
  String?  _hlsUrl;
  Episode? _episode;
  int      _startPosition = 0;
  Map<String, String> _videoHeaders = {};

  String? _prevEpisodeId;
  String? _nextEpisodeId;

  @override
  void initState() {
    super.initState();
    _loadEpisode();
    _loadAdjacent();
  }

  /// Récupère la liste des épisodes lisibles (avec fichier) pour déterminer
  /// l'épisode précédent / suivant. Indépendant du chargement de la vidéo :
  /// si ça échoue, les boutons prev/next restent simplement masqués.
  Future<void> _loadAdjacent() async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        '/api/aniplex/anime/${widget.animeId}',
      );
      final data    = res.data!;
      final eps     = ((data['episodes'] as List?) ?? []).cast<Map<String, dynamic>>();
      final withFile = (((data['episodeIdsWithFile'] as List?) ?? []).cast<String>()).toSet();
      // Uniquement les épisodes réellement lisibles, triés par numéro.
      final playable = eps.where((e) => withFile.contains(e['id'])).toList()
        ..sort((a, b) => ((a['number'] as num?) ?? 0).compareTo((b['number'] as num?) ?? 0));
      final idx = playable.indexWhere((e) => e['id'] == widget.episodeId);
      if (idx < 0 || !mounted) return;
      setState(() {
        _prevEpisodeId = idx > 0 ? playable[idx - 1]['id'] as String : null;
        _nextEpisodeId = idx < playable.length - 1 ? playable[idx + 1]['id'] as String : null;
      });
    } catch (_) {}
  }

  void _goEpisode(String episodeId) {
    // pushReplacement (pas go) : on remplace la route player courante en
    // gardant Home/Détail dans la stack → un seul pop revient à la fiche.
    context.pushReplacement('/watch/${widget.animeId}/$episodeId');
  }

  Future<void> _loadEpisode() async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        '/api/aniplex/watch/${widget.animeId}/${widget.episodeId}',
      );
      final data = res.data!;
      var hlsUrl = (data['hlsUrl'] ?? data['streamUrl']) as String? ?? '';
      if (hlsUrl.isNotEmpty && !hlsUrl.startsWith('http')) {
        hlsUrl = '${_api.baseUrl}$hlsUrl';
      }
      if (hlsUrl.isEmpty) {
        setState(() { _error = true; _errorMsg = 'Aucun fichier disponible.'; _loading = false; });
        return;
      }
      final ep      = Episode.fromJson(data['episode'] as Map<String, dynamic>);
      final start   = data['startPosition'] as int? ?? 0;
      final headers = await _api.getVideoHeaders();
      setState(() {
        _hlsUrl        = hlsUrl;
        _episode       = ep;
        _startPosition = start;
        _videoHeaders  = headers;
        _loading       = false;
      });
    } catch (e) {
      setState(() { _error = true; _errorMsg = 'Impossible de charger la vidéo.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }
    if (_error) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(_errorMsg ?? 'Erreur', style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TvButton(autofocus: true, outlined: true, onTap: () => context.pop(),
                  child: const Text('Retour', style: TextStyle(color: Colors.white70))),
            ],
          ),
        ),
      );
    }
    if (_isDesktop) {
      return _DesktopStub(hlsUrl: _hlsUrl!, episode: _episode, onBack: () => context.pop());
    }
    return _Player(
      hlsUrl:         _hlsUrl!,
      episode:        _episode,
      animeId:        widget.animeId,
      episodeId:      widget.episodeId,
      startSeconds:   _startPosition,
      headers:        _videoHeaders,
      onBack:         () => context.pop(),
      onSaveProgress: _saveProgress,
      onPrevEpisode:  _prevEpisodeId == null ? null : () => _goEpisode(_prevEpisodeId!),
      onNextEpisode:  _nextEpisodeId == null ? null : () => _goEpisode(_nextEpisodeId!),
    );
  }

  Future<void> _saveProgress(int pos, int dur, {bool finished = false}) async {
    try {
      await _api.post<void>(
        '/api/aniplex/progress/${widget.episodeId}',
        data: {
          'animeId':         widget.animeId,
          'positionSeconds': pos,
          'durationSeconds': dur > 0 ? dur : null,
          'finished':        finished,
        },
      );
    } catch (_) {}
  }
}

// ── Desktop stub ──────────────────────────────────────────────────────────────

class _DesktopStub extends StatefulWidget {
  final String hlsUrl;
  final Episode? episode;
  final VoidCallback onBack;

  const _DesktopStub({required this.hlsUrl, required this.episode, required this.onBack});

  @override
  State<_DesktopStub> createState() => _DesktopStubState();
}

class _DesktopStubState extends State<_DesktopStub> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final ep = widget.episode;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.desktop_windows_rounded, color: AppTheme.textMuted, size: 48),
              const SizedBox(height: 16),
              Text(
                ep != null ? 'Ép. ${ep.number ?? '?'}${ep.title != null ? ' — ${ep.title}' : ''}' : 'Lecture vidéo',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(widget.hlsUrl,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontFamily: 'monospace'),
                        maxLines: 2, overflow: TextOverflow.ellipsis)),
                    IconButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: widget.hlsUrl));
                        setState(() => _copied = true);
                        await Future.delayed(const Duration(seconds: 2));
                        if (mounted) setState(() => _copied = false);
                      },
                      icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded,
                          color: _copied ? Colors.greenAccent : AppTheme.textSecondary, size: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TvButton(outlined: true, onTap: widget.onBack,
                  child: const Text('Retour', style: TextStyle(color: AppTheme.textSecondary))),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Player Android TV ─────────────────────────────────────────────────────────

class _Player extends StatefulWidget {
  final String    hlsUrl;
  final Episode?  episode;
  final String    animeId;
  final String    episodeId;
  final int       startSeconds;
  final Map<String, String> headers;
  final VoidCallback onBack;
  final Future<void> Function(int pos, int dur, {bool finished}) onSaveProgress;
  final VoidCallback? onPrevEpisode;
  final VoidCallback? onNextEpisode;

  const _Player({
    required this.hlsUrl,
    required this.episode,
    required this.animeId,
    required this.episodeId,
    required this.startSeconds,
    required this.headers,
    required this.onBack,
    required this.onSaveProgress,
    this.onPrevEpisode,
    this.onNextEpisode,
  });

  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> {
  final _api = ApiClient.instance;

  late final Player          _player;
  late final VideoController _videoCtrl;

  final FocusNode _progressFocus = FocusNode(debugLabel: 'player.progress');

  bool   _initialized  = false;
  bool   _error        = false;
  bool   _controlsVisible = true;
  Timer? _hideTimer;
  Timer? _saveTimer;
  Timer? _seekTimer;
  bool   _isPlaying    = false;

  StreamSubscription<bool>?     _playingSub;
  StreamSubscription<String>?   _errorSub;
  StreamSubscription<Duration>? _cueSub;

  // ── Sous-titres ────────────────────────────────────────────────────────────
  String?         _sourceId;        // token opaque extrait de l'URL HLS
  List<_SubTrack> _subTracks    = [];
  int?            _activeSubIndex;
  List<_SubCue>   _subCues      = [];
  String?         _currentCueText;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _player    = Player();
    _videoCtrl = VideoController(_player);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _progressFocus.requestFocus();
    });

    HardwareKeyboard.instance.addHandler(_onAnyKey);

    _playingSub = _player.stream.playing.listen((p) {
      if (!mounted) return;
      _isPlaying = p;
      if (p) { _scheduleHide(); }
      else   { _hideTimer?.cancel(); if (!_controlsVisible) setState(() => _controlsVisible = true); }
    });

    _errorSub = _player.stream.error.listen((_) {
      if (mounted) setState(() => _error = true);
    });

    // Affichage des sous-titres : on cherche la cue active à chaque tick de
    // position et on met à jour l'overlay quand le texte change.
    _cueSub = _player.stream.position.listen((pos) {
      if (!mounted) return;
      if (_subCues.isEmpty) {
        if (_currentCueText != null) setState(() => _currentCueText = null);
        return;
      }
      final cue = _subCues.cast<_SubCue?>().firstWhere(
        (c) => pos >= c!.start && pos <= c.end,
        orElse: () => null,
      );
      if (cue?.text != _currentCueText) {
        setState(() => _currentCueText = cue?.text);
      }
    });

    _initPlayback();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onAnyKey);
    _hideTimer?.cancel();
    _saveTimer?.cancel();
    _seekTimer?.cancel();
    _playingSub?.cancel();
    _errorSub?.cancel();
    _cueSub?.cancel();
    _progressFocus.dispose();
    _player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _initPlayback() async {
    await _player.open(Media(widget.hlsUrl, httpHeaders: widget.headers));

    if (widget.startSeconds > 5) {
      _seekToPosition(Duration(seconds: widget.startSeconds));
    }

    if (mounted) setState(() => _initialized = true);
    _scheduleHide();
    _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());

    _sourceId = _extractSourceId(widget.hlsUrl);
    _fetchSubtitles();
  }

  // ── Sous-titres ──────────────────────────────────────────────────────────

  /// Extrait le token opaque de source depuis l'URL HLS render-engine
  /// (`…/render-engine/hls/<source>/index.m3u8`). C'est ce token que les
  /// endpoints subs/audio attendent.
  String? _extractSourceId(String url) {
    final m = RegExp(r'/render-engine/hls/([^/]+)/').firstMatch(url);
    return m?.group(1);
  }

  bool _isFrench(_SubTrack t) {
    final lang  = (t.language ?? '').toLowerCase();
    final title = (t.title    ?? '').toLowerCase();
    return ['fr', 'fre', 'fra', 'french', 'français', 'francais']
        .any((k) => lang == k || title.contains(k));
  }

  /// Récupère la liste des pistes de sous-titres puis active le français par
  /// défaut s'il existe. Silencieux en cas d'échec (fichier non-MKV, ffprobe
  /// absent, etc.) → le bouton sous-titres reste simplement masqué.
  Future<void> _fetchSubtitles() async {
    final src = _sourceId;
    if (src == null) return;
    try {
      final res  = await _api.get<Map<String, dynamic>>('/api/aniplex/render-engine/subs/$src');
      final data = res.data;
      if (data == null || data['success'] != true) return;
      final list = (data['data'] as List?) ?? [];
      final tracks = list.map((e) {
        final t = e as Map<String, dynamic>;
        return _SubTrack(
          index:    (t['index'] as num).toInt(),
          language: t['language'] as String?,
          title:    t['title']    as String?,
        );
      }).toList();
      if (!mounted) return;
      setState(() => _subTracks = tracks);

      final fr = tracks.cast<_SubTrack?>().firstWhere(
        (t) => _isFrench(t!),
        orElse: () => null,
      );
      if (fr != null) _selectSubtitle(fr.index);
    } catch (_) {}
  }

  /// Active une piste (ou la désactive si `index == null`). Télécharge et parse
  /// le WebVTT — media_kit ne sait pas extraire les pistes embarquées d'un MKV
  /// à la volée, donc on rend les sous-titres via notre propre overlay.
  Future<void> _selectSubtitle(int? index) async {
    setState(() {
      _activeSubIndex = index;
      _subCues        = [];
      _currentCueText = null;
    });
    if (index == null || _sourceId == null) return;
    try {
      final vtt  = await _api.getText('/api/aniplex/render-engine/subs/$_sourceId/$index');
      final cues = _parseVtt(vtt ?? '');
      if (mounted) setState(() => _subCues = cues);
    } catch (_) {}
  }

  void _showSubtitlePicker() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _SubtitlePicker(
        tracks:      _subTracks,
        activeIndex: _activeSubIndex,
        onSelect:    (i) { Navigator.pop(context); _selectSubtitle(i); },
      ),
    );
  }

  // ── Parser WebVTT ──────────────────────────────────────────────────────────

  static final _vttTagRe = RegExp(r'<[^>]*>');

  List<_SubCue> _parseVtt(String raw) {
    final cues  = <_SubCue>[];
    final lines = raw.replaceAll('\r\n', '\n').split('\n');
    int i = 0;
    while (i < lines.length) {
      final line = lines[i].trim();
      if (line.contains('-->')) {
        final arrow  = line.indexOf('-->');
        final start  = _parseVttTime(line.substring(0, arrow).trim());
        final endRaw = line.substring(arrow + 3).trim().split(' ').first;
        final end    = _parseVttTime(endRaw);
        i++;
        final textLines = <String>[];
        while (i < lines.length && lines[i].trim().isNotEmpty) {
          textLines.add(lines[i].trim().replaceAll(_vttTagRe, ''));
          i++;
        }
        if (start != null && end != null && textLines.isNotEmpty) {
          cues.add(_SubCue(start: start, end: end, text: textLines.join('\n')));
        }
      } else {
        i++;
      }
    }
    return cues;
  }

  Duration? _parseVttTime(String s) {
    try {
      final parts = s.split(':');
      if (parts.length == 3) {
        final h     = int.parse(parts[0]);
        final m     = int.parse(parts[1]);
        final secMs = parts[2].split('.');
        final sec   = int.parse(secMs[0]);
        final ms    = int.parse((secMs.length > 1 ? secMs[1] : '0').padRight(3, '0').substring(0, 3));
        return Duration(hours: h, minutes: m, seconds: sec, milliseconds: ms);
      } else if (parts.length == 2) {
        final m     = int.parse(parts[0]);
        final secMs = parts[1].split('.');
        final sec   = int.parse(secMs[0]);
        final ms    = int.parse((secMs.length > 1 ? secMs[1] : '0').padRight(3, '0').substring(0, 3));
        return Duration(minutes: m, seconds: sec, milliseconds: ms);
      }
    } catch (_) {}
    return null;
  }

  void _seekToPosition(Duration target) {
    int attempts = 0;
    _seekTimer?.cancel();
    _seekTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      attempts++;
      final dur = _player.state.duration;
      if (dur.inSeconds > 0) {
        _player.seek(target);
        timer.cancel();
        _seekTimer = null;
      } else if (attempts > 30) {
        timer.cancel();
        _seekTimer = null;
      }
    });
  }

  bool _onAnyKey(KeyEvent event) {
    if (event is KeyDownEvent && mounted) _revealControls();
    return false;
  }

  void _revealControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_isPlaying) return;
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) setState(() => _controlsVisible = false);
    });
  }

  Future<void> _saveProgress() async {
    final pos = _player.state.position.inSeconds;
    final dur = _player.state.duration.inSeconds;
    if (pos <= 0) return;
    final finished = dur > 0 && pos >= dur - 5;
    await widget.onSaveProgress(pos, dur, finished: finished);
  }

  Future<void> _exit() async {
    _saveTimer?.cancel();
    _hideTimer?.cancel();
    _seekTimer?.cancel();
    try { await _saveProgress(); } catch (_) {}
    if (mounted) context.pop();
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.escape) {
      _exit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              const Text('Impossible de lire la vidéo.', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 16),
              TvButton(autofocus: true, outlined: true, onTap: _exit,
                  child: const Text('Retour', style: TextStyle(color: Colors.white70))),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _exit(); },
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: _handleKey,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Vidéo
              Center(
                child: Video(
                  controller: _videoCtrl,
                  controls:   NoVideoControls,
                ),
              ),
              // Overlay sous-titres — remonte au-dessus de la barre quand les
              // contrôles sont visibles, redescend près du bord sinon.
              if (_currentCueText != null)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve:    Curves.easeOut,
                  bottom:   _controlsVisible ? 150 : 32,
                  left:     32,
                  right:    32,
                  child:    _SubtitleOverlay(text: _currentCueText!),
                ),
              // Contrôles
              AnimatedOpacity(
                opacity:  _controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: PlayerControls(
                  player:            _player,
                  progressFocusNode: _progressFocus,
                  hasSubtitles:      _subTracks.isNotEmpty,
                  onSubtitlesTap:    _showSubtitlePicker,
                  onPrevEpisode:     widget.onPrevEpisode == null
                      ? null
                      : () { _saveProgress(); widget.onPrevEpisode!(); },
                  onNextEpisode:     widget.onNextEpisode == null
                      ? null
                      : () { _saveProgress(); widget.onNextEpisode!(); },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Modèles sous-titres ─────────────────────────────────────────────────────

class _SubTrack {
  final int     index;
  final String? language;
  final String? title;
  const _SubTrack({required this.index, this.language, this.title});

  String get label {
    if (title != null && title!.isNotEmpty)       return title!;
    if (language != null && language!.isNotEmpty) return language!.toUpperCase();
    return 'Piste ${index + 1}';
  }
}

class _SubCue {
  final Duration start;
  final Duration end;
  final String   text;
  const _SubCue({required this.start, required this.end, required this.text});
}

// ── Overlay sous-titres ─────────────────────────────────────────────────────

class _SubtitleOverlay extends StatelessWidget {
  const _SubtitleOverlay({required this.text});
  final String text;

  // Contour noir simulé par 8 ombres directionnelles + 1 halo flou — lisible
  // sur n'importe quel fond. Porté depuis Animax.
  static const _shadow = [
    Shadow(offset: Offset(-1.5, -1.5), color: Colors.black),
    Shadow(offset: Offset( 1.5, -1.5), color: Colors.black),
    Shadow(offset: Offset(-1.5,  1.5), color: Colors.black),
    Shadow(offset: Offset( 1.5,  1.5), color: Colors.black),
    Shadow(offset: Offset(-2,  0), color: Colors.black),
    Shadow(offset: Offset( 2,  0), color: Colors.black),
    Shadow(offset: Offset( 0, -2), color: Colors.black),
    Shadow(offset: Offset( 0,  2), color: Colors.black),
    Shadow(blurRadius: 8, color: Color(0xCC000000)),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color:      Colors.white,
          fontSize:   22,
          height:     1.4,
          fontWeight: FontWeight.w600,
          shadows:    _shadow,
        ),
      ),
    );
  }
}

// ── Picker sous-titres ──────────────────────────────────────────────────────

class _SubtitlePicker extends StatelessWidget {
  const _SubtitlePicker({
    required this.tracks,
    required this.activeIndex,
    required this.onSelect,
  });
  final List<_SubTrack>     tracks;
  final int?                activeIndex;
  final void Function(int?) onSelect;

  @override
  Widget build(BuildContext context) {
    final all = <(String, int?)>[
      ('Désactivés', null),
      ...tracks.map((t) => (t.label, t.index as int?)),
    ];

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 280,
          margin: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Text(
                  'Sous-titres',
                  style: TextStyle(
                    color:         Colors.white,
                    fontSize:      15,
                    fontWeight:    FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              ...all.indexed.map((entry) {
                final (i, item)    = entry;
                final (label, idx) = item;
                return _SubOption(
                  label:     label,
                  selected:  idx == activeIndex,
                  autofocus: i == 0,
                  onTap:     () => onSelect(idx),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubOption extends StatefulWidget {
  const _SubOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.autofocus = false,
  });
  final String       label;
  final bool         selected;
  final VoidCallback onTap;
  final bool         autofocus;

  @override
  State<_SubOption> createState() => _SubOptionState();
}

class _SubOptionState extends State<_SubOption> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) => TvNav.handle(node, event, onSelect: widget.onTap),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: _focused ? Colors.white.withOpacity(0.12) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: widget.selected
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color:      widget.selected || _focused ? Colors.white : Colors.white60,
                    fontSize:   14,
                    fontWeight: widget.selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
