import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../theme/app_icons.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';
import 'driver_break_reminder_banner.dart';
import 'driver_verification_status_banner.dart';
import 'driver_earnings_modal.dart';
import 'driver_shift_timer_widget.dart';
import '../services/sound_service.dart';
import '../services/driver_platform_fee_gate.dart';
import 'driver_online_panel.dart';
import 'driver_online_status_widget.dart';

const _hubButtonSize = 48.0; // +~10% for better visibility on the map

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
    final topPadding = MediaQuery.of(context).padding.top;

    final isOnline = driver.appState == DriverAppState.onlineAvailable ||
        driver.appState == DriverAppState.onBreak;
    final summary = earningsAsync.valueOrNull;
    final todayEuros =
        summary != null ? summary.formatEuros(summary.todayEuros) : '€0.00';
    final zoneName = isOnline
        ? (zoneAsync.valueOrNull ?? '—')
        : DriverStrings.offline;
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
    final screenHeight = MediaQuery.of(context).size.height;
    final mapVisibleHeight = screenHeight - sheetHeight;
    final hubButtonTop = topPadding + mapVisibleHeight * 0.42 - (_hubButtonSize / 2);
    final badgeCount = ref.watch(driverHubBadgeCountProvider).valueOrNull ?? 0;

    return Stack(
      children: [
        Positioned(
          top: topPadding + 8,
          left: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DriverBreakReminderBanner(),
              const SizedBox(height: 8),
              const DriverVerificationStatusBanner(),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 54),
                child: DriverEarningsPill(
                  todayEarnings: todayEuros,
                  zoneName: zoneName,
                  statusKind: statusKind,
                  colors: colors,
                  typo: typo,
                  statusTime: statusTime,
                  onTap: () => _showEarningsModal(context, ref),
                ),
              ),
              if (isOnline) ...[
                const SizedBox(height: 8),
                DriverOnlineStatusWidget(
                  zoneName: zoneAsync.valueOrNull ?? '—',
                  isOnBreak: driver.appState == DriverAppState.onBreak,
                  colors: colors,
                  typo: typo,
                  onTap: () => _showOnlinePanel(context, ref),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          top: topPadding + 12,
          right: 16,
          child: _MapFloatingButton(
            icon: AppIcons.mapRecenter,
            colors: colors,
            onTap: onRecenter,
          ),
        ),
        if (onDriverHub != null)
          Positioned(
            top: hubButtonTop,
            right: 16,
            child: _DriverHubButton(
              badgeCount: badgeCount,
              colors: colors,
              typo: typo,
              onTap: onDriverHub!,
            ),
          ),
        if (isOnline)
          Positioned(
            left: 16,
            right: 16,
            bottom: sheetHeight + 12,
            child: const DriverShiftTimerWidget(),
          ),
      ],
    );
  }

  void _showEarningsModal(BuildContext context, WidgetRef ref) {
    final earnings = ref.read(driverEarningsProvider).valueOrNull;
    final todayStr = earnings?.formatEuros(earnings.todayEuros) ?? '€0.00';
    final zoneAsync = ref.read(currentZoneNameProvider);
    final zoneName = zoneAsync.valueOrNull ?? '—';
    final driver = ref.read(driverStateProvider);
    final statusKind = driver.appState == DriverAppState.onlineAvailable
        ? DriverStatusKind.online
        : driver.appState == DriverAppState.onBreak
            ? DriverStatusKind.onBreak
            : DriverStatusKind.offline;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => DriverEarningsModal(
        todayEarnings: todayStr,
        zoneName: zoneName,
        statusKind: statusKind,
        colors: ref.read(colorsProvider),
        typo: ref.read(typographyProvider),
        onDismiss: () => Navigator.of(dialogContext).pop(),
        onTakeBreak: () async {
          try {
            await ref.read(driverApiProvider).setStatus(status: 'on_break');
            ref.read(driverStateProvider.notifier).setStatus(DriverAppState.onBreak);
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
              colors: ref.read(colorsProvider),
              typo: ref.read(typographyProvider),
            ),
          );
          if (confirmed == true) {
            try {
              await ref.read(driverApiProvider).setStatus(status: 'offline');
              ref.read(driverStateProvider.notifier).setStatus(DriverAppState.offline);
              SoundService().playNotification();
              if (context.mounted) Navigator.of(dialogContext).pop();
            } catch (_) {}
          }
        },
        onResume: () async {
          final ok = await ensureDriverPlatformFeeAllowsOnline(context, ref);
          if (!ok) return;
          try {
            await ref.read(driverApiProvider).setStatus(status: 'available');
            ref.read(driverStateProvider.notifier).setStatus(DriverAppState.onlineAvailable);
            SoundService().playNotification();
            if (context.mounted) Navigator.of(dialogContext).pop();
          } catch (_) {}
        },
      ),
    );
  }

  void _showOnlinePanel(BuildContext context, WidgetRef ref) {
    ref.invalidate(driverShiftStatsProvider);
    final themeColors = ref.read(colorsProvider);
    final stats = ref.read(driverShiftStatsProvider).valueOrNull;
    final onlineMins = stats?.shiftTotalOnlineMinutes ?? 0;
    final rides = stats?.shiftRidesToday ?? 0;
    final earned =
        stats != null ? '€${stats.shiftEarningsToday.toStringAsFixed(2)}' : '€0.00';
    String? breakNotice;
    Color? breakNoticeColor;
    if (stats != null && stats.continuousDrivingMinutes >= 180) {
      final mins = stats.continuousDrivingMinutes;
      breakNotice = DriverStrings.dutchBreakNotice.replaceFirst(
        'X',
        '${mins ~/ 60}',
      );
      breakNoticeColor = stats.hasExceededBreakLimit
          ? ref.read(colorsProvider).error
          : stats.isApproachingBreakLimit
              ? ref.read(colorsProvider).warning
              : null;
    }
    final controller = ScrollController();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: themeColors.text.withValues(alpha: 0.54),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: DriverOnlinePanel(
              fromTop: true,
              isOnBreak: ref.read(driverStateProvider).appState == DriverAppState.onBreak,
              colors: ref.read(colorsProvider),
              typo: ref.read(typographyProvider),
              scrollController: controller,
              onlineMinutes: onlineMins,
              ridesToday: rides,
              earnedToday: earned,
              breakNotice: breakNotice,
              breakNoticeColor: breakNoticeColor,
              onTakeBreak: () async {
                try {
                  await ref.read(driverApiProvider).setStatus(status: 'on_break');
                  ref.read(driverStateProvider.notifier).setStatus(DriverAppState.onBreak);
                  if (context.mounted) Navigator.of(context).pop();
                } catch (_) {}
              },
              onEndShift: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => _EndShiftConfirmDialog(
                    hours: '${onlineMins ~/ 60}',
                    rides: '$rides',
                    colors: ref.read(colorsProvider),
                    typo: ref.read(typographyProvider),
                  ),
                );
                if (confirmed == true) {
                  try {
                    await ref.read(driverApiProvider).setStatus(status: 'offline');
                    ref.read(driverStateProvider.notifier).setStatus(DriverAppState.offline);
                    SoundService().playNotification();
                    if (context.mounted) Navigator.of(context).pop();
                  } catch (_) {}
                }
              },
              onResume: () async {
                final ok = await ensureDriverPlatformFeeAllowsOnline(context, ref);
                if (!ok) return;
                try {
                  await ref.read(driverApiProvider).setStatus(status: 'available');
                  ref.read(driverStateProvider.notifier).setStatus(DriverAppState.onlineAvailable);
                  SoundService().playNotification();
                  if (context.mounted) Navigator.of(context).pop();
                } catch (_) {}
              },
            ),
          ),
        ),
      ),
      transitionBuilder: (_, animation, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
    );
  }
}

