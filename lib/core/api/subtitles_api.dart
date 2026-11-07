import 'api_client.dart';
import '../../shared/models/media.dart';

/// Sous-titres v2 : stock rattaché à l'épisode (ASS d'origine + polices pour un
/// rendu libass fidèle) + pistes render-engine (repli VTT).
class SubtitlesApi {
  final _api = ApiClient.instance;

  /// Stock de l'épisode — à privilégier (porte le décalage admin et les polices).
  Future<List<Subtitle>> episodeSubtitles(String episodeId) async {
    try {
      final res = await _api.get<Map<String, dynamic>>('/api/aniplex/subtitles/episode/$episodeId');
      return ((res.data?['data'] as List?) ?? [])
          .map((e) => Subtitle.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Pistes du fichier via render-engine (repli quand le stock est vide).
  Future<List<Track>> renderTracks(String sourceId) async {
    try {
      final res = await _api.get<Map<String, dynamic>>('/api/aniplex/render-engine/subs/$sourceId');
      if (res.data?['success'] != true) return const [];
      return ((res.data?['data'] as List?) ?? [])
          .map((e) => Track.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Contenu d'un sous-titre du stock. `vtt: true` → conversion serveur (décalage
  /// déjà appliqué) ; sinon l'original (ASS/SRT/VTT) à décaler via [Subtitle.offsetMs].
  Future<String?> subtitleContent(String id, {bool vtt = false}) =>
      _api.getText('/api/aniplex/subtitles/$id', params: vtt ? {'format': 'vtt'} : null);

  /// VTT d'une piste render-engine (repli sans stock).
  Future<String?> renderTrackVtt(String sourceId, int index) =>
      _api.getText('/api/aniplex/render-engine/subs/$sourceId/$index');

  /// Polices jointes au MKV, nécessaires au rendu ASS fidèle (URLs résolues en absolu).
  Future<List<SubtitleFont>> fonts(String subtitleId) async {
    try {
      final res = await _api.get<Map<String, dynamic>>('/api/aniplex/subtitles/$subtitleId/fonts');
      return ((res.data?['data'] as List?) ?? []).map((e) {
        final f = SubtitleFont.fromJson(e as Map<String, dynamic>);
        if (f.url.startsWith('http')) return f;
        return SubtitleFont(sha256: f.sha256, fileName: f.fileName, url: '${_api.baseUrl}${f.url}');
      }).toList();
    } catch (_) {
      return const [];
    }
  }
}
