import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../theme/app_icons.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../theme/driver_motion_presets.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_resilience_inset_provider.dart';
import '../providers/driver_state_provider.dart';
import '../services/driver_data_service.dart' show ZoneDemand;
import '../ui/driver_map_controls_column.dart';
import '../ui/driver_map_demand_chip.dart';
import 'driver_community_overlay_bodies.dart';
import 'driver_verification_status_banner.dart';
import 'driver_earnings_modal.dart';
import 'driver_earnings_modal_parts.dart';
import 'driver_shift_timer_widget.dart';
import '../services/sound_service.dart';
import '../utils/driver_go_online_runtime_action.dart';
import 'driver_go_online_guidance_sheet.dart';

ZoneDemand? _currentZoneDemand(List<ZoneDemand> zones, String? zoneId) {
  if (zoneId == null || zones.isEmpty) return null;
  for (final z in zones) {
    if (z.zoneId == zoneId) return z;
  }
  return null;
}

bool _isHighMapDemand(ZoneDemand zone) {
  final level = (zone.demandLevel ?? '').toLowerCase();
  if (level == 'high' || level == 'very_high') return true;
  return zone.waitingPassengers >= 12;
}

/// Floating elements on top of the driver home map.
class DriverMapFloating extends ConsumerWidget {
  const DriverMapFloating({
    super.key,
    required this.sheetHeight,
    required this.onRecenter,
    required this.onGoOnline,
    this.onDriverHub,
  });

  final double sheetHeight;
  final VoidCallback onRecenter;
  final VoidCallback onGoOnline;
  final VoidCallback? onDriverHub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final driver = ref.watch(driverStateProvider);
    final earningsAsync = ref.watch(driverEarningsProvider);
    final zoneAsync = ref.watch(currentZoneNameProvider);
    final resilienceInset = ref.watch(driverResilienceBannerInsetProvider);
    final topPadding = MediaQuery.of(context).padding.top + resilienceInset;

    final isOnline = driver.appState == DriverAppState.onlineAvailable ||
        driver.appState == DriverAppState.onBreak;
    final summary = earningsAsync.valueOrNull;
    final todayEuros =
        summary != null ? summary.formatEuros(summary.todayEuros) : '€0.00';
    final zoneName =
        isOnline ? (zoneAsync.valueOrNull ?? '—') : DriverStrings.offline;
    final statusKind = driver.appState == DriverAppState.onlineAvailable
        ? DriverStatusKind.online
        : driver.appState == DriverAppState.onBreak
            ? DriverStatusKind.onBreak
            : DriverStatusKind.offline;
    final stats = ref.watch(driverShiftStatsProvider).valueOrNull;
    final statusTime = isOnline && stats != null
        ? (statusKind == DriverStatusKind.online
            ? stats.shiftStartAt
            : stats.lastBreakStartAt)
        : null;
    final badgeCount =
        ref.watch(communityUnreadNotificationsCountProvider).valueOrNull ?? 0;
    final driverColors = DriverColors.fromTheme(colors);
    final driverTypography = DriverTypography.fromTheme(typo);
    final zones =
        ref.watch(zoneDemandProvider).valueOrNull ?? const <ZoneDemand>[];
    final currentZoneId = ref.watch(currentZoneIdProvider).valueOrNull;
    final currentZone = _currentZoneDemand(zones, currentZoneId);
    final waitingCount = currentZone?.waitingPassengers ?? 0;
    final showDemandChip = isOnline && waitingCount >= 4;
    final demandZoneName = currentZone?.zoneName ?? zoneAsync.valueOrNull ?? '';

