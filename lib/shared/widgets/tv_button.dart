import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

/// Bouton D-pad-ready pour Android TV.
/// Gère focus visuel + OK/Enter/Select/GameButtonA de la télécommande.
class TvButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool autofocus;
  final FocusNode? focusNode;
  final Color? backgroundColor;
  final Color? focusColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool outlined;

  const TvButton({
    super.key,
    required this.child,
    this.onTap,
    this.autofocus    = false,
    this.focusNode,
    this.backgroundColor,
    this.focusColor,
    this.padding      = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.borderRadius = 8,
    this.outlined     = false,
  });

  @override
  State<TvButton> createState() => _TvButtonState();
}

class _TvButtonState extends State<TvButton> {
  bool _focused = false;

  static bool _isOk(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.select        ||
      k == LogicalKeyboardKey.enter         ||
      k == LogicalKeyboardKey.gameButtonA   ||
      k == LogicalKeyboardKey.space;

  @override
  Widget build(BuildContext context) {
    final bg = widget.outlined
        ? Colors.transparent
        : (_focused
            ? (widget.focusColor ?? AppTheme.primary).withOpacity(0.85)
            : (widget.backgroundColor ?? AppTheme.primary));

    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent && _isOk(event.logicalKey)) {
          widget.onTap?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: _focused
                  ? Colors.white
                  : (widget.outlined ? AppTheme.divider : Colors.transparent),
              width: 2,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
