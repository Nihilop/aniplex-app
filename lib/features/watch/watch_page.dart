import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/episode.dart';
import '../../shared/widgets/tv_button.dart';

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
      // Le backend renvoie une URL relative (/api/...) — on la rend absolue
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
      setState(() { _hlsUrl = hlsUrl; _episode = ep; _startPosition = start; _videoHeaders = headers; _loading = false; });
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
              Text(_errorMsg ?? 'Erreur', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 16),
              TvButton(autofocus: true, outlined: true, onTap: () => context.pop(),
                  child: const Text('Retour', style: TextStyle(color: Colors.white70))),
            ],
          ),
        ),
      );
    }
    if (_isDesktop) {
      return _DesktopPlayerStub(
        hlsUrl: _hlsUrl!, episode: _episode,
        onBack: () => context.pop(),
      );
    }
    return _MobilePlayer(
      hlsUrl:       _hlsUrl!,
      episode:      _episode,
      animeId:      widget.animeId,
      episodeId:    widget.episodeId,
      startSeconds: _startPosition,
      headers:      _videoHeaders,
      onBack:       () => context.pop(),
      onSaveProgress: _saveProgress,
    );
  }

  Future<void> _saveProgress(int pos, int dur, {bool finished = false}) async {
    try {
      await _api.post<void>(
        '/api/aniplex/progress/${widget.episodeId}',
        data: {
          'animeId':          widget.animeId,
          'positionSeconds':  pos,
          'durationSeconds':  dur > 0 ? dur : null,
          'finished':         finished,
        },
      );
    } catch (_) {}
  }
}

// ── Desktop stub ──────────────────────────────────────────────────────────────

class _DesktopPlayerStub extends StatefulWidget {
  final String hlsUrl;
  final Episode? episode;
  final VoidCallback onBack;

  const _DesktopPlayerStub({required this.hlsUrl, required this.episode, required this.onBack});

  @override
  State<_DesktopPlayerStub> createState() => _DesktopPlayerStubState();
}

class _DesktopPlayerStubState extends State<_DesktopPlayerStub> {
  bool _copied = false;

  Future<void> _copyUrl() async {
    await Clipboard.setData(ClipboardData(text: widget.hlsUrl));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

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
              const SizedBox(height: 8),
              const Text('Copie le lien HLS pour le lire dans VLC.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(widget.hlsUrl,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontFamily: 'monospace'),
                        maxLines: 2, overflow: TextOverflow.ellipsis)),
                    IconButton(
                      onPressed: _copyUrl,
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

// ── Mobile/TV player ──────────────────────────────────────────────────────────

class _MobilePlayer extends StatefulWidget {
  final String    hlsUrl;
  final Episode?  episode;
  final String    animeId;
  final String    episodeId;
  final int       startSeconds;
  final Map<String, String> headers;
  final VoidCallback onBack;
  final Future<void> Function(int pos, int dur, {bool finished}) onSaveProgress;

  const _MobilePlayer({
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
  State<_MobilePlayer> createState() => _MobilePlayerState();
}

class _MobilePlayerState extends State<_MobilePlayer> {
  late VideoPlayerController _controller;
  bool   _initialized  = false;
  bool   _showControls = true;
  bool   _error        = false;
  Timer? _hideTimer;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initPlayer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _saveTimer?.cancel();
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _initPlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.hlsUrl),
        httpHeaders: widget.headers,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      await _controller.initialize();
      _controller.addListener(_onPlayerEvent);

      // Seek to saved position
      if (widget.startSeconds > 0) {
        await _controller.seekTo(Duration(seconds: widget.startSeconds));
      }
      await _controller.play();

      if (mounted) setState(() => _initialized = true);
      _resetHideTimer();
      _startSaveTimer();
    } catch (e) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _onPlayerEvent() {
    if (!mounted) return;
    setState(() {});
    final value = _controller.value;
    if (value.duration.inSeconds > 0 &&
        value.position >= value.duration - const Duration(seconds: 2)) {
      widget.onSaveProgress(
        value.position.inSeconds,
        value.duration.inSeconds,
        finished: true,
      );
    }
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    if (mounted) setState(() => _showControls = true);
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _startSaveTimer() {
    _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final value = _controller.value;
      if (value.isInitialized) {
        widget.onSaveProgress(
          value.position.inSeconds,
          value.duration.inSeconds,
        );
      }
    });
  }

  void _togglePlay() {
    _controller.value.isPlaying ? _controller.pause() : _controller.play();
    _resetHideTimer();
  }

  void _seek(Duration delta) {
    final value = _controller.value;
    final newPos = value.position + delta;
    final clamped = newPos < Duration.zero ? Duration.zero
        : newPos > value.duration ? value.duration : newPos;
    _controller.seekTo(clamped);
    _resetHideTimer();
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    _resetHideTimer();
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.select     ||
        key == LogicalKeyboardKey.enter      ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      _togglePlay();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.mediaFastForward) {
      _seek(const Duration(seconds: 10));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft  ||
        key == LogicalKeyboardKey.mediaRewind) {
      _seek(const Duration(seconds: -10));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _seek(const Duration(seconds: 60));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _seek(const Duration(seconds: -60));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.goBack     ||
        key == LogicalKeyboardKey.escape) {
      widget.onBack();
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
              TvButton(autofocus: true, outlined: true, onTap: widget.onBack,
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

    final value    = _controller.value;
    final duration = value.duration;
    final position = value.position;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: _handleKey,
        child: GestureDetector(
          onTap: _togglePlay,
          child: Stack(
            children: [
              // ── Video ──────────────────────────────────────────────
              Center(
                child: AspectRatio(
                  aspectRatio: value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              ),

              // ── Controls overlay ───────────────────────────────────
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x99000000), Colors.transparent, Color(0xCC000000)],
                      stops: [0.0, 0.4, 1.0],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Top bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: widget.onBack,
                              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 12),
                            if (widget.episode != null)
                              Expanded(
                                child: Text(
                                  'Ép. ${widget.episode!.number ?? '?'}'
                                  '${widget.episode!.title != null ? ' — ${widget.episode!.title}' : ''}',
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Bottom bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                        child: Column(
                          children: [
                            // Progress bar
                            LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                              minHeight: 3,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // Play/Pause
                                Icon(
                                  value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                const SizedBox(width: 16),
                                // Position / Duration
                                Text(
                                  '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                                const Spacer(),
                                // Hints
                                const Text(
                                  '◀◀ -10s   ▶▶ +10s   ↑ +1min',
                                  style: TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Buffering indicator
              if (value.isBuffering)
                const Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
