import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design system V2 — tokens « Lumen TV » (cf. design_handoff_lumen_tv/README.md).
/// Thème 10-foot inspiré tvOS : fond quasi-noir, matériaux flous, focus par
/// mise à l'échelle + ombre, accent monochrome blanc. Police Poppins.
class AppTheme {
  // ── Base ──────────────────────────────────────────────────────────
  static const Color background   = Color(0xFF0B0B0D); // fond app
  static const Color foreground   = Color(0xFFF5F5F7); // texte
  static const Color textPrimary  = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xB3FFFFFF); // ~.70
  static const Color textMuted    = Color(0x8CFFFFFF);  // ~.55

  /// Accent principal monochrome : pilule/carte focus = blanc, texte noir.
  static const Color primary           = Color(0xFFF5F5F7);
  static const Color primaryForeground = Color(0xFF0B0B0D);

  // ── Matériaux flous (backdrop-filter blur+saturate côté widgets) ──
  static const Color materialDark  = Color(0x8028282E); // rgba(40,40,46,.5) — pilule nav
  static const Color materialLight = Color(0x12FFFFFF); // rgba(255,255,255,.07) — cartes
  static const Color materialLight16 = Color(0x29FFFFFF); // rgba(255,255,255,.16) — boutons repos
  static const Color borderFaint   = Color(0x14FFFFFF); // rgba(255,255,255,.08)
  static const double blurSigma    = 18.0; // ~blur(30px) visuel

  // Alias conservés pour les anciens écrans.
  static const Color surface     = materialLight;
  static const Color card        = materialLight;
  static const Color cardHover   = materialLight16;
  static const Color muted       = materialLight;
  static const Color accent      = materialLight16;
  static const Color border      = borderFaint;
  static const Color divider     = borderFaint;
  static const Color input       = materialLight;
  static const Color ring        = foreground;
  static const Color focusBorder = foreground;
  static const Color destructive = Color(0xFFE1192B);

  // ── Statuts planning ──────────────────────────────────────────────
  static const Color statusWatched  = Color(0xFF4ED589); // vu
  static const Color statusNew      = Color(0xFF37D2F2); // nouveau
  static const Color statusUpcoming = Color(0xFFF3B94C); // à venir
  static const Color statusAvailable = foreground;       // dispo

  // ── Rayons ────────────────────────────────────────────────────────
  static const double radiusPill  = 999;
  static const double radiusCard  = 20;
  static const double radiusThumb = 18;
  static const double radiusMini  = 12;
  static const double radiusBadge = 6;
  static const double radius      = radiusCard;
  static const double focusBorderWidth  = 3.0;
  static const double focusBorderRadius = radiusCard;

  // ── Zone sûre TV ──────────────────────────────────────────────────
  static const double safeH = 96;
  static const double overscanH = safeH;
  static const double overscanV = 54;
  static const EdgeInsets overscan = EdgeInsets.symmetric(horizontal: safeH, vertical: overscanV);

  // ── Ombres ────────────────────────────────────────────────────────
  static const List<BoxShadow> restShadow = [
    BoxShadow(color: Color(0x59000000), blurRadius: 24, offset: Offset(0, 10)),
  ];
  static const List<BoxShadow> focusShadow = [
    BoxShadow(color: Color(0x99000000), blurRadius: 60, offset: Offset(0, 30)),
  ];
  static const List<BoxShadow> btnFocusShadow = [
    BoxShadow(color: Color(0x73000000), blurRadius: 40, offset: Offset(0, 18)),
  ];

  // ── Motion ────────────────────────────────────────────────────────
  static const Duration motion     = Duration(milliseconds: 220); // focus
  static const Duration motionScroll = Duration(milliseconds: 500); // translations
  static const Curve    ease       = Cubic(0.2, 0.8, 0.2, 1);

  // ── ThemeData ─────────────────────────────────────────────────────
  static ThemeData get theme => dark;

  static final TextTheme _text = const TextTheme(
    displayLarge:   TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 48, letterSpacing: -1),
    displayMedium:  TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 36, letterSpacing: -.5),
    headlineLarge:  TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 28),
    headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 22),
    titleLarge:     TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 18),
    titleMedium:    TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
    bodyLarge:      TextStyle(color: textPrimary, fontSize: 16),
    bodyMedium:     TextStyle(color: textSecondary, fontSize: 14),
    bodySmall:      TextStyle(color: textMuted, fontSize: 12),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      surface:     background,
      onSurface:   foreground,
      primary:     primary,
      onPrimary:   primaryForeground,
      secondary:   materialLight16,
      onSecondary: foreground,
      error:       destructive,
      outline:     borderFaint,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(_text),
    focusColor: const Color(0x26FFFFFF),
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    cardColor: materialLight,
    dividerColor: borderFaint,
  );
}
