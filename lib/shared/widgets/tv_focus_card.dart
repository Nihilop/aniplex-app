import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

/// Widget focusable standard pour Android TV.
/// Gère le ring de focus et l'appel onTap sur OK/Enter/Select.
class TvFocusCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final bool autofocus;
  final FocusNode? focusNode;

  const TvFocusCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = AppTheme.focusBorderRadius,
    this.padding,
    this.backgroundColor,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<TvFocusCard> createState() => _TvFocusCardState();
}

class _TvFocusCardState extends State<TvFocusCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter  ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onTap?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? AppTheme.card,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: _focused ? AppTheme.focusBorder : Colors.transparent,
              width: AppTheme.focusBorderWidth,
            ),
            boxShadow: _focused
                ? [BoxShadow(
                    color: AppTheme.focusBorder.withOpacity(0.2),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
