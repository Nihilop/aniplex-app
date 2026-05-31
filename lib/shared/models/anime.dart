class Anime {
  final String id;
  final String title;
  final String? japaneseTitle;
  final String? image;
  final String? cover;
  final String? status;
  final String? type;
  final String? season;
  final int? totalEpisodes;
  final double? voteAverage;
  final List<String> genres;
  final String? description;
  final String? trailerKey;

  /// Alias for cover (wide banner image)
  String? get banner => cover;
  /// Alias for description
  String? get synopsis => description;

  const Anime({
    required this.id,
    required this.title,
    this.japaneseTitle,
    this.image,
    this.cover,
    this.status,
    this.type,
    this.season,
    this.totalEpisodes,
    this.voteAverage,
    this.genres = const [],
    this.description,
    this.trailerKey,
  });

  factory Anime.fromJson(Map<String, dynamic> j) => Anime(
    id:             j['id'] as String,
    title:          j['title'] as String,
    japaneseTitle:  j['japaneseTitle'] as String?,
    image:          j['image'] as String?,
    cover:          j['cover'] as String?,
    status:         j['status'] as String?,
    type:           j['type'] as String?,
    season:         j['season'] as String?,
    totalEpisodes:  j['totalEpisodes'] as int?,
    voteAverage:    (j['voteAverage'] as num?)?.toDouble(),
    genres:         List<String>.from(j['genres'] as List? ?? []),
    description:    j['description'] as String?,
    trailerKey:     j['trailerKey'] as String?,
  );
}
