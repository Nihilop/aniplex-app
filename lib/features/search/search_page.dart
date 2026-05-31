import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/anime.dart';
import '../../shared/widgets/anime_card.dart';
import '../../shared/widgets/tv_scaffold.dart';

/// Page recherche TV : clavier D-pad à gauche, résultats à droite.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _api   = ApiClient.instance;
  final _query = StringBuffer();

  List<Anime>   _results   = [];
  bool          _searching = false;
  Timer?        _debounce;

  // Keyboard layout
  static const _rows = [
    ['A','B','C','D','E','F','G'],
    ['H','I','J','K','L','M','N'],
    ['O','P','Q','R','S','T','U'],
    ['V','W','X','Y','Z','0','1'],
    ['2','3','4','5','6','7','8'],
    ['9','⌫','Espace','✓'],
  ];

  // Focus management: keyboard side vs results side
  final _keyboardFocusScope = FocusScopeNode();
  final _resultsFocusScope  = FocusScopeNode();
  bool _inResults = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _keyboardFocusScope.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _keyboardFocusScope.dispose();
    _resultsFocusScope.dispose();
    super.dispose();
  }

  void _onKey(String key) {
    if (key == '⌫') {
      if (_query.isNotEmpty) {
        final s = _query.toString();
        _query.clear();
        _query.write(s.substring(0, s.length - 1));
      }
    } else if (key == 'Espace') {
      _query.write(' ');
    } else if (key == '✓') {
      // Confirm — move focus to results
      if (_results.isNotEmpty) {
        setState(() => _inResults = true);
        _resultsFocusScope.requestFocus();
      }
      return;
    } else {
      _query.write(key);
    }
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  Future<void> _search() async {
    final q = _query.toString().trim();
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      // GET /api/aniplex/search?q=&limit= → { items: [...], total }
      final res = await _api.get<Map<String, dynamic>>(
        '/api/aniplex/search',
        params: {'q': q, 'limit': '30'},
      );
      final items = (res.data!['items'] as List? ?? [])
          .map((e) => Anime.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() { _results = items; _searching = false; });
    } catch (_) {
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TvScaffold(
      current: NavItem.search,
      child: Row(
        children: [
          // ── Keyboard panel ───────────────────────────────────────────
          SizedBox(
            width: 340,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.overscanH, 16, 24, AppTheme.overscanV),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Query display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Text(
                      _query.isEmpty ? 'Rechercher...' : _query.toString(),
                      style: TextStyle(
                        color: _query.isEmpty ? AppTheme.textMuted : AppTheme.textPrimary,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Keyboard
                  Expanded(
                    child: FocusScope(
                      node: _keyboardFocusScope,
                      child: _TvKeyboard(onKey: _onKey),
                    ),
                  ),
                  // Arrow hint
                  if (!_inResults && _results.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.arrow_forward_rounded, color: AppTheme.textMuted, size: 14),
                          SizedBox(width: 4),
                          Text('Appuie sur ✓ pour voir les résultats',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Divider
          Container(width: 1, color: AppTheme.divider, margin: const EdgeInsets.symmetric(vertical: 16)),
          // ── Results panel ────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, AppTheme.overscanH, AppTheme.overscanV),
              child: Focus(
                onKeyEvent: (node, event) {
                  // Press LEFT to go back to keyboard
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                      _inResults) {
                    setState(() => _inResults = false);
                    _keyboardFocusScope.requestFocus();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: FocusScope(
                  node: _resultsFocusScope,
                  child: _SearchResults(
                    results: _results,
                    searching: _searching,
                    query: _query.toString(),
                    onTap: (anime) => context.push('/catalogue/${anime.id}'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── TV Keyboard ───────────────────────────────────────────────────────────────

class _TvKeyboard extends StatelessWidget {
  final void Function(String) onKey;

  static const _rows = [
    ['A','B','C','D','E','F','G'],
    ['H','I','J','K','L','M','N'],
    ['O','P','Q','R','S','T','U'],
    ['V','W','X','Y','Z','0','1'],
    ['2','3','4','5','6','7','8'],
    ['9','⌫','   ','✓'],
  ];

  const _TvKeyboard({required this.onKey});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _rows.map((row) => Row(
        children: row.map((key) {
          final isWide = key.trim() == '' || key == '⌫' || key == '✓';
          return Expanded(
            flex: isWide ? 2 : 1,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: _KeyButton(
                label: key.trim().isEmpty ? 'Espace' : key,
                display: key.trim().isEmpty ? '⎵' : key,
                onTap: () => onKey(key.trim().isEmpty ? 'Espace' : key),
              ),
            ),
          );
        }).toList(),
      )).toList(),
    );
  }
}

class _KeyButton extends StatefulWidget {
  final String label;
  final String display;
  final VoidCallback onTap;

  const _KeyButton({
    required this.label,
    required this.display,
    required this.onTap,
  });

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 36,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _focused ? AppTheme.primary : AppTheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _focused ? AppTheme.primary : AppTheme.divider,
            ),
          ),
          child: Center(
            child: Text(
              widget.display,
              style: TextStyle(
                color: _focused ? Colors.white : AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Search Results ────────────────────────────────────────────────────────────

class _SearchResults extends StatelessWidget {
  final List<Anime>    results;
  final bool           searching;
  final String         query;
  final void Function(Anime) onTap;

  const _SearchResults({
    required this.results,
    required this.searching,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2));
    }
    if (query.trim().isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 48),
            SizedBox(height: 12),
            Text('Commencez à taper pour rechercher', style: TextStyle(color: AppTheme.textMuted)),
          ],
        ),
      );
    }
    if (results.isEmpty) {
      return Center(
        child: Text('Aucun résultat pour "$query"', style: const TextStyle(color: AppTheme.textMuted)),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 2 / 3.6,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) => AnimeCard(
        anime: results[index],
        autofocus: index == 0,
        onTap: () => onTap(results[index]),
      ),
    );
  }
}
