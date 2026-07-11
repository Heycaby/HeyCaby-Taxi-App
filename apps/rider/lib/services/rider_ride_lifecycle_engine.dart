import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../providers/booking_provider.dart';
import '../providers/driver_tracking_provider.dart';
import '../providers/ride_request_provider.dart';
import 'nearby_supply_service.dart';
import 'rider_dispatch_status_service.dart';
import 'rider_driver_profile_service.dart';
import 'rider_lifecycle_proof_logger.dart';
import 'rider_ride_lifecycle_snapshot.dart';
import 'rider_ride_state_refresh.dart';
import 'rider_ride_state_version.dart';

export 'rider_ride_state_version.dart' show rideRequestIdFromPushData;
export 'rider_ride_state_refresh.dart'
    show
        RiderRideStateBackgroundRefresh,
        RiderRideStateRefresh,
        RiderRideStatuses,
        isRideLifecyclePushCategory;

/// Riverpod hub: orchestrates the full ride lifecycle → Rider UI + Live Activity.
final riderRideLifecycleEngineProvider = Provider<RiderRideLifecycleEngine>(
  RiderRideLifecycleEngine.new,
);

/// Orchestrates the entire ride lifecycle. All paths call [refreshRideState].
class RiderRideLifecycleEngine {
  RiderRideLifecycleEngine(this._ref);

  final Ref _ref;

  String _driverName = '';
  String _vehicleLabel = '';
  String _vehiclePlate = '';
  int _driversNotified = 0;
  RiderRideLifecycleSnapshot? _lifecycle;

  bool get shouldRunGraceTick => _lifecycle?.isInWaitingGraceWindow ?? false;

