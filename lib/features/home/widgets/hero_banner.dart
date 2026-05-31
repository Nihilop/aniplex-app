import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/anime.dart';
import '../../../shared/widgets/tv_focus_card.dart';

class HeroBanner extends StatelessWidget {
  final Anime anime;
  final VoidCallback? onPlay;
  final VoidCallback? onDetail;

  const HeroBanner({
    super.key,
    required this.anime,
    this.onPlay,
    this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          if (anime.banner != null || anime.image != null)
            Image.network(
              (anime.banner ?? anime.image)!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              loadingBuilder: (_, child, p) => p == null ? child : Container(color: AppTheme.surface),
              errorBuilder: (_, __, ___) => Container(color: AppTheme.surface),
            )
          else
            Container(color: AppTheme.surface),

          // Gradient overlay
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  Colors.transparent,
                  AppTheme.background.withOpacity(0.6),
                  AppTheme.background.withOpacity(0.95),
                ],
                stops: const [0.3, 0.6, 1.0],
              ),
            ),
          ),
          // Bottom gradient
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, AppTheme.background],
                stops: [0.6, 1.0],
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.overscanH, 24, AppTheme.overscanH, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Badges
                if (anime.type != null || anime.status != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        if (anime.type != null) _Badge(anime.type!),
                        if (anime.type != null && anime.status != null)
                          const SizedBox(width: 8),
                        if (anime.status != null) _Badge(anime.status!),
                      ],
                    ),
                  ),
                // Title
                Text(
                  anime.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                // Synopsis
                if (anime.synopsis != null)
                  SizedBox(
                    width: 480,
                    child: Text(
                      anime.synopsis!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                // Buttons
                Row(
                  children: [
                    TvFocusCard(
                      onTap: onPlay,
                      autofocus: true,
                      borderRadius: 6,
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 6),
                          Text('Regarder', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    TvFocusCard(
                      onTap: onDetail,
                      borderRadius: 6,
                      backgroundColor: AppTheme.surface,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline_rounded, color: AppTheme.textPrimary, size: 20),
                          SizedBox(width: 6),
                          Text('Détails', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}
