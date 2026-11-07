import 'api_client.dart';
import '../../shared/models/catalog.dart';

/// Endpoints agrégés « client » du catalogue (§6 api-public.md).
/// Formes NON enveloppées dans `{ data }` (historique TV).
class CatalogApi {
  final _api = ApiClient.instance;

  Future<HomeData> home() async {
    final res = await _api.get<Map<String, dynamic>>('/api/aniplex/home');
    return HomeData.fromJson(res.data ?? const {});
  }

  Future<CatalogueResult> catalogue({
    int page = 1,
    String? q,
    String? status,
    String? type,
    List<String>? genres,
    String? sortBy,
  }) async {
    final res = await _api.get<Map<String, dynamic>>('/api/aniplex/catalogue', params: {
      'page': page,
      if (q != null && q.isNotEmpty) 'q': q,
      if (status != null) 'status': status,
      if (type != null) 'type': type,
      if (genres != null && genres.isNotEmpty) 'genre': genres,
      if (sortBy != null) 'sortBy': sortBy,
    });
    return CatalogueResult.fromJson(res.data ?? const {});
  }

  Future<CatalogueResult> search(String q, {int limit = 30}) async {
    if (q.trim().isEmpty) return const CatalogueResult();
    final res = await _api.get<Map<String, dynamic>>('/api/aniplex/search', params: {
      'q': q,
      'limit': limit,
    });
    return CatalogueResult.fromJson(res.data ?? const {});
  }

  Future<AnimeDetail> animeDetail(String id) async {
    final res = await _api.get<Map<String, dynamic>>('/api/aniplex/anime/$id');
    return AnimeDetail.fromJson(res.data!);
  }

  /// 7 jours groupés par jour ISO (1 = lundi … 7 = dimanche).
  Future<Map<int, List<PlanningEntry>>> planning() async {
    final res = await _api.get<Map<String, dynamic>>('/api/aniplex/planning');
    final data = res.data ?? const {};
    final out = <int, List<PlanningEntry>>{};
    data.forEach((key, value) {
      final day = int.tryParse(key);
      if (day == null) return;
      out[day] = ((value as List?) ?? [])
          .map((e) => PlanningEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    });
    return out;
  }
}
