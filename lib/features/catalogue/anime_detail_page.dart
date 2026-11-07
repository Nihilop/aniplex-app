import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/catalog_api.dart';
import '../../core/api/progress_api.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/anime.dart';
import '../../shared/models/catalog.dart';
import '../../shared/models/episode.dart';
import '../../ui/focus/tv_focusable.dart';
import '../../ui/widgets/lumen_cards.dart';
import '../../ui/widgets/lumen_shell.dart';

/// Fiche anime « Lumen » : backdrop, infos + boutons, liste d'épisodes.
/// Toute la page défile ; seul le titre reste épinglé en haut.
class AnimeDetailPage extends StatefulWidget {
  final String animeId;
  const AnimeDetailPage({super.key, required this.animeId});

  @override
  State<AnimeDetailPage> createState() => _AnimeDetailPageState();
}

class _AnimeDetailPageState extends State<AnimeDetailPage> {
  final _api = CatalogApi();
  final _progress = ProgressApi();
  final _scroll = ScrollController();
  late Future<AnimeDetail> _future;

  double _dim = 0; // assombrit le backdrop au défilement
  bool _fav = false;

  @override
  void initState() {
    super.initState();
    _future = _api.animeDetail(widget.animeId);
    _progress.isFavorite(widget.animeId).then((v) { if (mounted) setState(() => _fav = v); });
    _scroll.addListener(() {
      final d = (_scroll.offset / 500).clamp(0.0, 0.55);
      if ((d - _dim).abs() > 0.02) setState(() => _dim = d);
    });
  }

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  Future<void> _toggleFav() async {
    final next = !_fav;
    setState(() => _fav = next);
    final res = await _progress.setFavorite(widget.animeId, next);
    if (mounted && res != next) setState(() => _fav = res);
  }

