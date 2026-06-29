import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../theme/app_icons.dart';
import 'driver_profile_realtime_listener.dart';
import 'ride_invite_realtime_listener.dart';
import 'driver_notifications_listener.dart';
import 'driver_location_tracking_listener.dart';
import 'driver_fcm_listener.dart';
import 'driver_active_ride_realtime_listener.dart';
import 'driver_resilience_banner.dart';
import 'driver_resilience_listener.dart';
import 'driver_ride_proximity_listener.dart';
import 'driver_automatic_ping_listener.dart';
import '../utils/driver_immersive_shell.dart';

class DriverShell extends ConsumerStatefulWidget {
  const DriverShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends ConsumerState<DriverShell>
    with WidgetsBindingObserver {
  bool _scheduledDriverBootstrap = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // After Veriff in the external browser, refresh compliance when user returns.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(driverComplianceProvider);
      ref.invalidate(driverProfileProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_scheduledDriverBootstrap) {
      _scheduledDriverBootstrap = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await ref.read(driverDataServiceProvider).bootstrapDriverRow();
        if (!mounted) return;
        ref.invalidate(driverIdProvider);
        ref.invalidate(driverProfileProvider);
      });
    }

    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final location = GoRouterState.of(context).uri.toString();
    // Home | Community | My rides | Me
    int currentIndex = 0;
    if (location.startsWith('/driver/community')) {
      currentIndex = 1;
    } else if (location.startsWith('/driver/my-rides')) {
      currentIndex = 2;
    } else if (location.startsWith('/driver/me')) {
      currentIndex = 3;
    }

    final immersive = isDriverImmersiveRoute(location);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          const DriverProfileRealtimeListener(),
          const RideInviteRealtimeListener(),
          const DriverFcmListener(),
          const DriverActiveRideRealtimeListener(),
          const DriverNotificationsListener(),
          const DriverLocationTrackingListener(),
          const DriverRideProximityListener(),
          const DriverAutomaticPingListener(),
          const DriverResilienceListener(),
          const DriverResilienceBanner(),
        ],
      ),
      bottomNavigationBar: immersive
          ? null
          : Container(
              decoration: BoxDecoration(
                color: colors.bg,
                border: Border(
                  top: BorderSide(color: colors.border, width: 0.5),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: _NavItem(
                        icon: AppIcons.navHome,
                        label: DriverStrings.home,
                        isActive: currentIndex == 0,
                        colors: colors,
                        typo: typo,
                        onTap: () => context.go('/driver'),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: AppIcons.navCommunity,
                        label: DriverStrings.community,
                        isActive: currentIndex == 1,
                        colors: colors,
                        typo: typo,
                        onTap: () => context.go('/driver/community'),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: AppIcons.navMyRides,
                        label: DriverStrings.myRides,
                        isActive: currentIndex == 2,
                        colors: colors,
                        typo: typo,
                        onTap: () => context.go('/driver/my-rides'),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: AppIcons.navProfile,
                        label: DriverStrings.me,
                        isActive: currentIndex == 3,
                        colors: colors,
                        typo: typo,
                        onTap: () => context.go('/driver/me'),
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
  final String label;
  final bool isActive;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isActive ? colors.accent : colors.textSoft;
    final labelColor = isActive ? colors.text : colors.textMid;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            if (isActive) {
              HapticService.selectionClick();
            }
            onTap();
          },
          splashColor: colors.accent.withValues(alpha: 0.14),
          highlightColor: colors.accent.withValues(alpha: 0.06),
          child: Semantics(
            selected: isActive,
            label: label,
            button: true,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? colors.accent.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isActive
                      ? colors.accent.withValues(alpha: 0.42)
                      : Colors.transparent,
                  width: 1,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: colors.accent.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: iconColor, size: 24),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: typo.labelSmall.copyWith(
                      color: labelColor,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0,
                    ),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
