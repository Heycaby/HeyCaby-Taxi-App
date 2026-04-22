import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';
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
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final tabKey = _tab == ScheduledTab.requests ? 'requests' : 'confirmed';
    final ridesAsync = ref.watch(scheduledRidesByTabProvider(tabKey));

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.text),
          onPressed: () => context.pop(),
        ),
        title: Text(
          DriverStrings.scheduledRides,
          style: typo.headingLarge.copyWith(color: colors.text),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: _TabPill(
                    label: DriverStrings.requests,
                    isSelected: _tab == ScheduledTab.requests,
                    colors: colors,
                    typo: typo,
                    onTap: () => setState(() => _tab = ScheduledTab.requests),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TabPill(
                    label: DriverStrings.confirmed,
                    isSelected: _tab == ScheduledTab.confirmed,
                    colors: colors,
                    typo: typo,
                    onTap: () => setState(() => _tab = ScheduledTab.confirmed),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ridesAsync.when(
              data: (rides) {
                if (rides.isEmpty) {
                  return Center(
                    child: Text(
                      _tab == ScheduledTab.requests
                          ? 'No ride requests'
                          : 'No confirmed rides',
                      style: typo.bodyMedium.copyWith(color: colors.textSoft),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: rides.length,
                  itemBuilder: (_, i) => _ScheduledRideCard(
                    ride: rides[i],
                    colors: colors,
                    typo: typo,
                    showActions: _tab == ScheduledTab.requests,
                    showSwapRow: _tab == ScheduledTab.confirmed,
                    onTap: () => _openRideDetail(context, rides[i]),
                    onOfferSwap: _tab == ScheduledTab.confirmed
                        ? () => showOfferRideSwapDialog(
                              context,
                              ref,
                              ride: rides[i],
                              onSuccess: () {
                                if (mounted) setState(() {});
                              },
                            )
                        : null,
                    onCancelSwap: _tab == ScheduledTab.confirmed && rides[i].swapListed == true
                        ? () => _cancelListedSwap(context, ref, rides[i])
                        : null,
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Text(
                  'Could not load rides',
                  style: typo.bodyMedium.copyWith(color: colors.textSoft),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
    final colors = ref.read(colorsProvider);
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

class _TabPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.isSelected,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colors.card : colors.border.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? colors.border : Colors.transparent),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: typo.bodyMedium.copyWith(
            color: isSelected ? colors.text : colors.textSoft,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _ScheduledRideCard extends StatelessWidget {
  final ScheduledRide ride;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final bool showActions;
  final bool showSwapRow;
  final VoidCallback onTap;
  final VoidCallback? onOfferSwap;
  final VoidCallback? onCancelSwap;

  const _ScheduledRideCard({
    required this.ride,
    required this.colors,
    required this.typo,
    required this.showActions,
    this.showSwapRow = false,
    required this.onTap,
    this.onOfferSwap,
    this.onCancelSwap,
  });

  String _mapThumbnailUrl() {
    final lat = ride.pickupLat ?? 52.3676;
    final lng = ride.pickupLng ?? 4.9041;
    const token = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
    return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/'
        '$lng,$lat,12,0/320x120@2x?access_token=$token';
  }

  @override
  Widget build(BuildContext context) {
    final fare = ride.estimatedFare != null
        ? '€${ride.estimatedFare!.toStringAsFixed(2)}'
        : '—';
    final timeStr = ride.scheduledPickupAt != null
        ? DateFormat('HH:mm').format(ride.scheduledPickupAt!)
        : '—';
    final distStr = ride.distanceKm != null
        ? '${ride.distanceKm!.toStringAsFixed(1)} km'
        : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$fare · Pick-up today $timeStr',
              style: typo.titleMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (distStr.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.directions_car, size: 16, color: colors.textSoft),
                  const SizedBox(width: 4),
                  Text(
                    distStr,
                    style: typo.bodySmall.copyWith(color: colors.textSoft),
                  ),
                ],
              ),
            ],
            if (ride.pickupLat != null && ride.pickupLng != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: _mapThumbnailUrl(),
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
                ),
              ),
            ],
            if (ride.pickupAddress != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      color: colors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ride.pickupAddress!,
                      style: typo.bodySmall.copyWith(color: colors.text),
                    ),
                  ),
                ],
              ),
            ],
            if (ride.destinationAddress != null) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      color: colors.text,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ride.destinationAddress!,
                      style: typo.bodySmall.copyWith(color: colors.text),
                    ),
                  ),
                ],
              ),
            ],
            if (showSwapRow &&
                (ride.status == 'accepted' ||
                    ride.status == 'driver_arrived')) ...[
              const SizedBox(height: 14),
              Consumer(
                builder: (context, ref, _) => ScheduledPrerideActions(
                  ride: ride,
                  colors: colors,
                  typo: typo,
                  onInvalidate: () {
                    ref.invalidate(scheduledRidesByTabProvider('confirmed'));
                    ref.invalidate(scheduledRidesProvider);
                  },
                ),
              ),
            ],
            if (showSwapRow) ...[
              const SizedBox(height: 14),
              if (ride.swapListed == true) ...[
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
                        onPressed: onTap,
                        child: Text(DriverStrings.rideDetails),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancelSwap,
                        child: Text(
                          DriverStrings.swapCancelOffer,
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (ride.canOfferSwap && onOfferSwap != null)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onTap,
                        child: Text(DriverStrings.rideDetails),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onOfferSwap,
                        icon: Icon(Icons.swap_horiz_rounded, size: 18, color: colors.text),
                        label: Text(DriverStrings.swapAction),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
