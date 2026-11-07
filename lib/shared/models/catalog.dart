import 'anime.dart';
import 'episode.dart';

/// Carte « reprendre » de la home : un anime + l'épisode en cours.
class ContinueItem {
  final Anime anime;
  final String episodeId;
  final int positionSeconds;

  const ContinueItem({required this.anime, required this.episodeId, required this.positionSeconds});

  factory ContinueItem.fromJson(Map<String, dynamic> j) => ContinueItem(
        anime:           Anime.fromJson(j),
        episodeId:       j['episodeId'] as String,
        positionSeconds: (j['positionSeconds'] as num?)?.toInt() ?? 0,
      );
}

/// `GET /api/aniplex/home`.
class HomeData {
  final List<ContinueItem> continueWatching;
  final List<Anime> recentlyAdded;
  final List<Anime> trending;

  const HomeData({
    this.continueWatching = const [],
    this.recentlyAdded = const [],
    this.trending = const [],
  });

  static List<Anime> _cards(dynamic list) =>
      ((list as List?) ?? []).map((e) => Anime.fromJson(e as Map<String, dynamic>)).toList();

  factory HomeData.fromJson(Map<String, dynamic> j) => HomeData(
        continueWatching: ((j['continueWatching'] as List?) ?? [])
            .map((e) => ContinueItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        recentlyAdded: _cards(j['recentlyAdded']),
        trending:      _cards(j['trending']),
      );
}

/// `GET /api/aniplex/catalogue` et `/search` : `{ items, total, ... }`.
class CatalogueResult {
  final List<Anime> items;
  final int total;

  const CatalogueResult({this.items = const [], this.total = 0});

  factory CatalogueResult.fromJson(Map<String, dynamic> j) => CatalogueResult(
        items: ((j['items'] as List?) ?? [])
            .map((e) => Anime.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (j['total'] as num?)?.toInt() ?? 0,
      );
}

/// `GET /api/aniplex/anime/:id` : fiche + épisodes + lisibles + progression.
class AnimeDetail {
  final Anime anime;
  final List<Episode> episodes;
  final Set<String> episodeIdsWithFile;
  final List<EpisodeProgress> progress;

  const AnimeDetail({
    required this.anime,
    this.episodes = const [],
    this.episodeIdsWithFile = const {},
    this.progress = const [],
  });

  bool hasFile(String episodeId) => episodeIdsWithFile.contains(episodeId);

  EpisodeProgress? progressFor(String episodeId) {
    for (final p in progress) {
      if (p.episodeId == episodeId) return p;
    }
    return null;
  }

  factory AnimeDetail.fromJson(Map<String, dynamic> j) => AnimeDetail(
        anime: Anime.fromJson(j['anime'] as Map<String, dynamic>),
        episodes: ((j['episodes'] as List?) ?? [])
            .map((e) => Episode.fromJson(e as Map<String, dynamic>))
            .toList(),
        episodeIdsWithFile:
            ((j['episodeIdsWithFile'] as List?) ?? []).map((e) => e as String).toSet(),
        progress: ((j['progress'] as List?) ?? [])
            .map((e) => EpisodeProgress.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// `GET /api/aniplex/planning` : une entrée par épisode programmé.
class PlanningEntry {
  final String animeId;
  final String title;
  final String? image;
  final int? episodeNumber;
  final String airDate;
  final bool available;

  const PlanningEntry({
    required this.animeId,
    required this.title,
    required this.airDate,
    this.image,
    this.episodeNumber,
    this.available = false,
  });

  factory PlanningEntry.fromJson(Map<String, dynamic> j) => PlanningEntry(
        animeId:       j['animeId'] as String,
        title:         j['title'] as String,
        image:         j['image'] as String?,
        episodeNumber: (j['episodeNumber'] as num?)?.toInt(),
        airDate:       j['airDate'] as String,
        available:     j['available'] as bool? ?? false,
      );
}

/// `GET /api/aniplex/progress/stats`.
class WatchStats {
  final int episodesStarted;
  final int episodesCompleted;
  final int animesTouched;
  final int favoritesCount;
  final int secondsWatched;

  const WatchStats({
    this.episodesStarted = 0,
    this.episodesCompleted = 0,
    this.animesTouched = 0,
    this.favoritesCount = 0,
    this.secondsWatched = 0,
  });

  factory WatchStats.fromJson(Map<String, dynamic> j) => WatchStats(
        episodesStarted:   (j['episodesStarted'] as num?)?.toInt() ?? 0,
        episodesCompleted: (j['episodesCompleted'] as num?)?.toInt() ?? 0,
        animesTouched:     (j['animesTouched'] as num?)?.toInt() ?? 0,
        favoritesCount:    (j['favoritesCount'] as num?)?.toInt() ?? 0,
        secondsWatched:    (j['secondsWatched'] as num?)?.toInt() ?? 0,
      );
}
