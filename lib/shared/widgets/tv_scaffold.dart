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

/// Shell Netflix TV : top navbar + contenu.
/// UP depuis contenu → focus navbar / DOWN depuis navbar → focus contenu.
class TvScaffold extends StatefulWidget {
  final NavItem current;
  final Widget child;

  const TvScaffold({
    super.key,
    required this.current,
    required this.child,
  });

  @override
  State<TvScaffold> createState() => _TvScaffoldState();
}

class _TvScaffoldState extends State<TvScaffold> {
  final _navScope     = FocusScopeNode();
  final _contentScope = FocusScopeNode();
  bool _navFocused = false;

  @override
  void dispose() {
    _navScope.dispose();
    _contentScope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Navbar ─────────────────────────────────────────────────
            FocusScope(
              node: _navScope,
              onFocusChange: (f) => setState(() => _navFocused = f),
              child: Focus(
                // DOWN from navbar → focus content
                onKeyEvent: (_, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    _contentScope.requestFocus();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: _NavBar(
                  current: widget.current,
                  onTap: (item) => context.go(item.route),
                ),
              ),
            ),
            // ── Content ────────────────────────────────────────────────────
            Expanded(
              child: FocusScope(
                node: _contentScope,
                child: Focus(
                  // UP from content (not already in nav) → focus navbar
                  onKeyEvent: (_, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.arrowUp &&
                        !_navFocused) {
                      _navScope.requestFocus();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: widget.child,
                ),
              ),
            ),
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
          // Logo
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
          // Nav items
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

// ── NavItem widget ────────────────────────────────────────────────────────────

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
             event.logicalKey == LogicalKeyboardKey.enter)) {
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
              Icon(
                widget.item.icon,
                size: 18,
                color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
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
