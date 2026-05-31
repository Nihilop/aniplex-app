import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/anime.dart';
import '../../shared/widgets/tv_focus_card.dart';
import '../../shared/widgets/tv_scaffold.dart';

class PlanningPage extends StatefulWidget {
  const PlanningPage({super.key});

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  final _api = ApiClient.instance;

  /// Map de weekday (1=Mon .. 7=Sun) → liste d'animes
  Map<int, List<_PlanningEntry>> _schedule = {};
  bool   _loading = true;
  String? _error;

  // Current focused day index (0–6)
  int _dayIndex = DateTime.now().weekday - 1;

  static const _days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
  static const _daysFull = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // GET /api/aniplex/planning → { "1": [...], "2": [...], ... "7": [...] }
      final res = await _api.get<Map<String, dynamic>>('/api/aniplex/planning');
      final data = res.data!;
      final Map<int, List<_PlanningEntry>> schedule = {};
      for (int d = 1; d <= 7; d++) {
        final key = d.toString();
        schedule[d] = (data[key] as List? ?? [])
            .map((e) => _PlanningEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      setState(() { _schedule = schedule; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Impossible de charger le planning.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TvScaffold(
      current: NavItem.planning,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Day tabs
                    _DayTabs(
                      days: _days,
                      selected: _dayIndex,
                      onSelect: (i) => setState(() => _dayIndex = i),
                    ),
                    const SizedBox(height: 16),
                    // Content for selected day
                    Expanded(
                      child: _DayContent(
                        title: _daysFull[_dayIndex],
                        entries: _schedule[_dayIndex + 1] ?? [],
                        onTap: (entry) => context.push('/catalogue/${entry.animeId}'),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _DayTabs extends StatelessWidget {
  final List<String> days;
  final int selected;
  final ValueChanged<int> onSelect;

  const _DayTabs({required this.days, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.overscanH, 8, AppTheme.overscanH, 0),
      child: Row(
        children: List.generate(days.length, (i) {
          final isSelected = i == selected;
          return TvFocusCard(
            onTap: () => onSelect(i),
            borderRadius: 8,
            backgroundColor: isSelected ? AppTheme.primary : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              days[i],
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _DayContent extends StatelessWidget {
  final String title;
  final List<_PlanningEntry> entries;
  final void Function(_PlanningEntry) onTap;

  const _DayContent({required this.title, required this.entries, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Text('Aucune sortie ce jour.', style: TextStyle(color: AppTheme.textMuted)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(AppTheme.overscanH, 0, AppTheme.overscanH, AppTheme.overscanV),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 2 / 3.6,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final e = entries[index];
        return TvFocusCard(
          onTap: () => onTap(e),
          autofocus: index == 0,
          borderRadius: 10,
          backgroundColor: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: e.image != null
                      ? Image.network(
                          e.image!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          loadingBuilder: (_, child, p) => p == null ? child : Container(color: AppTheme.surface),
                          errorBuilder: (_, __, ___) => Container(color: AppTheme.surface,
                              child: const Icon(Icons.movie, color: AppTheme.textMuted)),
                        )
                      : Container(color: AppTheme.surface,
                          child: const Icon(Icons.movie, color: AppTheme.textMuted)),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                e.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              if (e.episodeNumber != null)
                Text(
                  'Ép. ${e.episodeNumber}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PlanningEntry {
  final String  animeId;
  final String  title;
  final String? image;
  final int?    episodeNumber;

  const _PlanningEntry({
    required this.animeId,
    required this.title,
    this.image,
    this.episodeNumber,
  });

  factory _PlanningEntry.fromJson(Map<String, dynamic> j) => _PlanningEntry(
    animeId:       j['animeId'] as String,
    title:         j['title']   as String,
    image:         j['image']   as String?,
    episodeNumber: j['episodeNumber'] as int?,
  );
}
