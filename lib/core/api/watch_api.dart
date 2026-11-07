import 'api_client.dart';
import '../../shared/models/media.dart';

/// Lecture : résolution de la source, heartbeat de progression, passages sautables.
class WatchApi {
  final _api = ApiClient.instance;

  /// `GET /api/aniplex/watch/:animeId/:episodeId` — l'URL HLS est résolue en absolu.
  Future<WatchData> watch(String animeId, String episodeId) async {
    final res = await _api.get<Map<String, dynamic>>('/api/aniplex/watch/$animeId/$episodeId');
    final data = WatchData.fromJson(res.data!);
    final hls = data.hlsUrl;
    if (hls == null || hls.isEmpty || hls.startsWith('http')) return data;
    return WatchData(
      episode:       data.episode,
      sourceId:      data.sourceId,
      hlsUrl:        '${_api.baseUrl}$hls',
      startPosition: data.startPosition,
    );
  }

  /// Variante TV du heartbeat (§6). `finished: true` marque aussi l'épisode vu.
  Future<void> saveProgress(
    String episodeId, {
    required String animeId,
    required int positionSeconds,
    int? durationSeconds,
    bool finished = false,
  }) async {
    try {
      await _api.post<void>('/api/aniplex/progress/$episodeId', data: {
        'animeId': animeId,
        'positionSeconds': positionSeconds,
        'durationSeconds': durationSeconds != null && durationSeconds > 0 ? durationSeconds : null,
        'finished': finished,
      });
    } catch (_) {
      // Non bloquant : une progression ratée n'interrompt pas la lecture.
    }
  }

  /// Durée totale du fichier (s) via `hls/:source/info` — fiable même quand le
  /// flux HLS transcodé ne l'annonce pas au player.
  Future<int?> hlsDuration(String sourceId) async {
    try {
      final res = await _api.get<Map<String, dynamic>>('/api/aniplex/render-engine/hls/$sourceId/info');
      final d = (res.data?['duration'] as num?)?.toInt();
      return d != null && d > 0 ? d : null;
    } catch (_) {
      return null;
    }
  }

  /// `GET /api/aniplex/segments/episode/:episodeId` — OP/ED/récap/aperçu (vide sans fichier).
  Future<List<Segment>> segments(String episodeId) async {
    try {
      final res = await _api.get<Map<String, dynamic>>('/api/aniplex/segments/episode/$episodeId');
      return ((res.data?['data'] as List?) ?? [])
          .map((e) => Segment.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
