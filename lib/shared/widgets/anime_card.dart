import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/anime.dart';
import 'tv_focus_card.dart';

class AnimeCard extends StatelessWidget {
  final Anime anime;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final bool autofocus;
  final FocusNode? focusNode;

  // Zone de texte fixe sous l'image : title (2 lignes) + subtitle
  static const _textAreaH = 52.0;

  const AnimeCard({
    super.key,
    required this.anime,
    this.onTap,
    this.width  = 160,
    this.height = 230,
    this.autofocus = false,
    this.focusNode,
  });

  /// Hauteur totale de la card (image + espacement + texte).
  double get totalHeight => height + 8 + _textAreaH;

  @override
  Widget build(BuildContext context) {
    return TvFocusCard(
      onTap: onTap,
      autofocus: autofocus,
      focusNode: focusNode,
      borderRadius: 10,
      backgroundColor: Colors.transparent,
      child: SizedBox(
        width: width,
        height: totalHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Poster ───────────────────────────────────────────────
            SizedBox(
              width: width,
              height: height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: anime.image != null
                    ? Image.network(
                        anime.image!,
                        width: width,
                        height: height,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) =>
                            progress == null ? child : _placeholder(),
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
            const SizedBox(height: 8),
            // ── Métadonnées (budget fixe) ─────────────────────────
            SizedBox(
              height: _textAreaH,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anime.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                  if (anime.type != null || anime.totalEpisodes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        [
                          anime.type,
                          if (anime.totalEpisodes != null) '${anime.totalEpisodes} ép.',
                        ].whereType<String>().join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.movie, color: AppTheme.textMuted, size: 32),
  );
}