class _MapFloatingButton extends StatelessWidget {
  final IconData icon;
  final HeyCabyColorTokens colors;
  final VoidCallback onTap;

  const _MapFloatingButton({
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.card,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: colors.text.withValues(alpha: 0.26),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: colors.text, size: 22),
        ),
      ),
    );
  }
}

class _DriverHubButton extends StatelessWidget {
  final int badgeCount;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _DriverHubButton({
    required this.badgeCount,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // High-contrast, premium "hub" button: accent fill + white ring + soft glow.
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colors.accent.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: colors.accent,
            shape: const CircleBorder(),
            elevation: 6,
            shadowColor: colors.text.withValues(alpha: 0.10),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: _hubButtonSize,
                height: _hubButtonSize,
                child: Icon(
                  AppIcons.hubGrid,
                  // Lucide stroke on map: force luminance-based fg so we never get dark-on-dark
                  // when [onAccent] tracks [text] on light-gold accents over a busy basemap.
                  color: colors.accent.computeLuminance() < 0.45
                      ? colors.card
                      : colors.text,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.card.withValues(alpha: 0.85),
                  width: 2,
                ),
              ),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: BoxDecoration(
                color: colors.error,
                shape: BoxShape.circle,
                border: Border.all(color: colors.card, width: 1.5),
              ),
              child: Center(
                child: Text(
                  badgeCount >= 10 ? '9+' : '$badgeCount',
                  style: typo.labelSmall.copyWith(
                    color: colors.card,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
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
          child: const Text(DriverStrings.cancel),
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
