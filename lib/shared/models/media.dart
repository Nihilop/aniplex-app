import 'episode.dart';

/// Réponse de `GET /api/aniplex/watch/:animeId/:episodeId` — tout ce qu'il faut
/// au lecteur.
class WatchData {
  final Episode episode;
  final String? sourceId;   // id du MediaFile pour render-engine (null = aucun fichier)
  final String? hlsUrl;     // /api/aniplex/render-engine/hls/<sourceId>/index.m3u8
  final int startPosition;  // secondes, reprise

  const WatchData({
    required this.episode,
    this.sourceId,
    this.hlsUrl,
    this.startPosition = 0,
  });

  factory WatchData.fromJson(Map<String, dynamic> j) => WatchData(
        episode:       Episode.fromJson(j['episode'] as Map<String, dynamic>),
        sourceId:      j['sourceId'] as String?,
        hlsUrl:        (j['hlsUrl'] ?? j['streamUrl']) as String?,
        startPosition: (j['startPosition'] as num?)?.toInt() ?? 0,
      );
}

/// DTO d'une piste (sous-titres ou audio) renvoyé par
/// `GET /api/aniplex/render-engine/subs|audio/:source`.
class Track {
  final int index;
  final String? lang;      // code canonique, null = inconnue
  final String? langName;  // « Français »
  final String label;      // prêt à afficher : « Français · Signs (forcé) »
  final String? title;
  final String? codec;
  final bool isDefault;
  final bool forced;
  final bool hearingImpaired;
  final int? channels;        // audio
  final String? subtitleId;   // présent si la piste est dans le stock
  final String? origin;       // embedded | sidecar | upload | translated
  final bool otherRelease;
  final String? translatedFrom;

  const Track({
    required this.index,
    required this.label,
    this.lang,
    this.langName,
    this.title,
    this.codec,
    this.isDefault = false,
    this.forced = false,
    this.hearingImpaired = false,
    this.channels,
    this.subtitleId,
    this.origin,
    this.otherRelease = false,
    this.translatedFrom,
  });

  factory Track.fromJson(Map<String, dynamic> j) => Track(
        index:           (j['index'] as num).toInt(),
        lang:            j['lang'] as String?,
        langName:        j['langName'] as String?,
        label:           j['label'] as String? ?? 'Piste ${(j['index'] as num).toInt() + 1}',
        title:           j['title'] as String?,
        codec:           j['codec'] as String?,
        isDefault:       j['default'] as bool? ?? false,
        forced:          j['forced'] as bool? ?? false,
        hearingImpaired: j['hearingImpaired'] as bool? ?? false,
        channels:        (j['channels'] as num?)?.toInt(),
        subtitleId:      j['subtitleId'] as String?,
        origin:          j['origin'] as String?,
        otherRelease:    j['otherRelease'] as bool? ?? false,
        translatedFrom:  j['translatedFrom'] as String?,
      );
}

/// Sous-titre du stock — `GET /api/aniplex/subtitles/episode/:episodeId`.
class Subtitle {
  final String id;
  final String? lang;
  final String? langName;
  final String label;
  final String? title;
  final String format; // ass | srt | vtt | sup | mks
  final bool forced;
  final bool isDefault;
  final bool sdh;
  final int offsetMs;
  final String origin;

  const Subtitle({
    required this.id,
    required this.label,
    required this.format,
    this.lang,
    this.langName,
    this.title,
    this.forced = false,
    this.isDefault = false,
    this.sdh = false,
    this.offsetMs = 0,
    this.origin = 'embedded',
  });

  /// Format texte rendu par libass (les formats image ne le sont pas).
  bool get isText => format == 'ass' || format == 'srt' || format == 'vtt';

  factory Subtitle.fromJson(Map<String, dynamic> j) => Subtitle(
        id:        j['id'] as String,
        lang:      j['lang'] as String?,
        langName:  j['langName'] as String?,
        label:     j['label'] as String? ?? 'Sous-titre',
        title:     j['title'] as String?,
        format:    j['format'] as String? ?? 'vtt',
        forced:    j['forced'] as bool? ?? false,
        isDefault: j['isDefault'] as bool? ?? false,
        sdh:       j['sdh'] as bool? ?? false,
        offsetMs:  (j['offsetMs'] as num?)?.toInt() ?? 0,
        origin:    j['origin'] as String? ?? 'embedded',
      );
}

/// Police jointe au MKV — `GET /api/aniplex/subtitles/:id/fonts`.
class SubtitleFont {
  final String sha256;
  final String fileName;
  final String url;

  const SubtitleFont({required this.sha256, required this.fileName, required this.url});

  factory SubtitleFont.fromJson(Map<String, dynamic> j) => SubtitleFont(
        sha256:   j['sha256'] as String,
        fileName: j['fileName'] as String? ?? '${j['sha256']}.ttf',
        url:      j['url'] as String,
      );
}

/// Passage sautable (OP/ED/récap/aperçu) — `GET /api/aniplex/segments/episode/:episodeId`.
class Segment {
  final String kind; // intro | outro | recap | preview
  final int startMs;
  final int endMs;

  const Segment({required this.kind, required this.startMs, required this.endMs});

  factory Segment.fromJson(Map<String, dynamic> j) => Segment(
        kind:    j['kind'] as String,
        startMs: (j['startMs'] as num).toInt(),
        endMs:   (j['endMs'] as num).toInt(),
      );
}