  (List<Episode>, Episode?, bool) _playable(AnimeDetail d) {
    final playable = d.episodes.where((e) => d.hasFile(e.id)).toList()
      ..sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
    Episode? resume;
    for (final e in playable) {
      final p = d.progressFor(e.id);
      if (p != null && p.position > 0 && !p.completed) { resume = e; break; }
    }
    return (playable, resume ?? (playable.isNotEmpty ? playable.first : null), resume != null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FutureBuilder<AnimeDetail>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.foreground));
          }
          if (snap.hasError || snap.data == null) {
            return const Center(child: Text('Fiche introuvable.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 24)));
          }
          final d = snap.data!;
          final a = d.anime;
          final (_, primary, isResume) = _playable(d);
          final eps = d.episodes.toList()..sort((x, y) => (x.number ?? 0).compareTo(y.number ?? 0));

          return Stack(
            fit: StackFit.expand,
            children: [
              // Backdrop fixe + voiles
              LumenArt(seed: a.title, imageUrl: a.cover ?? a.image),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight,
                      colors: [Color(0xF008080A), Color(0x3308080A)]),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.center,
                      colors: [Color(0xF208080A), Color(0x0008080A)]),
                ),
              ),
              ColoredBox(color: const Color(0xFF08080A).withValues(alpha: _dim)),

              // Contenu défilant
              CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverPersistentHeader(pinned: true, delegate: _StickyTitle(a.title)),
                  SliverToBoxAdapter(child: _infoBody(a, primary, isResume)),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(AppTheme.safeH, 40, AppTheme.safeH, 16),
                      child: Text('Épisodes', style: TextStyle(color: AppTheme.foreground, fontSize: 34, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppTheme.safeH, 0, AppTheme.safeH, 80),
                    sliver: SliverList.builder(
                      itemCount: eps.length,
                      itemBuilder: (context, i) {
                        final e = eps[i];
                        final p = d.progressFor(e.id);
                        final available = d.hasFile(e.id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: TvFocusable(
                            centerOnFocus: true,
                            onSelect: available ? () => context.push('/watch/${widget.animeId}/${e.id}') : null,
                            builder: (context, focused) => _EpisodeTile(
                              episode: e,
                              coverSeed: a.title,
                              coverUrl: a.image ?? a.cover,
                              available: available,
                              progress: p,
                              focused: focused,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoBody(Anime a, Episode? primary, bool isResume) {
    final surtitle = [
      (a.type ?? 'ANIMÉ').toUpperCase(),
      if (a.genres.isNotEmpty) a.genres.first.toUpperCase(),
    ].join(' · ');
    final meta = [
      if (a.season != null) a.season,
      if (a.status != null) a.status,
      if (a.totalEpisodes != null) '${a.totalEpisodes} ép.',
    ].whereType<String>().join('  ·  ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.safeH, 24, AppTheme.safeH, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(surtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 2.5)),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(meta, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 24, fontWeight: FontWeight.w500)),
          ],
          if (a.synopsis != null) ...[
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Text(a.synopsis!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 25, height: 1.42)),
            ),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              if (primary != null)
                PillButton(
                  icon: Icons.play_arrow_rounded,
                  label: isResume ? 'Reprendre É${primary.number ?? '?'}' : 'Lecture É${primary.number ?? '?'}',
                  autofocus: true,
                  onTap: () => context.push('/watch/${widget.animeId}/${primary.id}'),
                ),
              if (primary != null) const SizedBox(width: 20),
              PillButton(
                icon: _fav ? Icons.check_rounded : Icons.add_rounded,
                label: 'Ma liste',
                autofocus: primary == null,
                onTap: _toggleFav,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// En-tête épinglé : seul le titre reste visible pendant le défilement.
class _StickyTitle extends SliverPersistentHeaderDelegate {
  final String title;
  _StickyTitle(this.title);

  @override
  double get minExtent => 172;
  @override
  double get maxExtent => 172;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.fromLTRB(AppTheme.safeH, 0, AppTheme.safeH, 36),
      // Fond opaque sur la majeure partie, fondu seulement sur le bord bas :
      // le contenu qui défile passe dessous sans empiler sur le titre.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF508080A), Color(0xF508080A), Color(0x0008080A)],
          stops: [0.0, 0.72, 1.0],
        ),
      ),
      child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppTheme.foreground, fontSize: 60, fontWeight: FontWeight.w800, letterSpacing: -2)),
    );
  }

  @override
  bool shouldRebuild(_StickyTitle old) => old.title != title;
}

/// Tuile d'épisode (vignette + titre + statut + barre de progression).
class _EpisodeTile extends StatelessWidget {
  final Episode episode;
  final String coverSeed;
  final String? coverUrl;
  final bool available;
  final EpisodeProgress? progress;
  final bool focused;
  const _EpisodeTile({
    required this.episode,
    required this.coverSeed,
    required this.available,
    required this.focused,
    this.coverUrl,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final fg = focused ? AppTheme.primaryForeground : AppTheme.foreground;
    final sub = focused ? const Color(0xB3000000) : AppTheme.textMuted;
    final status = progress?.completed == true
        ? 'Vu'
        : (progress != null && progress!.position > 0 ? 'En cours' : (available ? null : 'Indisponible'));

    return AnimatedScale(
      scale: focused ? 1.015 : 1.0,
      duration: AppTheme.motion,
      curve: AppTheme.ease,
      child: AnimatedContainer(
        duration: AppTheme.motion,
        height: 180,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: focused ? AppTheme.primary : AppTheme.materialLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: focused ? AppTheme.focusShadow : null,
          border: focused ? Border.all(color: AppTheme.foreground, width: 3) : null,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusThumb),
              child: Stack(
                children: [
                  LumenArt(seed: '$coverSeed${episode.number}', imageUrl: coverUrl, width: 320, height: 160),
                  if (progress != null && progress!.percent > 0)
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      child: Container(
                        height: 5,
                        color: const Color(0x4DFFFFFF),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress!.percent,
                          child: const ColoredBox(color: AppTheme.foreground),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 28),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${episode.number ?? '?'}. ${episode.title ?? 'Épisode ${episode.number ?? ''}'}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: available ? fg : fg.withValues(alpha: 0.5), fontSize: 30, fontWeight: FontWeight.w700),
                  ),
                  if (status != null) ...[
                    const SizedBox(height: 8),
                    Text(status, style: TextStyle(color: sub, fontSize: 23, fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