  /// **Single entry point.** Realtime, FCM, poll, resume, and screens all use this.
  Future<void> refreshRideState({required String source}) async {
    final rideId = _ref.read(rideRequestProvider).rideRequestId;
    if (rideId == null || rideId.isEmpty) return;

    try {
      final row = await HeyCabySupabase.client
          .from('ride_requests')
          .select(kRiderRideLifecycleSelect)
          .eq('id', rideId)
          .maybeSingle();
      if (row == null) return;
      await applyBackendRecord(
        Map<String, dynamic>.from(row),
        source: source,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RideLifecycleEngine] refreshRideState failed: $e');
      }
    }
  }

  /// Apply a fetched row: update Rider UI providers, then sync Live Activity.
  Future<void> applyBackendRecord(
    Map<String, dynamic> record, {
    required String source,
  }) async {
    final ride = _ref.read(rideRequestProvider);
    final rideId = ride.rideRequestId ?? record['id']?.toString();
    if (rideId == null || rideId.isEmpty) return;

    final snapshot = RiderRideLifecycleSnapshot.fromRow(
      record,
      rideRequestId: rideId,
    );

    final prev = _lifecycle;
    final lifecycleChanged = snapshot.fingerprint() != prev?.fingerprint();
    _lifecycle = snapshot;

    final effectiveStatus = snapshot.resolveEffectiveStatus();
    final providerStatus = inferRideProviderStatus(snapshot);

    if (kDebugMode && lifecycleChanged) {
      final changed =
          RiderRideLifecycleSnapshot.changedFields(prev, snapshot);
      debugPrint(
        '[RideLifecycleEngine] $source ride=$rideId '
        'changedFields=${changed.join(',')} '
        'rideVersion=${snapshot.rideVersion} effectiveStatus=$effectiveStatus',
      );
    }

    RiderLifecycleProofLogger.engineRefresh(
      rideId: rideId,
      source: source,
      effectiveStatus: effectiveStatus,
      rideVersion: snapshot.rideVersion,
    );

    if (providerStatus.isNotEmpty && providerStatus != ride.status) {
      _ref.read(rideRequestProvider.notifier).updateStatus(providerStatus);
    }

    if (RiderRideStatuses.isSearch(effectiveStatus)) {
      final dispatch = await RiderDispatchStatusService.fetch(rideId);
      _driversNotified = dispatch.driversNotified;
    }

    if (RiderRideStatuses.isActive(effectiveStatus) ||
        effectiveStatus == 'payment_confirmed') {
      await _refreshDriverProfile(rideId, ride.riderToken);
      _ref.read(driverTrackingProvider.notifier).startTracking(rideId);
    }

    final presentation = _buildPresentation(ride, record, effectiveStatus);

    if (RiderRideStateVersionGate.isGraceTickSource(source)) {
      await RiderRideStateRefresh.refreshLocalPresentation(
        snapshot: snapshot,
        effectiveStatus: effectiveStatus,
        presentation: presentation,
        source: source,
      );
      return;
    }

    await RiderRideStateRefresh.refreshRideStateFromRow(
      row: record,
      rideRequestId: rideId,
      source: source,
      presentation: presentation,
    );
  }

  /// Grace countdown + driver location ETA (local clock, no new DB version).
  Future<void> fanOutFromCurrentState({required String source}) async {
    final ride = _ref.read(rideRequestProvider);
    final rideId = ride.rideRequestId;
    final snapshot = _lifecycle;
    if (rideId == null || snapshot == null) return;

    await RiderRideStateRefresh.refreshLocalPresentation(
      snapshot: snapshot,
      effectiveStatus: snapshot.resolveEffectiveStatus(),
      presentation: _buildPresentation(
        ride,
        {},
        snapshot.resolveEffectiveStatus(),
      ),
      source: source,
    );
  }

  void resetForRideChange() {
    final rideId = _ref.read(rideRequestProvider).rideRequestId;
    if (rideId != null) RiderRideStateVersionGate.reset(rideId);
    _driverName = '';
    _vehicleLabel = '';
    _vehiclePlate = '';
    _driversNotified = 0;
    _lifecycle = null;
  }

  Future<void> _refreshDriverProfile(String rideId, String? riderToken) async {
    final map = await RiderDriverProfileService.fetchForRide(
      rideRequestId: rideId,
      riderToken: riderToken,
    );
    if (map == null) return;
    _driverName = (map['full_name'] ?? map['driver_name'] ?? '').toString();
    _vehicleLabel = (map['vehicle_label'] ?? map['vehicle_model'] ?? '')
        .toString();
    _vehiclePlate = (map['vehicle_plate'] ?? map['plate'] ?? '').toString();
  }

  RideStatePresentation _buildPresentation(
    RideRequestState ride,
    Map<String, dynamic> record,
    String effectiveStatus,
  ) {
    final booking = _ref.read(bookingProvider);
    final pickup = booking.pickup?.displayName ??
        record['pickup_address']?.toString() ??
        '';
    final dest = booking.destination?.displayName ??
        record['destination_address']?.toString() ??
        '';

    final driverLocation = _ref.read(driverTrackingProvider).valueOrNull;
    double? driverKmToPickup;
    int? etaMinutes;
    if (driverLocation != null && booking.pickup != null) {
      driverKmToPickup = NearbySupplyService.distanceKm(
        driverLocation.lat,
        driverLocation.lng,
        booking.pickup!.lat,
        booking.pickup!.lng,
      );
      final target =
          effectiveStatus == 'in_progress' ? booking.destination : booking.pickup;
      if (target != null) {
        final km = NearbySupplyService.distanceKm(
          driverLocation.lat,
          driverLocation.lng,
          target.lat,
          target.lng,
        );
        etaMinutes = ((km / 28.0) * 60.0).ceil().clamp(1, 90);
      }
    }

    return RideStatePresentation(
      driverName: _driverName,
      vehicleLabel: _vehicleLabel,
      vehiclePlate: _vehiclePlate,
      pickupSummary: pickup,
      destinationSummary: dest,
      rideCreatedAt:
          ride.rideCreatedAt ?? presentationFromRow(record).rideCreatedAt,
      driversNotified: _driversNotified,
      driverKmToPickup: driverKmToPickup,
      etaMinutes: etaMinutes,
      paymentMethodLabel:
          booking.paymentMethods.isNotEmpty ? booking.paymentMethods.first : null,
    );
  }
}

/// Refreshes ride row from Supabase → [RiderRideLifecycleEngine.refreshRideState].
Future<void> riderRideLifecycleEngineRefreshFromServer(
  WidgetRef ref, {
  required String rideRequestId,
  required String source,
}) async {
  await ref
      .read(riderRideLifecycleEngineProvider)
      .refreshRideState(source: source);
}

/// Legacy alias — prefer [riderRideLifecycleEngineRefreshFromServer].
@Deprecated('Use riderRideLifecycleEngineRefreshFromServer')
Future<void> riderRideStateEngineRefreshFromServer(
  WidgetRef ref, {
  required String rideRequestId,
  required String source,
}) =>
    riderRideLifecycleEngineRefreshFromServer(
      ref,
      rideRequestId: rideRequestId,
      source: source,
    );

/// Legacy provider alias.
@Deprecated('Use riderRideLifecycleEngineProvider')
final riderRideStateEngineProvider = riderRideLifecycleEngineProvider;

/// Legacy class alias.
@Deprecated('Use RiderRideLifecycleEngine')
typedef RiderRideStateEngine = RiderRideLifecycleEngine;
