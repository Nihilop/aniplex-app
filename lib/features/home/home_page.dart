import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/update/app_updater.dart';
import '../../core/update/update_dialog.dart';
import '../../shared/models/anime.dart';
import '../../shared/widgets/tv_scaffold.dart';
import 'widgets/content_row.dart';
import 'widgets/hero_banner.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _api = ApiClient.instance;

  List<Anime> _continueWatching = [];
  List<Anime> _recentlyAdded   = [];
  List<Anime> _trending        = [];
  Anime?      _hero;
  bool        _loading         = true;
  String?     _error;

  @override
  void initState() {
    super.initState();
    _load();
    // Check update après un court délai pour ne pas bloquer le chargement
    Future.delayed(const Duration(seconds: 3), _checkUpdate);
  }

  Future<void> _checkUpdate() async {
    final release = await AppUpdater.checkForUpdate();
    if (release != null && mounted) {
      await UpdateDialog.show(context, release);
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Parallel fetches
      final results = await Future.wait([
        _api.get<Map<String, dynamic>>('/api/aniplex/home'),
      ]);
      final data = results[0].data!;
      final cw  = (data['continueWatching'] as List? ?? []).map((e) => Anime.fromJson(e as Map<String, dynamic>)).toList();
      final ra  = (data['recentlyAdded']    as List? ?? []).map((e) => Anime.fromJson(e as Map<String, dynamic>)).toList();
      final tr  = (data['trending']         as List? ?? []).map((e) => Anime.fromJson(e as Map<String, dynamic>)).toList();

      setState(() {
        _continueWatching = cw;
        _recentlyAdded    = ra;
        _trending         = tr;
        // Hero: first continue-watching, else first trending
        _hero = cw.isNotEmpty ? cw.first : (tr.isNotEmpty ? tr.first : null);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Impossible de charger le contenu.';
        _loading = false;
      });
    }
  }

  void _goDetail(Anime anime) => context.push('/catalogue/${anime.id}');

  void _goWatch(Anime anime) {
    // Navigate to detail so user can pick episode
    context.push('/catalogue/${anime.id}');
  }

  @override
  Widget build(BuildContext context) {
    return TvScaffold(
      current: NavItem.home,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 16),
                      TextButton(onPressed: _load, child: const Text('Réessayer', style: TextStyle(color: AppTheme.primary))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primary,
                  child: ListView(
                    children: [
                      // Hero banner
                      if (_hero != null)
                        HeroBanner(
                          anime: _hero!,
                          onPlay: () => _goWatch(_hero!),
                          onDetail: () => _goDetail(_hero!),
                        ),
                      const SizedBox(height: 24),

                      // Continue watching
                      if (_continueWatching.isNotEmpty) ...[
                        ContentRow(
                          title: 'Continuer à regarder',
                          items: _continueWatching,
                          onTap: _goDetail,
                          autofocusFirst: _hero == null,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Tendances
                      if (_trending.isNotEmpty) ...[
                        ContentRow(
                          title: 'Tendances',
                          items: _trending,
                          onTap: _goDetail,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Ajouts récents
                      if (_recentlyAdded.isNotEmpty) ...[
                        ContentRow(
                          title: 'Ajouts récents',
                          items: _recentlyAdded,
                          onTap: _goDetail,
                        ),
                        const SizedBox(height: AppTheme.overscanV),
                      ],
                    ],
                  ),
                ),
    );
  }
}
