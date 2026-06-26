import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_scheduled_rides_body.dart';
import '../widgets/driver_trip_planning_flow_common.dart';
import '../widgets/offer_ride_swap_dialog.dart';
import '../widgets/scheduled_preride_actions.dart';

enum ScheduledTab { requests, confirmed }

class ScheduledRidesScreen extends ConsumerStatefulWidget {
  const ScheduledRidesScreen({super.key});

  @override
  ConsumerState<ScheduledRidesScreen> createState() => _ScheduledRidesScreenState();
}

class _ScheduledRidesScreenState extends ConsumerState<ScheduledRidesScreen> {
  ScheduledTab _tab = ScheduledTab.requests;

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography = DriverTypography.fromTheme(ref.watch(typographyProvider));
    final themeColors = ref.watch(colorsProvider);
    final themeTypo = ref.watch(typographyProvider);
    final tabKey = _tab == ScheduledTab.requests ? 'requests' : 'confirmed';
    final ridesAsync = ref.watch(scheduledRidesByTabProvider(tabKey));

    return ridesAsync.when(
      data: (rides) => DriverScheduledRidesBody(
        colors: colors,
        typography: typography,
        requestsSelected: _tab == ScheduledTab.requests,
        loading: false,
        emptyMessage: _tab == ScheduledTab.requests
            ? 'No ride requests'
            : 'No confirmed rides',
        errorMessage: null,
        rides: rides
            .map(
              (ride) => _buildRideItem(
                context,
                ref,
                ride,
                themeColors,
                themeTypo,
              ),
            )
            .toList(),
        onBack: () => context.pop(),
        onRequestsTap: () => setState(() => _tab = ScheduledTab.requests),
        onConfirmedTap: () => setState(() => _tab = ScheduledTab.confirmed),
        onRideTap: (index) => _openRideDetail(context, rides[index]),
      ),
      loading: () => DriverScheduledRidesBody(
        colors: colors,
        typography: typography,
        requestsSelected: _tab == ScheduledTab.requests,
        loading: true,
        emptyMessage: null,
        errorMessage: null,
        rides: const [],
        onBack: () => context.pop(),
        onRequestsTap: () => setState(() => _tab = ScheduledTab.requests),
        onConfirmedTap: () => setState(() => _tab = ScheduledTab.confirmed),
        onRideTap: (_) {},
      ),
      error: (_, __) => DriverScheduledRidesBody(
        colors: colors,
        typography: typography,
        requestsSelected: _tab == ScheduledTab.requests,
        loading: false,
        emptyMessage: null,
        errorMessage: DriverStrings.couldNotLoadRides,
        rides: const [],
        onBack: () => context.pop(),
        onRequestsTap: () => setState(() => _tab = ScheduledTab.requests),
        onConfirmedTap: () => setState(() => _tab = ScheduledTab.confirmed),
        onRideTap: (_) {},
      ),
    );
  }

  DriverScheduledRideListItem _buildRideItem(
    BuildContext context,
    WidgetRef ref,
    ScheduledRide ride,
    HeyCabyColorTokens colors,
    HeyCabyTypography typo,
  ) {
    final fare = ride.estimatedFare != null
        ? '€${ride.estimatedFare!.toStringAsFixed(2)}'
        : '—';
    final timeStr = ride.scheduledPickupAt != null
        ? DateFormat('HH:mm').format(ride.scheduledPickupAt!)
        : '—';
    final distStr = ride.distanceKm != null
        ? '${ride.distanceKm!.toStringAsFixed(1)} km'
        : null;

    Widget? mapPreview;
    if (ride.pickupLat != null && ride.pickupLng != null) {
      mapPreview = CachedNetworkImage(
        imageUrl: _mapThumbnailUrl(ride),
        height: 80,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: colors.border,
          height: 80,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (_, __, ___) => Container(
          color: colors.border,
          height: 80,
          child: Icon(Icons.map, color: colors.textSoft),
        ),
      );
    }

    Widget? footer;
    if (_tab == ScheduledTab.confirmed &&
        (ride.status == 'accepted' || ride.status == 'driver_arrived')) {
      footer = Consumer(
        builder: (context, ref, _) => ScheduledPrerideActions(
          ride: ride,
          colors: colors,
          typo: typo,
          onInvalidate: () {
            ref.invalidate(scheduledRidesByTabProvider('confirmed'));
            ref.invalidate(scheduledRidesProvider);
          },
        ),
      );
    }
    if (_tab == ScheduledTab.confirmed) {
      if (ride.swapListed == true) {
        final prerideFooter = footer;
        footer = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (prerideFooter != null) ...[prerideFooter, const SizedBox(height: 14)],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                DriverStrings.swapListedBadge,
                style: typo.labelSmall.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openRideDetail(context, ride),
                    child: Text(DriverStrings.rideDetails),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _cancelListedSwap(context, ref, ride),
                    child: Text(
                      DriverStrings.swapCancelOffer,
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      } else if (ride.canOfferSwap) {
        final prerideFooter = footer;
        footer = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (prerideFooter != null) ...[prerideFooter, const SizedBox(height: 14)],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openRideDetail(context, ride),
                    child: Text(DriverStrings.rideDetails),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => showOfferRideSwapDialog(
                      context,
                      ref,
                      ride: ride,
                      onSuccess: () {
                        if (mounted) setState(() {});
                      },
                    ),
                    icon: Icon(Icons.swap_horiz_rounded, size: 18, color: colors.text),
                    label: Text(DriverStrings.swapAction),
                  ),
                ),
              ],
            ),
          ],
        );
      }
    }

    return DriverScheduledRideListItem(
      headline: '$fare · Pick-up today $timeStr',
      distanceLabel: distStr,
      pickupAddress: ride.pickupAddress,
      destinationAddress: ride.destinationAddress,
      mapPreview: mapPreview,
      footer: footer,
    );
  }

  String _mapThumbnailUrl(ScheduledRide ride) {
    final lat = ride.pickupLat ?? 52.3676;
    final lng = ride.pickupLng ?? 4.9041;
    const token = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
    return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/'
        '$lng,$lat,12,0/320x120@2x?access_token=$token';
  }

  void _openRideDetail(BuildContext context, ScheduledRide ride) {
    context.push('/driver/ride/new/${ride.id}');
  }

  Future<void> _cancelListedSwap(
    BuildContext context,
    WidgetRef ref,
    ScheduledRide ride,
  ) async {
    final driverId = await ref.read(driverIdProvider.future);
    if (driverId == null) return;
    final swapId = await ref.read(rideSwapServiceProvider).fetchOpenSwapIdForRide(
          offeringDriverId: driverId,
          rideRequestId: ride.id,
        );
    if (!context.mounted) return;
    if (swapId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.swapErrorNotAvailable)),
      );
      return;
    }
    final typo = ref.read(typographyProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(DriverStrings.swapCancelConfirmTitle, style: typo.titleMedium),
        content: Text(DriverStrings.swapCancelConfirmBody, style: typo.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(DriverStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(DriverStrings.swapCancelConfirmCta),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final res = await ref.read(rideSwapServiceProvider).cancelRideSwap(
          driverId: driverId,
          swapId: swapId,
        );
    if (!context.mounted) return;
    if (res?['success'] == true) {
      ref.invalidate(scheduledRidesByTabProvider('confirmed'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.swapCancelledOk)),
      );
    } else {
      final err = res?['error']?.toString() ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.isNotEmpty ? err : 'Mislukt')),
      );
    }
  }
}

