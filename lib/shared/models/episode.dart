class Episode {
  final String id;
  final String animeId;
  final int? number;
  final String? title;
  final String? airDate;
  final bool isFiller;
  final bool hasFile;
  final int? duration; // seconds

  const Episode({
    required this.id,
    required this.animeId,
    this.number,
    this.title,
    this.airDate,
    this.isFiller = false,
    this.hasFile = false,
    this.duration,
  });

  factory Episode.fromJson(Map<String, dynamic> j) => Episode(
    id:       j['id'] as String,
    animeId:  j['animeId'] as String,
    number:   j['number'] as int?,
    title:    j['title'] as String?,
    airDate:  j['airDate'] as String?,
    isFiller: j['isFiller'] as bool? ?? false,
    hasFile:  j['hasFile'] as bool? ?? false,
    duration: j['duration'] as int?,
  );

  String get displayTitle => title != null
      ? 'Épisode ${number ?? '?'} — $title'
      : 'Épisode ${number ?? '?'}';
}

class EpisodeProgress {
  final String episodeId;
  final double position;
  final double? duration;
  final bool completed;

  const EpisodeProgress({
    required this.episodeId,
    required this.position,
    this.duration,
    this.completed = false,
  });

  double get percent {
    if (duration == null || duration! <= 0) return 0;
    return (position / duration!).clamp(0.0, 1.0);
  }

  factory EpisodeProgress.fromJson(Map<String, dynamic> j) => EpisodeProgress(
    episodeId: j['episodeId'] as String,
    position:  (j['position'] as num).toDouble(),
    duration:  (j['duration'] as num?)?.toDouble(),
    completed: j['completed'] as bool? ?? false,
  );
}
