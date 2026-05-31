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

  @override
  void initState() {
    super.initState();
    _loadEpisode();
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

  const _Player({
    required this.hlsUrl,
    required this.episode,
    required this.animeId,
    required this.episodeId,
    required this.startSeconds,
    required this.headers,
    required this.onBack,
    required this.onSaveProgress,
  });

  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> {
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

  StreamSubscription<bool>?            _playingSub;
  StreamSubscription<PlayerState>?     _errorSub;

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
              // Contrôles
              AnimatedOpacity(
                opacity:  _controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: PlayerControls(
                  player:            _player,
                  progressFocusNode: _progressFocus,
                  onPrevEpisode:     null, // TODO: prev/next episode nav
                  onNextEpisode:     null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
