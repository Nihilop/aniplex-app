import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/anime.dart';
import '../../shared/models/episode.dart';
import '../../shared/widgets/tv_focus_card.dart';

class AnimeDetailPage extends StatefulWidget {
  final String animeId;
  const AnimeDetailPage({super.key, required this.animeId});

  @override
  State<AnimeDetailPage> createState() => _AnimeDetailPageState();
}

class _AnimeDetailPageState extends State<AnimeDetailPage> {
  final _api = ApiClient.instance;

  Anime?           _anime;
  List<Episode>    _episodes   = [];
  Set<String>      _withFile   = {};
  Map<String, EpisodeProgress> _progress = {};
  bool             _loading    = true;
  String?          _error;
  int              _focusedEpIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // GET /api/aniplex/anime/:id
      // Shape: { anime: {...}, episodes: [...], episodeIdsWithFile: [...], progress: [...] }
      final res = await _api.get<Map<String, dynamic>>('/api/aniplex/anime/${widget.animeId}');
      final data = res.data!;

      final anime    = Anime.fromJson(data['anime'] as Map<String, dynamic>);
      final episodes = (data['episodes'] as List? ?? [])
          .map((e) => Episode.fromJson(e as Map<String, dynamic>))
          .toList();
      final withFile = Set<String>.from(
        (data['episodeIdsWithFile'] as List? ?? []).cast<String>(),
      );
      final progressList = (data['progress'] as List? ?? [])
          .map((e) => EpisodeProgress.fromJson(e as Map<String, dynamic>));
      final progressMap = { for (final p in progressList) p.episodeId: p };

      setState(() {
        _anime     = anime;
        _episodes  = episodes;
        _withFile  = withFile;
        _progress  = progressMap;
        _loading   = false;
        // Auto-focus first episode with file
        _focusedEpIndex = episodes.indexWhere((e) => withFile.contains(e.id));
        if (_focusedEpIndex < 0) _focusedEpIndex = 0;
      });
    } catch (e) {
      setState(() { _error = 'Impossible de charger l\'anime.'; _loading = false; });
    }
  }

  void _playEpisode(Episode ep) {
    if (!_withFile.contains(ep.id)) return;
    context.push('/watch/${widget.animeId}/${ep.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final anime = _anime!;
    return Stack(
      children: [
        // Background art
        Positioned.fill(
          child: anime.banner != null || anime.image != null
              ? Image.network(
                  (anime.banner ?? anime.image)!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  loadingBuilder: (_, child, p) => p == null ? child : Container(color: AppTheme.background),
                  errorBuilder: (_, __, ___) => Container(color: AppTheme.background),
                )
              : Container(color: AppTheme.background),
        ),
        // Dark overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.background.withOpacity(0.5),
                  AppTheme.background.withOpacity(0.92),
                  AppTheme.background,
                ],
                stops: const [0.0, 0.3, 0.6],
              ),
            ),
          ),
        ),
        // Foreground content
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              Padding(
                padding: const EdgeInsets.fromLTRB(AppTheme.overscanH, AppTheme.overscanV, 0, 0),
                child: TvFocusCard(
                  onTap: () => context.pop(),
                  borderRadius: 8,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary, size: 18),
                      SizedBox(width: 6),
                      Text('Retour', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: anime info
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppTheme.overscanH, 0, 32, 0),
                        child: _AnimeInfo(anime: anime),
                      ),
                    ),
                    // Right: episode list
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: EdgeInsets.only(right: AppTheme.overscanH, bottom: AppTheme.overscanV),
                        child: _EpisodeList(
                          episodes: _episodes,
                          withFile: _withFile,
                          progress: _progress,
                          initialFocusIndex: _focusedEpIndex,
                          onPlay: _playEpisode,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Anime Info Panel ─────────────────────────────────────────────────────────

class _AnimeInfo extends StatelessWidget {
  final Anime anime;
  const _AnimeInfo({required this.anime});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          anime.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        // Meta row
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (anime.type != null) _Tag(anime.type!),
            if (anime.status != null) _Tag(anime.status!),
            if (anime.totalEpisodes != null) _Tag('${anime.totalEpisodes} ép.'),
          ],
        ),
        if (anime.synopsis != null) ...[
          const SizedBox(height: 16),
          Text(
            anime.synopsis!,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
          ),
        ],
        if (anime.genres != null && anime.genres!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: anime.genres!
                .map((g) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.divider),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(g, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
    );
  }
}

