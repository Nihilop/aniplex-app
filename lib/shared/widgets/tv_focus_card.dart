import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Widget focusable standard pour Android TV.
/// Gère le ring de focus, l'animation scale, et l'appel onTap sur OK/Enter.
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

class _TvFocusCardState extends State<TvFocusCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange(bool focused) {
    setState(() => _focused = focused);
    if (focused) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: _onFocusChange,
      child: ScaleTransition(
        scale: _scale,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.backgroundColor ?? AppTheme.card,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: _focused
                    ? AppTheme.focusBorder
                    : Colors.transparent,
                width: AppTheme.focusBorderWidth,
              ),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: AppTheme.focusBorder.withOpacity(0.25),
                        blurRadius: 16,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
