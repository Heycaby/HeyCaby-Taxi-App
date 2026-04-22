import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'rider_notifications_listener.dart';

class RiderShell extends ConsumerWidget {
  final Widget child;

  const RiderShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final location = GoRouterState.of(context).uri.toString();

    int currentIndex = 0;
    if (location.startsWith('/rides')) {
      currentIndex = 1;
    } else if (location.startsWith('/tell-friend')) {
      currentIndex = 2;
    } else if (location.startsWith('/account')) {
      currentIndex = 3;
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          child,
          const RiderNotificationsListener(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.card,
          border: Border(
            top: BorderSide(color: colors.border),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.map_outlined,
                  activeIcon: Icons.map,
                  label: l10n.home,
                  isActive: currentIndex == 0,
                  colors: colors,
                  typo: typo,
                  onTap: () => context.go('/home'),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  label: l10n.rides,
                  isActive: currentIndex == 1,
                  colors: colors,
                  typo: typo,
                  onTap: () => context.go('/rides'),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.groups_2_outlined,
                  activeIcon: Icons.groups_2,
                  label: l10n.tellAFriendNavLabel,
                  semanticsLabel: l10n.tellAFriendNavSemanticLabel,
                  isActive: currentIndex == 2,
                  colors: colors,
                  typo: typo,
                  onTap: () => context.go('/tell-friend'),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: l10n.account,
                  isActive: currentIndex == 3,
                  colors: colors,
                  typo: typo,
                  onTap: () => context.go('/account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? semanticsLabel;
  final bool isActive;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.semanticsLabel,
    required this.isActive,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? colors.accent : colors.textSoft;

    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isActive ? activeIcon : icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: typo.labelSmall.copyWith(
                  color: color,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
