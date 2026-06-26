import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:intl/intl.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';
import '../services/driver_data_service.dart';
import '../theme/app_icons.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_accent_rail_card.dart';
import 'driver_home_premium_style.dart';

String _activeRideRoute(DriverData driver) {
  final id = driver.activeRideId!;
  return switch (driver.appState) {
    DriverAppState.arrived => '/driver/ride/pickup/$id',
    DriverAppState.inProgress => '/driver/ride/progress/$id',
    DriverAppState.completingRide => '/driver/ride/complete/$id',
    _ => '/driver/ride/active/$id',
  };
}

String _activeRideStatusLabel(DriverAppState state) {
  return switch (state) {
    DriverAppState.arrived => DriverStrings.waiting,
    DriverAppState.inProgress => DriverStrings.navigate,
    DriverAppState.completingRide => DriverStrings.rideDetails,
    _ => DriverStrings.navigateToPickup,
  };
}

/// Replaces the duplicate earnings hero — active + incoming ride feed.
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
    final isOnline = driver.appState == DriverAppState.onlineAvailable;
    final isOnBreak = driver.appState == DriverAppState.onBreak;
    final incomingAsync = ref.watch(availableRidesNowProvider);
    final incoming = incomingAsync.valueOrNull ?? const <ScheduledRide>[];
    final hasActiveRide = driver.activeRideId != null;
    final previewIncoming = incoming.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              DriverStrings.homeLiveRidesTitle.toUpperCase(),
              style: typography.labelSmall.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const Spacer(),
            if (isOnline || isOnBreak)
              TextButton(
                onPressed: () {
                  HapticService.selectionClick();
                  context.push('/driver/work');
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  DriverStrings.homeViewAllRides,
                  style: themeTypography.labelSmall.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: DriverSpacing.sm),
        if (hasActiveRide)
          _ActiveRideCard(
            driver: driver,
            colors: colors,
            typography: typography,
            themeColors: themeColors,
            themeTypography: themeTypography,
            onTap: () {
              HapticService.selectionClick();
              context.push(_activeRideRoute(driver));
            },
          ),
        if (hasActiveRide && (previewIncoming.isNotEmpty || isOnline))
          const SizedBox(height: DriverSpacing.sm),
        if (isOnBreak && !hasActiveRide)
          _EmptyLiveCard(
            colors: colors,
            typography: typography,
            themeColors: themeColors,
            icon: Icons.coffee_rounded,
            message: DriverStrings.homeLiveRidesOnBreak,
          )
        else if (isOnline && previewIncoming.isNotEmpty) ...[
          if (hasActiveRide)
            Padding(
              padding: const EdgeInsets.only(bottom: DriverSpacing.xs),
              child: Text(
                DriverStrings.homeIncomingRides,
                style: themeTypography.labelLarge.copyWith(
                  color: themeColors.textMid,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ...previewIncoming.map(
            (ride) => Padding(
              padding: const EdgeInsets.only(bottom: DriverSpacing.sm),
              child: _IncomingRideTile(
                ride: ride,
                colors: colors,
                themeColors: themeColors,
                themeTypography: themeTypography,
                onTap: () {
                  HapticService.selectionClick();
                  context.push('/driver/ride/new/${ride.id}');
                },
              ),
            ),
          ),
        ] else if (!hasActiveRide && !isOnline)
          _EmptyLiveCard(
            colors: colors,
            typography: typography,
            themeColors: themeColors,
            icon: Icons.radar_rounded,
            message: DriverStrings.homeNoLiveRidesOffline,
          )
        else if (isOnline && previewIncoming.isEmpty && !hasActiveRide)
          _EmptyLiveCard(
            colors: colors,
            typography: typography,
            themeColors: themeColors,
            icon: Icons.hourglass_top_rounded,
            message: DriverStrings.homeNoLiveRidesOnline,
            loading: incomingAsync.isLoading,
          ),
        const SizedBox(height: DriverSpacing.md),
      ],
    );
  }
}

