import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/catalog_api.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/anime.dart';
import '../../shared/models/catalog.dart';
import '../../ui/focus/tv_indexed_list.dart';
import '../../ui/widgets/lumen_cards.dart';
import '../../ui/widgets/lumen_shell.dart';

/// Accueil « Lumen ». Écran en rangées (hero · Continuer · Récent) piloté au
/// D-pad : la colonne se translate selon la rangée focus, la nav se masque, le
/// backdrop suit le titre focus.
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _tabs = ['Accueil', 'Planning', 'Animés', 'Films', 'Séries'];
  // Décalage vertical du contenu par rangée focus : 0 nav · 1 hero · 2 continuer · 3 récent.
  static const _translate = [0.0, 0.0, -380.0, -870.0];

  final _api = CatalogApi();
  late Future<HomeData> _future;

  int _row = 1;
  String? _bgUrl;
  String _bgSeed = 'aniplex';
  Anime? _featured;

  @override
  void initState() {
    super.initState();
    _future = _api.home();
  }

  void _setRow(int r) {
    if (_row != r && mounted) setState(() => _row = r);
  }

  void _setBg(Anime a) {
    final url = a.cover ?? a.image;
    if ((_bgUrl != url || _bgSeed != a.title) && mounted) {
      setState(() { _bgUrl = url; _bgSeed = a.title; });
    }
  }

  void _resetBg() {
    if (_featured != null) _setBg(_featured!);
  }

  void _onTab(int i) {
    switch (i) {
      case 1: context.go('/planning');
      case 2: context.go('/catalogue?tab=2');              // Animés (tout)
      case 3: context.go('/catalogue?type=MOVIE&tab=3');   // Films
      case 4: context.go('/catalogue?type=TV&tab=4');      // Séries
      default: break; // Accueil : déjà ici
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FutureBuilder<HomeData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.foreground));
          }
          if (snap.hasError || snap.data == null) {
            return Center(
              child: Text('Impossible de charger l’accueil.',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 24)),
            );
          }
          final data = snap.data!;
          _featured ??= data.trending.isNotEmpty
              ? data.trending.first
              : (data.recentlyAdded.isNotEmpty ? data.recentlyAdded.first : null);
          _bgUrl ??= _featured?.cover ?? _featured?.image;
          if (_featured != null) _bgSeed = _featured!.title;

          final dimmed = _row >= 2;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Backdrop + overlays
              LumenArt(seed: _bgSeed, imageUrl: _bgUrl),
              // Voile sombre global : lisibilité du texte sur n'importe quelle image.
              const ColoredBox(color: Color(0x73000000)),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xEB08080A), Color(0x8C08080A), Color(0x0008080A)],
                    stops: [0.0, 0.42, 0.75],
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [Color(0xFF08080A), Color(0x0008080A)],
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: dimmed ? 1 : 0,
                duration: AppTheme.motion,
                child: const ColoredBox(color: Color(0x8008080A)),
              ),

              // Contenu translaté (plus haut que l'écran : se translate selon la rangée).
              Positioned.fill(
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: AnimatedContainer(
                      duration: AppTheme.motionScroll,
                      curve: AppTheme.ease,
                      transform: Matrix4.translationValues(0, _translate[_row.clamp(0, 3)], 0),
                      transformAlignment: Alignment.topLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _hero(data),
                          _continueSection(data),
                          const SizedBox(height: 40),
                          _recentSection(data),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Nav
              Align(
                alignment: Alignment.topCenter,
                child: Focus(
                  canRequestFocus: false,
                  skipTraversal: true,
                  onFocusChange: (f) { if (f) _setRow(0); },
                  child: TopNavBar(tabs: _tabs, current: 0, onTab: _onTab, hidden: dimmed),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────
  Widget _hero(HomeData data) {
    final f = _featured;
    final meta = [
      if (f?.type != null) f!.type,
      if (f?.status != null) f!.status,
      if (f?.totalEpisodes != null) '${f!.totalEpisodes} ép.',
    ].whereType<String>().join('  ·  ');

    return AnimatedOpacity(
      opacity: _row >= 2 ? 0 : 1,
      duration: AppTheme.motion,
      child: SizedBox(
        height: 740,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.safeH, 0, AppTheme.safeH, 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                f?.title ?? 'Aniplex',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.foreground,
                  fontSize: 72,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -2,
                  height: 1.0,
                ),
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(meta, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 24, fontWeight: FontWeight.w500)),
              ],
              if (f?.synopsis != null) ...[
                const SizedBox(height: 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: Text(
                    f!.synopsis!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 26, height: 1.4),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Focus(
                canRequestFocus: false,
                skipTraversal: true,
                onFocusChange: (hasFocus) { if (hasFocus) { _setRow(1); _resetBg(); } },
                child: Row(
                  children: [
                    PillButton(
                      icon: Icons.play_arrow_rounded,
                      label: 'Lecture',
                      autofocus: true,
                      onTap: () { if (f != null) context.push('/catalogue/${f.id}'); },
                    ),
                    const SizedBox(width: 20),
                    PillButton(
                      icon: Icons.info_outline_rounded,
                      label: 'Plus d’infos',
                      onTap: () { if (f != null) context.push('/catalogue/${f.id}'); },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Continuer à regarder ──────────────────────────────────────────
  Widget _continueSection(HomeData data) {
    final items = data.continueWatching;
    if (items.isEmpty) return const SizedBox(height: 40);
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: AppTheme.safeH, bottom: 20),
            child: Text('Continuer à regarder',
                style: TextStyle(color: AppTheme.foreground, fontSize: 34, fontWeight: FontWeight.w700)),
          ),
          SizedBox(
            height: 300,
            child: TvIndexedList(
              axis: Axis.horizontal,
              itemCount: items.length,
              itemExtent: 456, // 416 + 40 gap
              clipBehavior: Clip.none, // ne pas rogner la carte agrandie au focus
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.safeH - 20),
              onFocusChange: (f) { if (f) { _setRow(2); _setBg(items[0].anime); } },
              onIndexChanged: (i) => _setBg(items[i].anime),
              onSelect: (i) => context.push('/watch/${items[i].anime.id}/${items[i].episodeId}'),
              itemBuilder: (context, i, focused) {
                final it = items[i];
                return ContinueCard(
                  title: it.anime.title,
                  imageUrl: it.anime.cover ?? it.anime.image,
                  subtitle: 'Reprendre', // la home ne fournit pas la durée → pas de « reste … »
                  progress: null,
                  focused: focused,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Récent ────────────────────────────────────────────────────────
  Widget _recentSection(HomeData data) {
    final items = data.recentlyAdded;
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: AppTheme.safeH, bottom: 20),
          child: Text('Récemment ajoutés',
              style: TextStyle(color: AppTheme.foreground, fontSize: 34, fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          height: 440,
          child: TvIndexedList(
            axis: Axis.horizontal,
            itemCount: items.length,
            itemExtent: 286, // 250 + 36 gap
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.safeH - 18),
            onFocusChange: (f) { if (f && items.isNotEmpty) { _setRow(3); _setBg(items[0]); } },
            onIndexChanged: (i) => _setBg(items[i]),
            onSelect: (i) => context.push('/catalogue/${items[i].id}'),
            itemBuilder: (context, i, focused) {
              final a = items[i];
              return PosterCard(
                title: a.title,
                imageUrl: a.image ?? a.cover,
                typeLabel: (a.type ?? 'ANIMÉ').toUpperCase(),
                focused: focused,
              );
            },
          ),
        ),
      ],
    );
  }
}
