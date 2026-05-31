import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Helper D-pad — port depuis Animax.
/// Usage dans Focus.onKeyEvent :
///   onKeyEvent: (node, event) => TvNav.handle(node, event, onSelect: ..., onArrowLeft: ...)
class TvNav {
  TvNav._();

  static KeyEventResult handle(
    FocusNode node,
    KeyEvent event, {
    VoidCallback? onSelect,
    VoidCallback? onArrowUp,
    VoidCallback? onArrowDown,
    VoidCallback? onArrowLeft,
    VoidCallback? onArrowRight,
    VoidCallback? onBack,
  }) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (onSelect != null &&
        (event.logicalKey == LogicalKeyboardKey.select ||
         event.logicalKey == LogicalKeyboardKey.enter  ||
         event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
      onSelect();
      return KeyEventResult.handled;
    }
    if (onArrowUp != null && event.logicalKey == LogicalKeyboardKey.arrowUp) {
      onArrowUp(); return KeyEventResult.handled;
    }
    if (onArrowDown != null && event.logicalKey == LogicalKeyboardKey.arrowDown) {
      onArrowDown(); return KeyEventResult.handled;
    }
    if (onArrowLeft != null && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      onArrowLeft(); return KeyEventResult.handled;
    }
    if (onArrowRight != null && event.logicalKey == LogicalKeyboardKey.arrowRight) {
      onArrowRight(); return KeyEventResult.handled;
    }
    if (onBack != null &&
        (event.logicalKey == LogicalKeyboardKey.goBack ||
         event.logicalKey == LogicalKeyboardKey.escape)) {
      onBack(); return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}
