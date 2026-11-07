import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../focus/tv_focusable.dart';

/// Bouton pilule (hero, contrôles). Repos : matériau translucide, texte blanc ;
/// focus : fond blanc, texte noir, scale 1.08 + ombre.
class PillButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final bool autofocus;
  final double height;
  const PillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.autofocus = false,
    this.height = 76,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      autofocus: autofocus,
      onSelect: onTap,
      builder: (context, focused) {
        final fg = focused ? AppTheme.primaryForeground : AppTheme.foreground;
        return AnimatedScale(
          scale: focused ? 1.08 : 1.0,
          duration: AppTheme.motion,
          curve: AppTheme.ease,
          child: AnimatedContainer(
            duration: AppTheme.motion,
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 42),
            decoration: BoxDecoration(
              color: focused ? AppTheme.primary : AppTheme.materialLight16,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              boxShadow: focused ? AppTheme.btnFocusShadow : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: fg, size: 30),
                  const SizedBox(width: 14),
                ],
                Text(label, style: TextStyle(color: fg, fontSize: 28, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Onglet de la pilule de navigation. Sélectionné (non focus) = matériau clair ;
/// focus = blanc plein + texte noir + scale.
class NavTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const NavTab({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onSelect: onTap,
      builder: (context, focused) {
        final Color bg = focused
            ? AppTheme.primary
            : selected
                ? AppTheme.materialLight16
                : Colors.transparent;
        final Color fg = focused
            ? AppTheme.primaryForeground
            : selected
                ? AppTheme.foreground
                : AppTheme.textSecondary;
        return AnimatedScale(
          scale: focused ? 1.08 : 1.0,
          duration: AppTheme.motion,
          curve: AppTheme.ease,
          child: AnimatedContainer(
            duration: AppTheme.motion,
            padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 16),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
            child: Text(label, style: TextStyle(color: fg, fontSize: 26, fontWeight: FontWeight.w600)),
          ),
        );
      },
    );
  }
}

/// Barre de navigation 10-foot : logo LUMEN · pilule d'onglets centrée ·
/// horloge + avatar. Se masque (opacity + translateY) quand [hidden].
class TopNavBar extends StatelessWidget {
  final List<String> tabs;
  final int current;
  final ValueChanged<int> onTab;
  final bool hidden;
  const TopNavBar({
    super.key,
    required this.tabs,
    required this.current,
    required this.onTab,
    this.hidden = false,
  });

  String get _clock {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: hidden,
      child: AnimatedOpacity(
        opacity: hidden ? 0 : 1,
        duration: AppTheme.motion,
        child: AnimatedSlide(
          offset: hidden ? const Offset(0, -0.2) : Offset.zero,
          duration: AppTheme.motion,
          curve: AppTheme.ease,
          child: SizedBox(
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: AppTheme.safeH),
                    child: Text(
                      'LUMEN',
                      style: TextStyle(
                        color: AppTheme.foreground,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 10.8,
                      ),
                    ),
                  ),
                ),
                // Pilule d'onglets centrée
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.materialDark,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(color: AppTheme.borderFaint),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < tabs.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: NavTab(label: tabs[i], selected: i == current, onTap: () => onTab(i)),
                        ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppTheme.safeH),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_clock, style: const TextStyle(color: AppTheme.foreground, fontSize: 26, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 20),
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(color: AppTheme.materialLight16, shape: BoxShape.circle),
                          child: const Icon(Icons.person_rounded, color: AppTheme.foreground, size: 30),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