    return Stack(
      children: [
        Positioned(
          top: topPadding + DriverSpacing.sm,
          left: DriverSpacing.screenEdge,
          right: DriverSpacing.screenEdge,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DriverVerificationStatusBanner(),
              const SizedBox(height: DriverSpacing.sm),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: DriverEarningsPill(
                    todayEarnings: todayEuros,
                    zoneName: zoneName,
                    statusKind: statusKind,
                    colors: colors,
                    typo: typo,
                    statusTime: statusTime,
                    onTap: () => _showEarningsModal(context, ref),
                  ).driverMapChromeEnter(staggerIndex: 0),
                ),
              ),
              if (isOnline && showDemandChip) ...[
                const SizedBox(height: DriverSpacing.sm),
                Center(
                  child: DriverMapDemandChip(
                    zoneName: demandZoneName,
                    waitingCount: waitingCount,
                    highDemand:
                        currentZone != null && _isHighMapDemand(currentZone),
                    colors: driverColors,
                    typography: driverTypography,
                  ).driverMapChromeEnter(staggerIndex: 2),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          top: topPadding + DriverSpacing.md,
          right: DriverSpacing.screenEdge,
          child: DriverMapControlsColumn(
            colors: driverColors,
            recenterIcon: AppIcons.mapRecenter,
            recenterTooltip: DriverStrings.recenterMap,
            onRecenter: onRecenter,
            hubIcon: AppIcons.bellRing,
            hubTooltip: DriverStrings.communityNotificationsTitle,
            hubBadge: badgeCount,
            onHub: () => _showNotifications(context, ref),
          ).driverMapChromeEnter(staggerIndex: 3),
        ),
        if (isOnline)
          Positioned(
            left: DriverSpacing.screenEdge,
            right: DriverSpacing.screenEdge,
            bottom: sheetHeight + DriverSpacing.md,
            child: const DriverShiftTimerWidget()
                .driverFadeSlideIn(staggerIndex: 0, slideY: 0.12),
          ),
      ],
    );
  }

  void _showEarningsModal(BuildContext context, WidgetRef ref) {
    final earnings = ref.read(driverEarningsProvider).valueOrNull;
    final todayStr = earnings?.formatEuros(earnings.todayEuros) ?? '€0.00';
    final zoneAsync = ref.read(currentZoneNameProvider);
    final zoneName = zoneAsync.valueOrNull ?? '—';
    final themeColors = ref.read(colorsProvider);
    final typography = ref.read(typographyProvider);
    final api = ref.read(driverApiProvider);
    final stateNotifier = ref.read(driverStateProvider.notifier);
    final driver = ref.read(driverStateProvider);
    final statusKind = driver.appState == DriverAppState.onlineAvailable
        ? DriverStatusKind.online
        : driver.appState == DriverAppState.onBreak
            ? DriverStatusKind.onBreak
            : DriverStatusKind.offline;
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      builder: (dialogContext) => DriverEarningsModal(
        todayEarnings: todayStr,
        zoneName: zoneName,
        statusKind: statusKind,
        colors: themeColors,
        typo: typography,
        onDismiss: () => Navigator.of(dialogContext).pop(),
        onTakeBreak: () async {
          try {
            await api.setStatus(status: 'on_break');
            stateNotifier.setStatus(DriverAppState.onBreak);
            SoundService().playStatusOnBreak();
            if (context.mounted) Navigator.of(dialogContext).pop();
          } catch (_) {}
        },
        onEndShift: () async {
          final stats = ref.read(driverShiftStatsProvider).valueOrNull;
          final onlineMins = stats?.shiftTotalOnlineMinutes ?? 0;
          final rides = stats?.shiftRidesToday ?? 0;
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (_) => _EndShiftConfirmDialog(
              hours: '${onlineMins ~/ 60}',
              rides: '$rides',
              colors: themeColors,
              typo: typography,
            ),
          );
          if (confirmed == true) {
            try {
              await api.setStatus(status: 'offline');
              stateNotifier.setStatus(DriverAppState.offline);
              SoundService().playStatusOffline();
              if (context.mounted) Navigator.of(dialogContext).pop();
            } catch (_) {}
          }
        },
        onResume: () async {
          final attempt =
              await attemptDriverGoOnlineWithLocationGuard(context, ref);
          if (!context.mounted) return;
          if (attempt.isBlocked) {
            HapticService.mediumTap();
            SoundService().playActionBlocked();
            await showDriverGoOnlineGuidanceSheet(context, ref,
                args: attempt.gateArgs!);
            return;
          }
          if (!attempt.succeeded) return;
          stateNotifier.setStatus(DriverAppState.onlineAvailable);
          SoundService().playStatusOnline();
          if (context.mounted) Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  void _showNotifications(BuildContext context, WidgetRef ref) {
    showDriverCommunityNotificationsSheet(
      context,
      ref,
      onNotificationTap: (notification) {
        final colors = DriverColors.fromTheme(ref.read(colorsProvider));
        final typography =
            DriverTypography.fromTheme(ref.read(typographyProvider));
        showDriverCommunityNotificationDetailDialog(
          context,
          notification: notification,
          colors: colors,
          typography: typography,
        );
      },
    );
  }
}

class _EndShiftConfirmDialog extends StatelessWidget {
  final String hours;
  final String rides;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _EndShiftConfirmDialog({
    required this.hours,
    required this.rides,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(DriverStrings.endShiftConfirm),
      content: Text(
        'You have driven $hours hours and completed $rides rides today.',
        style: typo.bodyMedium.copyWith(color: colors.text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(DriverStrings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.card,
          ),
          child: const Text(DriverStrings.endShift),
        ),
      ],
    );
  }
}
