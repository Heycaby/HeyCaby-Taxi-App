import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_return_trips_body.dart';
import '../widgets/driver_trip_planning_flow_common.dart';

final _returnDiscountPctProvider = StateProvider<double>((_) => 0);

class DriverReturnTripsScreen extends ConsumerStatefulWidget {
  const DriverReturnTripsScreen({super.key});

  @override
  ConsumerState<DriverReturnTripsScreen> createState() => _DriverReturnTripsScreenState();
}

class _DriverReturnTripsScreenState extends ConsumerState<DriverReturnTripsScreen> {
  RealtimeChannel? _channel;
  Timer? _debounce;
  bool _initializedFromProfile = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _channel = HeyCabySupabase.client
          .channel('return_market')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'ride_requests',
            callback: (_) {
              ref.invalidate(driverReturnTripsProvider);
              ref.invalidate(filteredReturnTripsProvider);
            },
          )
          .subscribe();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_channel != null) {
      HeyCabySupabase.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography = DriverTypography.fromTheme(ref.watch(typographyProvider));

    final tripsAsync = ref.watch(filteredReturnTripsProvider);
    final trips = tripsAsync.valueOrNull ?? const <DriverReturnTrip>[];

    final activeProfile = ref.watch(activeRateProfileProvider).valueOrNull;
    final initialPct = (activeProfile?.returnDiscountPct ?? 0).clamp(0, 40).toDouble();
    final currentPct = ref.watch(_returnDiscountPctProvider);

    if (activeProfile != null && !_initializedFromProfile) {
      _initializedFromProfile = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(_returnDiscountPctProvider.notifier).state = initialPct;
      });
    }

    final first = trips.isNotEmpty ? trips.first : null;
    final subtitle = first == null
        ? null
        : '${first.pickupZoneName ?? '—'} → ${first.destinationZoneName ?? first.destinationCity ?? '—'}'
            '${first.distanceKm != null ? ' route, ${first.distanceKm!.toStringAsFixed(0)} km' : ''}';

    return DriverReturnTripsBody(
      colors: colors,
      typography: typography,
      subtitle: subtitle,
      discountPct: currentPct,
      computedFareText: _computedFareText(trips: trips, discountPct: currentPct),
      chanceLabel: _matchChanceLabel(discountPct: currentPct),
      chanceColor: _matchChanceColor(colors: colors, discountPct: currentPct),
      loading: tripsAsync.isLoading,
      trips: trips.map((trip) {
        final offered = trip.offeredFare;
        final discounted =
            offered == null ? null : offered * (1 - (currentPct / 100));
        return DriverReturnTripOfferItem(
          fromLabel: trip.pickupZoneName ?? '—',
          toLabel: trip.destinationZoneName ?? trip.destinationCity ?? '—',
          offeredFareLabel:
              offered == null ? null : '€${offered.toStringAsFixed(2)}',
          discountedFareLabel: discounted == null
              ? null
              : '€${discounted.toStringAsFixed(2)}',
          distanceLabel: trip.distanceKm == null
              ? null
              : '${trip.distanceKm!.toStringAsFixed(1)} km',
          durationLabel: trip.estimatedDurationMin == null
              ? null
              : '${trip.estimatedDurationMin!.toStringAsFixed(0)} min',
          canAccept: trip.rideRequestId != null,
        );
      }).toList(),
      onBack: () => context.pop(),
      onDiscountChanged: (v) =>
          _onDiscountChanged(activeProfile: activeProfile, v: v),
      onAcceptTrip: (index) {
        final rideRequestId = trips[index].rideRequestId;
        if (rideRequestId != null) {
          context.push('/driver/ride/new/$rideRequestId');
        }
      },
    );
  }

  void _onDiscountChanged({required DriverRateProfile? activeProfile, required double v}) {
    final snapped = (v / 5).round() * 5.0;
    ref.read(_returnDiscountPctProvider.notifier).state = snapped;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () async {
      if (activeProfile == null) return;
      await ref.read(driverDataServiceProvider).updateReturnDiscountPct(
            rateProfileId: activeProfile.id,
            returnDiscountPct: snapped,
          );
      ref.invalidate(driverRateProfilesProvider);
      ref.invalidate(activeRateProfileProvider);
    });
  }

  String _computedFareText({required List<DriverReturnTrip> trips, required double discountPct}) {
    final fare = trips.isNotEmpty ? trips.first.offeredFare : null;
    if (fare == null) return '€—';
    final discounted = fare * (1 - (discountPct / 100));
    return '€${discounted.toStringAsFixed(2)}';
  }

  String _matchChanceLabel({required double discountPct}) {
    if (discountPct <= 10) return 'low';
    if (discountPct <= 25) return 'medium';
    return 'high';
  }

  Color _matchChanceColor({required DriverColors colors, required double discountPct}) {
    if (discountPct <= 10) return colors.error;
    if (discountPct <= 25) return colors.warning;
    return colors.success;
  }
}

