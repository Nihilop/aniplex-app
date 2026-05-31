import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../shared/widgets/tv_nav.dart';

/// Barre de contrôles TV — portée depuis Animax.
/// Toujours visible. Focus initial sur la progress bar.
/// Ordre de focus : Progress bar → Précédent → Play/Pause → Suivant → Audio → Sous-titres
class PlayerControls extends StatefulWidget {
  const PlayerControls({
    super.key,
    required this.player,
    this.progressFocusNode,
    this.hasSubtitles    = false,
    this.onSubtitlesTap,
    this.hasAudioTracks  = false,
    this.onAudioTap,
    this.onPrevEpisode,
    this.onNextEpisode,
    this.showSkipIntro   = false,
    this.onSkipIntro,
    this.showSkipOutro   = false,
    this.onSkipOutro,
  });

  final Player        player;
  final FocusNode?    progressFocusNode;
  final bool          hasSubtitles;
  final VoidCallback? onSubtitlesTap;
  final bool          hasAudioTracks;
  final VoidCallback? onAudioTap;
  final VoidCallback? onPrevEpisode;
  final VoidCallback? onNextEpisode;
  final bool          showSkipIntro;
  final VoidCallback? onSkipIntro;
  final bool          showSkipOutro;
  final VoidCallback? onSkipOutro;

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  Duration _pos     = Duration.zero;
  Duration _dur     = Duration.zero;
  bool     _playing = false;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<bool>?     _playSub;

  @override
  void initState() {
    super.initState();
    _posSub  = widget.player.stream.position.listen((d) { if (mounted) setState(() => _pos = d); });
    _durSub  = widget.player.stream.duration.listen((d) { if (mounted) setState(() => _dur = d); });
    _playSub = widget.player.stream.playing.listen((p)  { if (mounted) setState(() => _playing = p); });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _playSub?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _seekBy(int seconds) {
    final target = _pos + Duration(seconds: seconds);
    widget.player.seek(Duration(
      milliseconds: target.inMilliseconds.clamp(0, _dur.inMilliseconds),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Skip intro/outro
        if (widget.showSkipIntro || widget.showSkipOutro)
          Positioned(
            right: 32, bottom: 156,
            child: _SkipButton(
              label: widget.showSkipIntro ? "Passer l'intro" : "Passer l'outro",
              onTap: widget.showSkipIntro ? widget.onSkipIntro : widget.onSkipOutro,
            ),
          ),

        // Barre de contrôles
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end:   Alignment.topCenter,
                colors: [Color(0xCC000000), Colors.transparent],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ProgressBar(
                  position:     _pos,
                  duration:     _dur,
                  fmt:          _fmt,
                  focusNode:    widget.progressFocusNode,
                  onSeekLeft:   () => _seekBy(-10),
                  onSeekRight:  () => _seekBy(10),
                  onTogglePlay: widget.player.playOrPause,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (widget.onPrevEpisode != null) ...[
                      _IconBtn(icon: Icons.skip_previous_rounded, onTap: widget.onPrevEpisode!),
                      const SizedBox(width: 8),
                    ],
                    _IconBtn(
                      icon: _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 40, btnSize: 64,
                      onTap: widget.player.playOrPause,
                    ),
                    if (widget.onNextEpisode != null) ...[
                      const SizedBox(width: 8),
                      _IconBtn(icon: Icons.skip_next_rounded, onTap: widget.onNextEpisode!),
                    ],
                    const Spacer(),
                    if (widget.hasAudioTracks) ...[
                      _IconBtn(icon: Icons.audiotrack, onTap: widget.onAudioTap ?? () {}),
                      const SizedBox(width: 4),
                    ],
                    if (widget.hasSubtitles)
                      _IconBtn(icon: Icons.subtitles, onTap: widget.onSubtitlesTap ?? () {}),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Progress bar focusable ────────────────────────────────────────────────────

class _ProgressBar extends StatefulWidget {
  const _ProgressBar({
    required this.position,
    required this.duration,
    required this.fmt,
    required this.onSeekLeft,
    required this.onSeekRight,
    required this.onTogglePlay,
    this.focusNode,
  });

  final Duration position;
  final Duration duration;
  final String Function(Duration) fmt;
  final VoidCallback onSeekLeft;
  final VoidCallback onSeekRight;
  final VoidCallback onTogglePlay;
  final FocusNode? focusNode;

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final hasDur = widget.duration.inMilliseconds > 0;
    final pct    = hasDur
        ? (widget.position.inMilliseconds / widget.duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) => TvNav.handle(node, event,
        onSelect:     widget.onTogglePlay,
        onArrowLeft:  widget.onSeekLeft,
        onArrowRight: widget.onSeekRight,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: _focused ? 6 : 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(_focused ? 0.35 : 0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(
                    height: _focused ? 6 : 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE63946),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                if (_focused && hasDur)
                  Positioned(
                    left: 0, right: 0, top: 0, bottom: 0,
                    child: FractionallySizedBox(
                      widthFactor: pct,
                      alignment: Alignment.centerLeft,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 14, height: 14,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 6)],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(widget.fmt(widget.position),
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(hasDur ? widget.fmt(widget.duration) : '--:--',
                  style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bouton icône focusable ────────────────────────────────────────────────────

class _IconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double btnSize;

  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.size    = 24,
    this.btnSize = 56,
  });

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) => TvNav.handle(node, event, onSelect: widget.onTap),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.btnSize, height: widget.btnSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _focused ? Colors.white.withOpacity(0.18) : Colors.transparent,
          ),
          child: Icon(widget.icon, color: Colors.white, size: widget.size),
        ),
      ),
    );
  }
}

// ── Skip button ───────────────────────────────────────────────────────────────

class _SkipButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  const _SkipButton({required this.label, required this.onTap});
  @override
  State<_SkipButton> createState() => _SkipButtonState();
}

class _SkipButtonState extends State<_SkipButton> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) => TvNav.handle(node, event, onSelect: widget.onTap),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _focused ? Colors.white : Colors.white.withOpacity(0.4),
              width: _focused ? 2 : 1,
            ),
          ),
          child: Text(widget.label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
