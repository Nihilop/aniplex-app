import 'api_client.dart';
import '../../shared/models/catalog.dart';

/// Favoris, statistiques et compte AniList (§4). Routes enveloppées dans `{ data }`.
/// La reprise (« continue watching ») est déjà fournie par `CatalogApi.home()`.
class ProgressApi {
  final _api = ApiClient.instance;

  Future<List<String>> favoriteIds() async {
    try {
      final res = await _api.get<Map<String, dynamic>>('/api/aniplex/progress/favorites');
      return ((res.data?['data'] as List?) ?? []).map((e) => e as String).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<bool> isFavorite(String animeId) async {
    try {
      final res = await _api.get<Map<String, dynamic>>('/api/aniplex/progress/favorites/$animeId');
      return (res.data?['data']?['favorite'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Bascule idempotente (pas de DELETE côté API). Renvoie l'état résultant.
  Future<bool> setFavorite(String animeId, bool on) async {
    final res = await _api.put<Map<String, dynamic>>(
      '/api/aniplex/progress/favorites/$animeId',
      data: {'on': on},
    );
    return (res.data?['data']?['favorite'] as bool?) ?? on;
  }

  Future<WatchStats> stats() async {
    final res = await _api.get<Map<String, dynamic>>('/api/aniplex/progress/stats');
    return WatchStats.fromJson((res.data?['data'] as Map<String, dynamic>?) ?? const {});
  }

  // ── AniList ─────────────────────────────────────────────────────────
  // Le lien du compte (`/anilist/connect`) est un OAuth web : à faire via QR /
  // companion plus tard. Ici on expose l'état et la synchro descendante.

  Future<({bool configured, bool linked, String? username})> anilistStatus() async {
    try {
      final res = await _api.get<Map<String, dynamic>>('/api/aniplex/progress/anilist/status');
      final d = (res.data?['data'] as Map<String, dynamic>?) ?? const {};
      return (
        configured: d['configured'] as bool? ?? false,
        linked: d['linked'] as bool? ?? false,
        username: (d['account'] as Map<String, dynamic>?)?['username'] as String?,
      );
    } catch (_) {
      return (configured: false, linked: false, username: null);
    }
  }

  /// Synchro descendante AniList → local (synchrone, 5–30 s).
  Future<void> anilistPull() => _api.post<void>('/api/aniplex/progress/anilist/pull');
}
