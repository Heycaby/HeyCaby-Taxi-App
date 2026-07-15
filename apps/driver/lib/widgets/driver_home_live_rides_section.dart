import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../models/driver_ride_line_board.dart';
import '../providers/driver_ride_line_provider.dart';
import '../providers/driver_state_provider.dart';
import '../theme/app_icons.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_accent_rail_card.dart';
import 'driver_home_premium_style.dart';

String _activeRideRoute(String rideId, DriverAppState state) {
  return switch (state) {
    DriverAppState.arrived => '/driver/ride/pickup/$rideId',
    DriverAppState.inProgress => '/driver/ride/progress/$rideId',
    DriverAppState.completingRide => '/driver/ride/complete/$rideId',
    _ => '/driver/ride/active/$rideId',
  };
}

/// Ride line on home: NOW + NEXT + open summary (no ringing).
class DriverHomeLiveRidesSection extends ConsumerWidget {
  const DriverHomeLiveRidesSection({
    super.key,
    required this.colors,
    required this.typography,
    required this.themeColors,
    required this.themeTypography,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final HeyCabyColorTokens themeColors;
  final HeyCabyTypography themeTypography;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = ref.watch(driverStateProvider);
    final boardAsync = ref.watch(driverRideLineProvider);
    final isOnline = driver.appState == DriverAppState.onlineAvailable;
    final isOnBreak = driver.appState == DriverAppState.onBreak;

    return boardAsync.when(
      data: (board) => _RideLineBody(
        board: board,
        colors: colors,
        typography: typography,
        themeColors: themeColors,
        themeTypography: themeTypography,
        isOnline: isOnline,
        isOnBreak: isOnBreak,
        driver: driver,
      ),
      loading: () => _RideLineBody(
        board: DriverRideLineBoard.empty,
        colors: colors,
        typography: typography,
        themeColors: themeColors,
        themeTypography: themeTypography,
        isOnline: isOnline,
        isOnBreak: isOnBreak,
        driver: driver,
        loading: true,
      ),
      error: (_, __) => _RideLineBody(
        board: DriverRideLineBoard.empty,
        colors: colors,
        typography: typography,
        themeColors: themeColors,
        themeTypography: themeTypography,
        isOnline: isOnline,
        isOnBreak: isOnBreak,
        driver: driver,
      ),
    );
  }
}

class _RideLineBody extends StatelessWidget {
  const _RideLineBody({
    required this.board,
    required this.colors,
    required this.typography,
    required this.themeColors,
    required this.themeTypography,
    required this.isOnline,
    required this.isOnBreak,
    required this.driver,
    this.loading = false,
  });

  final DriverRideLineBoard board;
  final DriverColors colors;
  final DriverTypography typography;
  final HeyCabyColorTokens themeColors;
  final HeyCabyTypography themeTypography;
  final bool isOnline;
  final bool isOnBreak;
  final DriverData driver;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DriverStrings.homeLiveRidesTitle.toUpperCase(),
          style: typography.labelSmall.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: DriverSpacing.sm),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: DriverSpacing.sm),
            child: LinearProgressIndicator(minHeight: 2),
          )
        else if (isOnBreak && !board.hasNow)
          _EmptyLine(
            colors: colors,
            typography: typography,
            themeColors: themeColors,
            icon: Icons.coffee_rounded,
            message: DriverStrings.homeLiveRidesOnBreak,
          )
        else if (!isOnline && !board.hasNow && !board.hasNext)
          _EmptyLine(
            colors: colors,
            typography: typography,
            themeColors: themeColors,
            icon: Icons.radar_rounded,
            message: DriverStrings.homeNoLiveRidesOffline,
          )
        else ...[
          if (board.now != null)
            _SlotCard(
              slot: board.now!,
              slotLabel: DriverStrings.rideLineNowLabel,
              accent: colors.success,
              colors: colors,
              themeColors: themeColors,
              themeTypography: themeTypography,
              onTap: () {
                HapticService.selectionClick();
                context.push(_activeRideRoute(board.now!.rideId, driver.appState));
              },
            ),
          if (board.now != null && board.next != null)
            const SizedBox(height: DriverSpacing.sm),
          if (board.next != null)
            _SlotCard(
              slot: board.next!,
              slotLabel: DriverStrings.rideLineNextLabel,
              accent: colors.primary,
              colors: colors,
              themeColors: themeColors,
              themeTypography: themeTypography,
              onTap: () {
                HapticService.selectionClick();
                context.push('/driver/ride/active/${board.next!.rideId}');
              },
            )
          else if (board.hasNow || isOnline)
            Padding(
              padding: const EdgeInsets.only(top: DriverSpacing.xs),
              child: Text(
                DriverStrings.rideLineNoNextRide,
                style: typography.bodySmall.copyWith(
                  color: themeColors.textMid,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          if (board.open.hasOpen) ...[
            const SizedBox(height: DriverSpacing.sm),
            Text(
              board.open.topFareEuros != null
                  ? DriverStrings.rideLineOpenInvitesSummary(
                      board.open.count,
                      '€${board.open.topFareEuros!.toStringAsFixed(2)}',
                    )
                  : (board.open.count == 1
                      ? DriverStrings.rideLineOpenInvitesOne
                      : DriverStrings.rideLineOpenInvitesSummary(
                          board.open.count,
                          '—',
                        )),
              style: themeTypography.bodySmall.copyWith(
                color: themeColors.textMid,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (isOnline && !board.hasNow && !board.hasNext)
            _EmptyLine(
              colors: colors,
              typography: typography,
              themeColors: themeColors,
              icon: Icons.hourglass_top_rounded,
              message: DriverStrings.homeNoLiveRidesOnline,
            ),
        ],
        const SizedBox(height: DriverSpacing.md),
      ],
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.slotLabel,
    required this.accent,
    required this.colors,
    required this.themeColors,
    required this.themeTypography,
    required this.onTap,
  });

  final DriverRideLineSlot slot;
  final String slotLabel;
  final Color accent;
  final DriverColors colors;
  final HeyCabyColorTokens themeColors;
  final HeyCabyTypography themeTypography;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fare = slot.fareLabel;
    return DriverAccentRailCard(
      colors: colors,
      onTap: onTap,
      padding: const EdgeInsets.all(DriverSpacing.md),
      child: Row(
        children: [
          DriverHomeIconOrb(
            icon: slot.isQueuedAfterCurrent
                ? Icons.queue_play_next_rounded
                : AppIcons.carFront,
            colors: colors,
            size: 44,
            iconSize: 20,
          ),
          const SizedBox(width: DriverSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(DriverRadius.pill),
                      ),
                      child: Text(
                        slotLabel.toUpperCase(),
                        style: themeTypography.labelSmall.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      slot.statusLabel,
                      style: themeTypography.labelSmall.copyWith(
                        color: themeColors.textMid,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  slot.routeLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: themeTypography.bodyMedium.copyWith(
                    color: themeColors.text,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                if (fare != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    fare,
                    style: themeTypography.bodySmall.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            AppIcons.chevronRight,
            color: colors.primary.withValues(alpha: 0.55),
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({
    required this.colors,
    required this.typography,
    required this.themeColors,
    required this.icon,
    required this.message,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final HeyCabyColorTokens themeColors;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DriverSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary.withValues(alpha: 0.82), size: 20),
          const SizedBox(width: DriverSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: typography.bodySmall.copyWith(
                color: themeColors.textMid,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
