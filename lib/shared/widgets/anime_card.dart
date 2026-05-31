import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/anime.dart';
import 'tv_focus_card.dart';

class AnimeCard extends StatelessWidget {
  final Anime anime;
  final VoidCallback? onTap;
  final bool autofocus;
  final FocusNode? focusNode;

  // Ratio hauteur/largeur du poster (format affiche)
  static const _posterRatio = 3 / 2;
  // Zone texte fixe sous l'image
  static const _textAreaH   = 52.0;

  const AnimeCard({
    super.key,
    required this.anime,
    this.onTap,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusCard(
      onTap: onTap,
      autofocus: autofocus,
      focusNode: focusNode,
      borderRadius: 10,
      backgroundColor: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w      = constraints.maxWidth;
          final imgH   = w * _posterRatio;
          final totalH = imgH + 8 + _textAreaH;

          return SizedBox(
            width: w,
            height: totalH,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Poster ─────────────────────────────────────────
                SizedBox(
                  width: w,
                  height: imgH,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: anime.image != null
                        ? Image.network(
                            anime.image!,
                            fit: BoxFit.cover,
                            width: w,
                            height: imgH,
                            loadingBuilder: (_, child, p) =>
                                p == null ? child : _placeholder(w, imgH),
                            errorBuilder: (_, __, ___) => _placeholder(w, imgH),
                          )
                        : _placeholder(w, imgH),
                  ),
                ),
                const SizedBox(height: 8),
                // ── Texte ───────────────────────────────────────────
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
                          fontSize: 12,
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
                              if (anime.totalEpisodes != null)
                                '${anime.totalEpisodes} ép.',
                            ].whereType<String>().join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _placeholder(double w, double h) => Container(
    width: w, height: h,
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.movie, color: AppTheme.textMuted, size: 28),
  );
}
