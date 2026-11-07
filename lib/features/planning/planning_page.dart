import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/catalog_api.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/catalog.dart';
import '../../ui/focus/tv_focusable.dart';
import '../../ui/widgets/lumen_cards.dart';
import '../../ui/widgets/lumen_shell.dart';

/// Planning « Lumen » : 7 jours à partir d'aujourd'hui, une colonne par jour,
/// cartes épisode avec statut coloré. Nav 2D au focus directionnel.
class PlanningPage extends StatefulWidget {
  const PlanningPage({super.key});
  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  static const _tabs = ['Accueil', 'Planning', 'Animés', 'Films', 'Séries'];
  static const _dayAbbr = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  final _api = CatalogApi();
  late Future<Map<int, List<PlanningEntry>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.planning();
  }

  void _onTab(int i) {
    switch (i) {
      case 0: context.go('/home');
      case 1: break;
      case 2: context.go('/catalogue?tab=2');
      case 3: context.go('/catalogue?type=MOVIE&tab=3');
      case 4: context.go('/catalogue?type=TV&tab=4');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FutureBuilder<Map<int, List<PlanningEntry>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.foreground));
          }
          final byDay = snap.data ?? const {};
          final today = DateTime.now();
          // 7 colonnes = 7 dates consécutives à partir d'aujourd'hui.
          final days = List.generate(7, (i) {
            final date = today.add(Duration(days: i));
            return (date: date, entries: byDay[date.weekday] ?? const <PlanningEntry>[]);
          });
          final total = days.fold<int>(0, (n, d) => n + d.entries.length);
          final autoDay = days.indexWhere((d) => d.entries.isNotEmpty); // 1er jour non vide

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TopNavBar(tabs: _tabs, current: 1, onTab: _onTab),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppTheme.safeH, 8, AppTheme.safeH, 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text('Planning', style: TextStyle(color: AppTheme.foreground, fontSize: 84, fontWeight: FontWeight.w800, letterSpacing: -2)),
                    const SizedBox(width: 24),
                    Text('$total épisodes', style: const TextStyle(color: AppTheme.textMuted, fontSize: 26)),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.safeH),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var di = 0; di < days.length; di++)
                        Expanded(
                          child: _dayColumn(days[di].date, days[di].entries, di == 0, di == autoDay),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dayColumn(DateTime date, List<PlanningEntry> entries, bool isToday, bool autoFirst) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête de jour
          Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday ? AppTheme.primary : AppTheme.materialLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusMini),
            ),
            child: Text(
              '${_dayAbbr[date.weekday - 1]} ${date.day}',
              style: TextStyle(
                color: isToday ? AppTheme.primaryForeground : AppTheme.foreground,
                fontSize: 22, fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: entries.isEmpty
                ? const SizedBox.shrink()
                : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) {
                      final e = entries[i];
                      return TvFocusable(
                        autofocus: autoFirst && i == 0,
                        centerOnFocus: true,
                        onSelect: () => context.push('/catalogue/${e.animeId}'),
                        builder: (context, focused) => _EpisodeMini(entry: e, focused: focused),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Statut d'un épisode programmé.
({String label, Color color}) _status(PlanningEntry e) {
  final now = DateTime.now();
  final air = DateTime.tryParse(e.airDate);
  if (air != null && air.isAfter(now)) return (label: 'À venir', color: AppTheme.statusUpcoming);
  if (e.available) {
    final isToday = air != null && air.year == now.year && air.month == now.month && air.day == now.day;
    return isToday ? (label: 'Nouveau', color: AppTheme.statusNew) : (label: 'Dispo', color: AppTheme.statusAvailable);
  }
  return (label: 'Bientôt', color: AppTheme.statusUpcoming);
}

String _time(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _EpisodeMini extends StatelessWidget {
  final PlanningEntry entry;
  final bool focused;
  const _EpisodeMini({required this.entry, required this.focused});

  @override
  Widget build(BuildContext context) {
    final st = _status(entry);
    final fg = focused ? AppTheme.primaryForeground : AppTheme.foreground;
    final sub = focused ? const Color(0x99000000) : AppTheme.textMuted;

    return AnimatedScale(
      scale: focused ? 1.03 : 1.0,
      duration: AppTheme.motion,
      curve: AppTheme.ease,
      child: AnimatedContainer(
        duration: AppTheme.motion,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: focused ? AppTheme.primary : AppTheme.materialLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: focused ? AppTheme.focusShadow : null,
          border: focused ? Border.all(color: AppTheme.foreground, width: 3) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMini),
              child: LumenArt(seed: entry.title, imageUrl: entry.image, width: 64, height: 92),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg, fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  if (entry.episodeNumber != null)
                    Text('Ép. ${entry.episodeNumber}', style: TextStyle(color: sub, fontSize: 18)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(_time(entry.airDate), style: TextStyle(color: sub, fontSize: 17, fontFeatures: const [FontFeature.tabularFigures()])),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(st.label, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false,
                            style: TextStyle(color: focused ? st.color.withValues(alpha: 0.85) : st.color, fontSize: 17, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
