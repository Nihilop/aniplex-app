import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/net_img.dart';

/// Placeholder « art(hue) » du proto : dégradé radial oklch dérivé d'une graine,
/// remplacé par la vraie image quand elle existe.
class LumenArt extends StatelessWidget {
  final String seed;
  final String? imageUrl;
  final double? width;
  final double? height;
  const LumenArt({super.key, required this.seed, this.imageUrl, this.width, this.height});

  Color _hue(double light, double sat) {
    final h = (seed.hashCode % 360).abs().toDouble();
    return HSLColor.fromAHSL(1, h, sat, light).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final grad = DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.5),
          radius: 1.2,
          colors: [_hue(0.42, 0.45), _hue(0.16, 0.5)],
        ),
      ),
      child: SizedBox(width: width, height: height),
    );
    if (imageUrl == null || imageUrl!.isEmpty) return grad;
    return SizedBox(
      width: width,
      height: height,
      child: NetImg(
        imageUrl!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_) => grad,
        errorWidget: (_) => grad,
      ),
    );
  }
}

/// Affiche verticale 250×375 (Récent / Catalogue). Focus : scale 1.1 + ombre +
/// reflet spéculaire. Le `focused` vient de la [TvIndexedList] parente.
class PosterCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final String? typeLabel; // FILM / SÉRIE / ANIMÉ
  final String? metaLabel; // « ANIMÉ · 2025 »
  final bool focused;
  final double width;
  final double height;
  final double sideMargin;   // 18 pour les rangées, 0 en grille
  final bool scaleOnFocus;   // false en grille (évite la découpe par les cellules)

  const PosterCard({
    super.key,
    required this.title,
    this.imageUrl,
    this.typeLabel,
    this.metaLabel,
    this.focused = false,
    this.width = 250,
    this.height = 375,
    this.sideMargin = 18,
    this.scaleOnFocus = true,
  });

  @override
  Widget build(BuildContext context) {
    final poster = AnimatedScale(
      scale: focused && scaleOnFocus ? 1.1 : 1.0,
      duration: AppTheme.motion,
      curve: AppTheme.ease,
      child: AnimatedContainer(
        duration: AppTheme.motion,
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: focused ? AppTheme.focusShadow : AppTheme.restShadow,
          // Bord toujours présent (transparent au repos) → la taille ne change pas
          // au focus, l'anneau épouse exactement les coins de la carte.
          border: Border.all(color: focused ? AppTheme.foreground : Colors.transparent, width: 4),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            LumenArt(seed: title, imageUrl: imageUrl, width: width, height: height),
            // Dégradé bas pour lisibilité du titre
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: [Color(0xCC000000), Color(0x00000000)],
                ),
              ),
            ),
            // Reflet spéculaire au focus
            AnimatedOpacity(
              opacity: focused ? 1 : 0,
              duration: AppTheme.motion,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0x47FFFFFF), Color(0x00FFFFFF)],
                    stops: [0.0, 0.45],
                  ),
                ),
              ),
            ),
            if ((metaLabel ?? typeLabel) != null)
              Positioned(
                left: 14,
                top: 14,
                child: Text(
                  (metaLabel ?? typeLabel)!,
                  style: const TextStyle(
                    color: AppTheme.foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.foreground,
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Padding(padding: EdgeInsets.symmetric(horizontal: sideMargin), child: poster);
  }
}

/// Carte « Continuer à regarder » 16:9 416×234 avec barre de progression.
class ContinueCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final String subtitle; // « S1 · É4 — reste 19 min »
  final double? progress; // 0..1, null = barre masquée (durée inconnue)
  final bool focused;
  final double width;
  final double height;

  const ContinueCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.progress,
    this.focused = false,
    this.width = 416,
    this.height = 234,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: focused ? 1.08 : 1.0,
            duration: AppTheme.motion,
            curve: AppTheme.ease,
            child: AnimatedContainer(
              duration: AppTheme.motion,
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                boxShadow: focused ? AppTheme.focusShadow : AppTheme.restShadow,
                border: Border.all(color: focused ? AppTheme.foreground : Colors.transparent, width: 4),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LumenArt(seed: title, imageUrl: imageUrl, width: width, height: height),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                        colors: [Color(0xB3000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 22,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.foreground,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  // Barre de progression (si durée connue)
                  if (progress != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 6,
                        color: const Color(0x4DFFFFFF),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress!.clamp(0.0, 1.0),
                          child: const ColoredBox(color: AppTheme.foreground),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: width,
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: focused ? AppTheme.foreground : AppTheme.textMuted,
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
