import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

enum NavItem { home, catalogue, planning, search }

extension NavItemX on NavItem {
  String get label => switch (this) {
    NavItem.home      => 'Accueil',
    NavItem.catalogue => 'Catalogue',
    NavItem.planning  => 'Planning',
    NavItem.search    => 'Recherche',
  };
  IconData get icon => switch (this) {
    NavItem.home      => Icons.home_rounded,
    NavItem.catalogue => Icons.grid_view_rounded,
    NavItem.planning  => Icons.calendar_month_rounded,
    NavItem.search    => Icons.search_rounded,
  };
  String get route => switch (this) {
    NavItem.home      => '/home',
    NavItem.catalogue => '/catalogue',
    NavItem.planning  => '/planning',
    NavItem.search    => '/search',
  };
}

/// Shell TV : navbar en haut + contenu.
/// La traversée D-pad est entièrement gérée par Flutter (spatial algorithm).
class TvScaffold extends StatelessWidget {
  final NavItem current;
  final Widget child;

  const TvScaffold({
    super.key,
    required this.current,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _NavBar(
              current: current,
              onTap: (item) => context.go(item.route),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

// ── NavBar ────────────────────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  final NavItem current;
  final void Function(NavItem) onTap;

  const _NavBar({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.overscanH, vertical: 0),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 32),
            child: Text(
              'ANIPLEX',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
          ),
          ...NavItem.values.map((item) => _NavItemWidget(
            item: item,
            selected: item == current,
            onTap: () => onTap(item),
          )),
        ],
      ),
    );
  }
}

class _NavItemWidget extends StatefulWidget {
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavItemWidget({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavItemWidget> createState() => _NavItemWidgetState();
}

class _NavItemWidgetState extends State<_NavItemWidget> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _focused;
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter  ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.selected ? AppTheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.item.icon, size: 18,
                color: active ? AppTheme.textPrimary : AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(
                widget.item.label,
                style: TextStyle(
                  color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
                  fontSize: 15,
                  fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
