import 'package:flutter/material.dart';

class AppTheme {
  // Palette
  static const Color background   = Color(0xFF0F0F0F);
  static const Color surface      = Color(0xFF1A1A1A);
  static const Color card         = Color(0xFF222222);
  static const Color cardHover    = Color(0xFF2A2A2A);
  static const Color primary      = Color(0xFFE63946);
  static const Color focusBorder  = Color(0xFFFFFFFF);
  static const Color textPrimary  = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color textMuted    = Color(0xFF616161);
  static const Color divider      = Color(0xFF2A2A2A);

  // Focus ring
  static const double focusBorderWidth = 3.0;
  static const double focusBorderRadius = 8.0;

  // TV overscan safe padding
  static const double overscanH = 48.0;
  static const double overscanV = 27.0;
  static const EdgeInsets overscan = EdgeInsets.symmetric(
    horizontal: overscanH,
    vertical: overscanV,
  );

  /// Alias so app.dart can use AppTheme.theme
  static ThemeData get theme => dark;

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      surface: background,
      primary: primary,
      onPrimary: textPrimary,
      secondary: surface,
      onSecondary: textPrimary,
    ),
    textTheme: const TextTheme(
      displayLarge:  TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 48),
      displayMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 36),
      headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 28),
      headlineMedium:TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 22),
      titleLarge:    TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 18),
      titleMedium:   TextStyle(color: textPrimary, fontWeight: FontWeight.w500, fontSize: 16),
      bodyLarge:     TextStyle(color: textPrimary, fontSize: 16),
      bodyMedium:    TextStyle(color: textSecondary, fontSize: 14),
      bodySmall:     TextStyle(color: textMuted, fontSize: 12),
    ),
    focusColor: focusBorder.withOpacity(0.15),
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    cardColor: card,
  );
}