class _ActiveRideCard extends StatelessWidget {
  const _ActiveRideCard({
    required this.driver,
    required this.colors,
    required this.typography,
    required this.themeColors,
    required this.themeTypography,
    required this.onTap,
  });

  final DriverData driver;
  final DriverColors colors;
  final DriverTypography typography;
  final HeyCabyColorTokens themeColors;
  final HeyCabyTypography themeTypography;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pickup = driver.pickupAddress?.trim();
    final destination = driver.destinationAddress?.trim();
    final route = [
      if (pickup != null && pickup.isNotEmpty) pickup,
      if (destination != null && destination.isNotEmpty) destination,
    ].join(' → ');

    return DriverAccentRailCard(
      colors: colors,
      onTap: onTap,
      padding: const EdgeInsets.all(DriverSpacing.md),
      child: Row(
        children: [
          DriverHomeIconOrb(
            icon: AppIcons.carFront,
            colors: colors,
            size: 48,
            iconSize: 22,
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
                        color: colors.success.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(DriverRadius.pill),
                      ),
                      child: Text(
                        DriverStrings.homeActiveRideTitle,
                        style: themeTypography.labelSmall.copyWith(
                          color: colors.success,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _activeRideStatusLabel(driver.appState),
                      style: themeTypography.labelSmall.copyWith(
                        color: themeColors.textMid,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  route.isNotEmpty ? route : DriverStrings.rideDetails,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: themeTypography.bodyMedium.copyWith(
                    color: themeColors.text,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                if (driver.riderContactName?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    driver.riderContactName!.trim(),
                    style: themeTypography.bodySmall.copyWith(
                      color: themeColors.textMid,
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

class _IncomingRideTile extends StatelessWidget {
  const _IncomingRideTile({
    required this.ride,
    required this.colors,
    required this.themeColors,
    required this.themeTypography,
    required this.onTap,
  });

  final ScheduledRide ride;
  final DriverColors colors;
  final HeyCabyColorTokens themeColors;
  final HeyCabyTypography themeTypography;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fare = ride.estimatedFare != null
        ? '€${ride.estimatedFare!.toStringAsFixed(2)}'
        : '—';
    final time = ride.scheduledPickupAt != null
        ? DateFormat('HH:mm').format(ride.scheduledPickupAt!)
        : DriverStrings.now;
    final dist = ride.distanceKm != null
        ? '${ride.distanceKm!.toStringAsFixed(1)} km'
        : null;

    return DriverAccentRailCard(
      colors: colors,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: DriverSpacing.md,
        vertical: DriverSpacing.sm + 2,
      ),
      child: Row(
        children: [
          DriverHomeIconOrb(
            icon: Icons.bolt_rounded,
            colors: colors,
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(width: DriverSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$fare · $time${dist != null ? ' · $dist' : ''}',
                  style: themeTypography.bodyMedium.copyWith(
                    color: themeColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (ride.pickupAddress?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    ride.pickupAddress!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: themeTypography.bodySmall.copyWith(
                      color: themeColors.textMid,
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

class _EmptyLiveCard extends StatelessWidget {
  const _EmptyLiveCard({
    required this.colors,
    required this.typography,
    required this.themeColors,
    required this.icon,
    required this.message,
    this.loading = false,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final HeyCabyColorTokens themeColors;
  final IconData icon;
  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return DriverAccentRailCard(
      colors: colors,
      padding: const EdgeInsets.all(DriverSpacing.lg),
      child: Row(
        children: [
          DriverHomeIconOrb(
            icon: icon,
            colors: colors,
            size: 44,
            iconSize: 22,
          ),
          const SizedBox(width: DriverSpacing.md),
          Expanded(
            child: loading
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    ),
                  )
                : Text(
                    message,
                    style: typography.bodyMedium.copyWith(
                      color: themeColors.textMid,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
