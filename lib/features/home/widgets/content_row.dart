import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/anime.dart';
import '../../../shared/widgets/anime_card.dart';

/// Ligne horizontale scrollable de cards anime.
/// Navigation D-pad : LEFT/RIGHT scrollent dans la liste.
class ContentRow extends StatefulWidget {
  final String title;
  final List<Anime> items;
  final void Function(Anime)? onTap;
  final bool autofocusFirst;

  const ContentRow({
    super.key,
    required this.title,
    required this.items,
    this.onTap,
    this.autofocusFirst = false,
  });

  @override
  State<ContentRow> createState() => _ContentRowState();
}

class _ContentRowState extends State<ContentRow> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.overscanH, 0, AppTheme.overscanH, 12),
          child: Text(
            widget.title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 294, // image(230) + spacing(8) + textArea(52) + focus ring margin(4)
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.overscanH),
            itemCount: widget.items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final anime = widget.items[index];
              return AnimeCard(
                anime: anime,
                autofocus: widget.autofocusFirst && index == 0,
                onTap: () => widget.onTap?.call(anime),
              );
            },
          ),
        ),
      ],
    );
  }
}