// ── Episode List ─────────────────────────────────────────────────────────────

class _EpisodeList extends StatefulWidget {
  final List<Episode> episodes;
  final Set<String>   withFile;
  final Map<String, EpisodeProgress> progress;
  final int           initialFocusIndex;
  final void Function(Episode) onPlay;

  const _EpisodeList({
    required this.episodes,
    required this.withFile,
    required this.progress,
    required this.initialFocusIndex,
    required this.onPlay,
  });

  @override
  State<_EpisodeList> createState() => _EpisodeListState();
}

class _EpisodeListState extends State<_EpisodeList> {
  final _scrollController = ScrollController();
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(widget.episodes.length, (_) => FocusNode());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialFocusIndex < _focusNodes.length) {
        _focusNodes[widget.initialFocusIndex].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final n in _focusNodes) n.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    const itemH = 72.0;
    final target = index * itemH;
    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.episodes.isEmpty) {
      return const Center(
        child: Text('Aucun épisode', style: TextStyle(color: AppTheme.textMuted)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Épisodes',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: widget.episodes.length,
            itemExtent: 72,
            itemBuilder: (context, index) {
              final ep       = widget.episodes[index];
              final hasFile  = widget.withFile.contains(ep.id);
              final progress = widget.progress[ep.id];
              return _EpisodeItem(
                episode:    ep,
                hasFile:    hasFile,
                progress:   progress,
                focusNode:  _focusNodes[index],
                onFocused:  () => _scrollToIndex(index),
                onTap:      hasFile ? () => widget.onPlay(ep) : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EpisodeItem extends StatefulWidget {
  final Episode           episode;
  final bool              hasFile;
  final EpisodeProgress?  progress;
  final FocusNode         focusNode;
  final VoidCallback      onFocused;
  final VoidCallback?     onTap;

  const _EpisodeItem({
    required this.episode,
    required this.hasFile,
    required this.focusNode,
    required this.onFocused,
    this.progress,
    this.onTap,
  });

  @override
  State<_EpisodeItem> createState() => _EpisodeItemState();
}

class _EpisodeItemState extends State<_EpisodeItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final ep        = widget.episode;
    final progress  = widget.progress;
    final completed = progress?.completed ?? false;
    final pct       = !completed && progress != null && ep.duration != null && ep.duration! > 0
        ? (progress.position / ep.duration!).clamp(0.0, 1.0)
        : null;

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) {
        setState(() => _focused = f);
        if (f) widget.onFocused();
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _focused ? AppTheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _focused ? AppTheme.focusBorder : Colors.transparent,
              width: AppTheme.focusBorderWidth,
            ),
          ),
          child: Row(
            children: [
              // Episode number
              SizedBox(
                width: 32,
                child: Text(
                  ep.number != null ? '${ep.number}' : '—',
                  style: TextStyle(
                    color: widget.hasFile ? AppTheme.textMuted : AppTheme.textMuted.withOpacity(0.4),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Thumbnail + état de visionnage
              Stack(
                children: [
                  Container(
                    width: 80, height: 46,
                    decoration: BoxDecoration(
                      color: completed ? AppTheme.primary.withOpacity(0.15) : AppTheme.card,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: widget.hasFile
                        ? Icon(
                            completed
                                ? Icons.check_circle_rounded
                                : Icons.play_circle_outline_rounded,
                            color: completed ? AppTheme.primary : AppTheme.textMuted,
                            size: 20,
                          )
                        : const Icon(Icons.lock_outline_rounded, color: AppTheme.textMuted, size: 16),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Title + progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ep.title ?? 'Épisode ${ep.number ?? '?'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.hasFile
                            ? AppTheme.textPrimary
                            : AppTheme.textMuted.withOpacity(0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (pct != null) ...[
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: pct,
                        backgroundColor: AppTheme.divider,
                        valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                        minHeight: 2,
                      ),
                    ],
                  ],
                ),
              ),
              // Status icon
              if (!widget.hasFile)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.block_rounded, color: AppTheme.textMuted, size: 14),
                )
              else if (completed)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
