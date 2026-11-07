import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/catalog_api.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/anime.dart';
import '../../shared/models/catalog.dart';
import '../../ui/focus/tv_focusable.dart';
import '../../ui/widgets/lumen_cards.dart';
import '../../ui/widgets/lumen_shell.dart';

/// Catalogue « Lumen » : onglet Films / Séries / Animés (mappé sur le `type`
/// anime), chips de genre dérivées du contenu, grille d'affiches en nav 2D.
class CataloguePage extends StatefulWidget {
  final String? type;   // null = tout (Animés) · 'Movie' (Films) · 'TV' (Séries)
  final int tabIndex;   // index dans la barre de nav (2/3/4)
  const CataloguePage({super.key, this.type, this.tabIndex = 2});

  @override
  State<CataloguePage> createState() => _CataloguePageState();
}

class _CataloguePageState extends State<CataloguePage> {
  static const _tabs = ['Accueil', 'Planning', 'Animés', 'Films', 'Séries'];

  final _api = CatalogApi();
  late Future<CatalogueResult> _future;
  List<Anime> _items = [];
  String? _genre; // null = Tout

  @override
  void initState() {
    super.initState();
    _future = _api.catalogue(type: widget.type, page: 1);
  }

  String get _title => switch (widget.tabIndex) { 3 => 'Films', 4 => 'Séries', _ => 'Animés' };

  List<String> get _genres {
    final s = <String>{};
    for (final a in _items) {
      s.addAll(a.genres);
    }
    final list = s.toList()..sort();
    return list;
  }

  List<Anime> get _filtered =>
      _genre == null ? _items : _items.where((a) => a.genres.contains(_genre)).toList();

  void _onTab(int i) {
    switch (i) {
      case 0: context.go('/home');
      case 1: context.go('/planning');
      case 2: context.go('/catalogue?tab=2');
      case 3: context.go('/catalogue?type=MOVIE&tab=3');
      case 4: context.go('/catalogue?type=TV&tab=4');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FutureBuilder<CatalogueResult>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.foreground));
          }
          _items = snap.data?.items ?? [];
          final items = _filtered;
          final genres = _genres;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TopNavBar(tabs: _tabs, current: widget.tabIndex, onTab: _onTab),
              // Titre + compteur
              Padding(
                padding: const EdgeInsets.fromLTRB(AppTheme.safeH, 8, AppTheme.safeH, 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(_title, style: const TextStyle(color: AppTheme.foreground, fontSize: 84, fontWeight: FontWeight.w800, letterSpacing: -2)),
                    const SizedBox(width: 24),
                    Text('${items.length} titres', style: const TextStyle(color: AppTheme.textMuted, fontSize: 26)),
                  ],
                ),
              ),
              // Chips de genre
              if (genres.isNotEmpty)
                SizedBox(
                  height: 72,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.safeH),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: NavTab(label: 'Tout', selected: _genre == null, onTap: () => setState(() => _genre = null)),
                      ),
                      for (final g in genres)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: NavTab(label: g, selected: _genre == g, onTap: () => setState(() => _genre = g)),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              // Grille
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text('Aucun titre dans cette catégorie pour le moment.',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 24)))
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(AppTheme.safeH, 8, AppTheme.safeH, 64),
                        cacheExtent: 1600,
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 286,
                          childAspectRatio: 250 / 430, // affiche + marge titre
                          mainAxisSpacing: 48,
                          crossAxisSpacing: 36,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final a = items[i];
                          return TvFocusable(
                            autofocus: i == 0,
                            centerOnFocus: true,
                            onSelect: () => context.push('/catalogue/${a.id}'),
                            builder: (context, focused) => PosterCard(
                              title: a.title,
                              imageUrl: a.image ?? a.cover,
                              metaLabel: [
                                (a.type ?? 'ANIMÉ').toUpperCase(),
                                if (a.season != null) a.season!.toUpperCase(),
                              ].join(' · '),
                              focused: focused,
                              width: 250,
                              height: 375,
                              sideMargin: 0,
                              scaleOnFocus: false, // grille : anneau seul, pas de découpe
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
