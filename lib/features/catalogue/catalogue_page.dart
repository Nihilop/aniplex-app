import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/anime.dart';
import '../../shared/widgets/anime_card.dart';
import '../../shared/widgets/tv_scaffold.dart';

class CataloguePage extends StatefulWidget {
  const CataloguePage({super.key});

  @override
  State<CataloguePage> createState() => _CataloguePageState();
}

class _CataloguePageState extends State<CataloguePage> {
  final _api = ApiClient.instance;
  final _scrollController = ScrollController();

  List<Anime> _items   = [];
  bool        _loading = true;
  bool        _loadingMore = false;
  String?     _error;
  int         _page    = 1;
  bool        _hasMore = true;

  static const _pageSize = 40;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _page = 1; _hasMore = true; });
    try {
      final res = await _api.get<Map<String, dynamic>>(
        '/api/aniplex/catalogue',
        params: {'page': '1', 'limit': '$_pageSize'},
      );
      final data = res.data!;
      // Shape: { items: [...], total, page, limit }
      final items = (data['items'] as List? ?? [])
          .map((e) => Anime.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _items   = items;
        _loading = false;
        _hasMore = items.length >= _pageSize;
      });
    } catch (e) {
      setState(() { _error = 'Impossible de charger le catalogue.'; _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final res = await _api.get<Map<String, dynamic>>(
        '/api/aniplex/catalogue',
        params: {'page': '$next', 'limit': '$_pageSize'},
      );
      final items = (res.data!['items'] as List? ?? [])
          .map((e) => Anime.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _items.addAll(items);
        _page = next;
        _hasMore = items.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TvScaffold(
      current: NavItem.catalogue,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _load, child: const Text('Réessayer', style: TextStyle(color: AppTheme.primary))),
                    ],
                  ),
                )
              : GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.overscanH,
                    16,
                    AppTheme.overscanH,
                    AppTheme.overscanV,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 20,
                    childAspectRatio: 160 / 294, // card width / totalHeight (230+8+52+4)
                  ),
                  itemCount: _items.length + (_loadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _items.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
                        ),
                      );
                    }
                    final anime = _items[index];
                    return AnimeCard(
                      anime: anime,
                      autofocus: index == 0,
                      onTap: () => context.push('/catalogue/${anime.id}'),
                    );
                  },
                ),
    );
  }
}
