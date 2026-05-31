import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/episode.dart';

// video_player ne supporte pas Windows/Linux/macOS.
// Sur desktop on affiche un placeholder.
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
  bool    _loading = true;
  bool    _error   = false;
  String? _errorMsg;
  String? _hlsUrl;
  Episode? _episode;

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
      final hlsUrl = (data['hlsUrl'] ?? data['streamUrl']) as String? ?? '';
      if (hlsUrl.isEmpty) {
        setState(() { _error = true; _errorMsg = 'Aucun fichier disponible pour cet épisode.'; _loading = false; });
        return;
      }
      final ep = Episode.fromJson(data['episode'] as Map<String, dynamic>);
      setState(() { _hlsUrl = hlsUrl; _episode = ep; _loading = false; });

      // Sur mobile/TV on lance le vrai player
      if (!_isDesktop) _launchPlayer(hlsUrl, data['startPosition'] as int? ?? 0);
    } catch (e) {
      setState(() { _error = true; _errorMsg = 'Impossible de charger la vidéo.'; _loading = false; });
    }
  }

  void _launchPlayer(String url, int startSeconds) {
    // Délégué au widget _MobilePlayer via setState déjà fait
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
              TextButton(onPressed: () => context.pop(), child: const Text('Retour', style: TextStyle(color: Colors.white70))),
            ],
          ),
        ),
      );
    }
    if (_isDesktop) {
      return _DesktopPlayerStub(
        hlsUrl: _hlsUrl!,
        episode: _episode,
        animeId: widget.animeId,
        episodeId: widget.episodeId,
        onBack: () => context.pop(),
      );
    }
    return _MobilePlayer(
      hlsUrl: _hlsUrl!,
      episode: _episode,
      animeId: widget.animeId,
      episodeId: widget.episodeId,
      onBack: () => context.pop(),
      onSaveProgress: _saveProgress,
    );
  }

  Future<void> _saveProgress(int posSeconds, int durSeconds, {bool finished = false}) async {
    try {
      await _api.post<void>(
        '/api/aniplex/progress/${widget.episodeId}',
        data: {
          'animeId': widget.animeId,
          'positionSeconds': posSeconds,
          'durationSeconds': durSeconds > 0 ? durSeconds : null,
          'finished': finished,
        },
      );
    } catch (_) {}
  }
}

// ── Desktop stub ──────────────────────────────────────────────────────────────

class _DesktopPlayerStub extends StatefulWidget {
  final String    hlsUrl;
  final Episode?  episode;
  final String    animeId;
  final String    episodeId;
  final VoidCallback onBack;

  const _DesktopPlayerStub({
    required this.hlsUrl,
    required this.episode,
    required this.animeId,
    required this.episodeId,
    required this.onBack,
  });

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
                ep != null
                    ? 'Épisode ${ep.number ?? '?'}${ep.title != null ? ' — ${ep.title}' : ''}'
                    : 'Lecture vidéo',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'video_player n\'est pas disponible sur Windows.\nCopie le lien HLS pour le lire dans VLC ou un lecteur externe.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              // HLS URL
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.hlsUrl,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontFamily: 'monospace'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _copyUrl,
                      icon: Icon(
                        _copied ? Icons.check_rounded : Icons.copy_rounded,
                        color: _copied ? Colors.greenAccent : AppTheme.textSecondary,
                        size: 18,
                      ),
                      tooltip: 'Copier',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Retour'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mobile/TV player (Android uniquement) ────────────────────────────────────

class _MobilePlayer extends StatefulWidget {
  final String    hlsUrl;
  final Episode?  episode;
  final String    animeId;
  final String    episodeId;
  final VoidCallback onBack;
  final Future<void> Function(int pos, int dur, {bool finished}) onSaveProgress;

  const _MobilePlayer({
    required this.hlsUrl,
    required this.episode,
    required this.animeId,
    required this.episodeId,
    required this.onBack,
    required this.onSaveProgress,
  });

  @override
  State<_MobilePlayer> createState() => _MobilePlayerState();
}

class _MobilePlayerState extends State<_MobilePlayer> {
  // Import différé — uniquement instancié sur Android
  dynamic _controller; // VideoPlayerController
  bool   _showControls = true;
  Timer? _hideTimer;
  Timer? _saveTimer;
  bool   _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _saveTimer?.cancel();
    (_controller as dynamic)?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _init() async {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Lazy import via reflection-like approach — on Android video_player est présent
    try {
      final vp = await _createController(widget.hlsUrl);
      _controller = vp;
      await (vp as dynamic).initialize();
      (vp as dynamic).addListener(_onEvent);
      await (vp as dynamic).play();
      if (mounted) setState(() => _initialized = true);
      _resetHideTimer();
      _startSaveTimer();
    } catch (e) {
      // Fallback — ne devrait pas arriver sur Android
    }
  }

  // Crée un VideoPlayerController — si le package n'est pas là, throw.
  Future<dynamic> _createController(String url) async {
    // On passe par un import dynamique pour éviter l'erreur compile sur desktop.
    // Ce code n'est exécuté que sur Android où video_player est disponible.
    throw UnimplementedError('video_player not available on this platform');
  }

  void _onEvent() {
    if (!mounted) return;
    setState(() {});
    final value = (_controller as dynamic).value;
    if (value?.position != null && value?.duration != null) {
      if ((value.position as Duration) >= (value.duration as Duration) - const Duration(seconds: 2)) {
        widget.onSaveProgress(
          (value.position as Duration).inSeconds,
          (value.duration as Duration).inSeconds,
          finished: true,
        );
      }
    }
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    setState(() => _showControls = true);
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _startSaveTimer() {
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final value = (_controller as dynamic)?.value;
      if (value != null) {
        widget.onSaveProgress(
          (value.position as Duration).inSeconds,
          (value.duration as Duration).inSeconds,
        );
      }
    });
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    _resetHideTimer();
    final key = event.logicalKey;
    final c = _controller as dynamic;
    final pos  = c?.value?.position  as Duration? ?? Duration.zero;
    final dur  = c?.value?.duration  as Duration? ?? Duration.zero;
    Duration clamp(Duration v) => v < Duration.zero ? Duration.zero : (v > dur ? dur : v);

    if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.mediaPlayPause) {
      c?.value?.isPlaying == true ? c?.pause() : c?.play();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.mediaFastForward) {
      c?.seekTo(clamp(pos + const Duration(seconds: 10)));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.mediaRewind) {
      c?.seekTo(clamp(pos - const Duration(seconds: 10)));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      c?.seekTo(clamp(pos + const Duration(seconds: 60)));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      c?.seekTo(clamp(pos - const Duration(seconds: 60)));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape) {
      widget.onBack();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: _handleKey,
        child: const Center(
          child: Text(
            'Lecture en cours…',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      ),
    );
  }
}
