import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/api/api_client.dart';
import 'core/theme/app_theme.dart';
import 'core/update/app_updater.dart';
import 'core/update/update_dialog.dart';
import 'features/auth/device_auth_page.dart';
import 'features/catalogue/anime_detail_page.dart';
import 'features/catalogue/catalogue_page.dart';
import 'features/home/home_page.dart';
import 'features/planning/planning_page.dart';
import 'features/search/search_page.dart';
import 'features/setup/setup_page.dart';
import 'features/watch/watch_page.dart';

final _router = GoRouter(
  initialLocation: '/setup',
  redirect: (context, state) async {
    final api  = ApiClient.instance;
    final path = state.matchedLocation;

    // If no base URL configured → always go to setup
    if (!api.hasBaseUrl) {
      return path == '/setup' ? null : '/setup';
    }

    // If not authenticated → go to auth (except if already there or in setup)
    if (path == '/setup') return null;

    final authed = await api.isAuthenticated();
    if (!authed) {
      return path == '/auth' ? null : '/auth';
    }
    // Authenticated — if still on /auth or /setup, redirect home
    if (path == '/auth' || path == '/setup') return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/setup', builder: (_, __) => const SetupPage()),
    GoRoute(path: '/auth',  builder: (_, __) => const DeviceAuthPage()),
    GoRoute(path: '/home',  builder: (_, __) => const HomePage()),
    GoRoute(path: '/catalogue', builder: (_, __) => const CataloguePage()),
    GoRoute(
      path: '/catalogue/:id',
      builder: (_, state) => AnimeDetailPage(animeId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/planning', builder: (_, __) => const PlanningPage()),
    GoRoute(path: '/search',   builder: (_, __) => const SearchPage()),
    GoRoute(
      path: '/watch/:animeId/:episodeId',
      builder: (_, state) => WatchPage(
        animeId:   state.pathParameters['animeId']!,
        episodeId: state.pathParameters['episodeId']!,
      ),
    ),
  ],
  errorBuilder: (_, state) => Scaffold(
    backgroundColor: AppTheme.background,
    body: Center(
      child: Text(
        'Page introuvable : ${state.error}',
        style: const TextStyle(color: AppTheme.textSecondary),
      ),
    ),
  ),
);

class AniplexApp extends StatefulWidget {
  const AniplexApp({super.key});
  @override
  State<AniplexApp> createState() => _AniplexAppState();
}

class _AniplexAppState extends State<AniplexApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Check update 5s après le démarrage — quelle que soit la page affichée
    Future.delayed(const Duration(seconds: 5), _checkUpdate);
  }

  Future<void> _checkUpdate() async {
    final release = await AppUpdater.checkForUpdate();
    if (release == null) return;
    final ctx = _navigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      await UpdateDialog.show(ctx, release);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Aniplex',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: _router,
    );
  }
}
