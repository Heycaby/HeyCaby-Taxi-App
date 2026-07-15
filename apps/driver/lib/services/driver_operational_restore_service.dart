import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';
import '../providers/driver_taxi_terug_queued_provider.dart';
import '../providers/driver_taxi_terug_stats_provider.dart';
import '../services/driver_data_service.dart';
import 'driver_operational_restore_models.dart';
import 'ride_gps_tracker.dart';

/// Program 3B — restore shift availability + active ride from server on cold start.
class DriverOperationalRestoreService {
  DriverOperationalRestoreService(this._dataService);

  final DriverDataService _dataService;

  Future<DriverOperationalRestoreSnapshot?> fetchSnapshot(
      String driverId) async {
    try {
      final driverRow = await HeyCabySupabase.client
          .from('drivers')
          .select('status')
          .eq('id', driverId)
          .maybeSingle();
      if (driverRow == null) return null;

      final serverStatus = driverRow['status'] as String?;
      final availability = driverAvailabilityFromServerStatus(serverStatus);

      final rideRow = await _dataService.getActiveRideForRestore(driverId);
      DriverActiveRideSnapshot? activeRide;
      if (rideRow != null) {
        activeRide = DriverActiveRideSnapshot.fromRow(rideRow);
      }

      return DriverOperationalRestoreSnapshot(
        availabilityState: availability,
        activeRide: activeRide,
        serverDriverStatus: serverStatus,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DriverOperationalRestoreService.fetchSnapshot: $e');
      }
      return null;
    }
  }

  void applyToState(
      DriverStateNotifier notifier, DriverOperationalRestoreSnapshot snap) {
    final ride = snap.activeRide;
    if (ride != null) {
      notifier.applyOperationalRestore(
        appState: ride.appState,
        activeRideId: ride.rideId,
        pickupAddress: ride.pickupAddress,
        pickupLat: ride.pickupLat,
        pickupLng: ride.pickupLng,
        destinationAddress: ride.destinationAddress,
        destinationLat: ride.destinationLat,
        destinationLng: ride.destinationLng,
        bookedDestinationAddress: ride.bookedDestinationAddress,
        bookedDestinationLat: ride.bookedDestinationLat,
        bookedDestinationLng: ride.bookedDestinationLng,
        routeStops: ride.routeStops,
        routeRevision: ride.routeRevision,
        bookingMode: ride.bookingMode,
        paymentMethod: ride.paymentMethod,
        riderContactName: ride.riderContactName,
      );
    } else {
      notifier.applyOperationalRestore(
        appState: snap.availabilityState,
        clearActiveRide: true,
      );
    }
  }

  /// Returns true if navigation was performed.
  bool navigateIfNeeded(
      GoRouter router, DriverOperationalRestoreSnapshot snap) {
    final target = snap.navigationRoute;
    if (target == null) return false;

    final current = router.routeInformationProvider.value.uri.path;
    if (current == target || current.startsWith('$target/')) return false;
    if (snap.activeRide != null) {
      router.go(target);
      return true;
    }
    return false;
  }
}

final driverOperationalRestoreServiceProvider =
    Provider<DriverOperationalRestoreService>(
  (ref) => DriverOperationalRestoreService(ref.read(driverDataServiceProvider)),
);

/// One-shot cold-start restore after auth + driver row exist.
Future<void> restoreDriverOperationalState(
    WidgetRef ref, GoRouter router) async {
  final driverId = await ref.read(driverIdProvider.future);
  if (driverId == null) return;

  final service = ref.read(driverOperationalRestoreServiceProvider);
  final snap = await service.fetchSnapshot(driverId);
  if (snap == null) return;

  service.applyToState(ref.read(driverStateProvider.notifier), snap);
  ref.invalidate(driverShiftStatsProvider);
  ref.invalidate(driverEarningsProvider);
  ref.invalidate(driverTaxiTerugStatsProvider);

  service.navigateIfNeeded(router, snap);

  // Resume GPS breadcrumb tracking if restoring an in_progress ride.
  if (snap.activeRide != null &&
      snap.activeRide!.appState == DriverAppState.inProgress) {
    unawaited(RideGpsTracker().startTracking(snap.activeRide!.rideId));
  }

  if (kDebugMode) {
    debugPrint(
      'DriverOperationalRestore: status=${snap.serverDriverStatus} '
      'effective=${snap.effectiveAppState} route=${snap.navigationRoute}',
    );
  }
}

/// After completing a ride, resume an activated queued Taxi Terug booking if any.
Future<bool> resumeActivatedTaxiTerugRideIfAny(
  WidgetRef ref,
  GoRouter router,
) async {
  final driverId = await ref.read(driverIdProvider.future);
  if (driverId == null) return false;

  final service = ref.read(driverOperationalRestoreServiceProvider);
  final snap = await service.fetchSnapshot(driverId);
  if (snap?.activeRide == null) return false;

  service.applyToState(ref.read(driverStateProvider.notifier), snap!);
  ref.invalidate(driverShiftStatsProvider);
  ref.invalidate(driverEarningsProvider);
  ref.invalidate(driverTaxiTerugStatsProvider);
  ref.invalidate(driverTaxiTerugQueuedProvider);
  return service.navigateIfNeeded(router, snap);
}
