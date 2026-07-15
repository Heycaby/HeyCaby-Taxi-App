import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/booking_provider.dart';
import '../providers/driver_tracking_provider.dart';
import '../providers/ride_request_provider.dart';
import 'nearby_supply_service.dart';
import 'rider_dispatch_status_service.dart';
import 'rider_driver_profile_service.dart';
import 'rider_eta_service.dart';
import 'rider_lifecycle_proof_logger.dart';
import 'rider_ride_lifecycle_snapshot.dart';
import 'rider_ride_snapshot_service.dart';
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

/// Latest full backend record fetched by the canonical Rider lifecycle engine.
///
/// Screens consume this projection instead of opening their own Realtime
/// channels or polling `ride_requests` independently.
class RiderRideBackendRecord {
  RiderRideBackendRecord({
    required this.rideRequestId,
    required Map<String, dynamic> record,
    required this.source,
    required this.revision,
  }) : record = Map<String, dynamic>.unmodifiable(record);

  final String rideRequestId;
  final Map<String, dynamic> record;
  final String source;
  final String revision;
}

final riderRideBackendRecordProvider =
    StateProvider<RiderRideBackendRecord?>((ref) => null);

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
      final ride = _ref.read(rideRequestProvider);
      final row = await RiderRideSnapshotService.fetch(
        rideRequestId: rideId,
        riderToken: ride.riderToken,
      );
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
      final changed = RiderRideLifecycleSnapshot.changedFields(prev, snapshot);
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

    _ref.read(riderRideBackendRecordProvider.notifier).state =
        RiderRideBackendRecord(
      rideRequestId: rideId,
      record: record,
      source: source,
      revision: [
        record['updated_at'],
        record['driver_on_my_way_at'],
      ].join('|'),
    );

    if (RiderRideStatuses.isSearch(effectiveStatus)) {
      final dispatch = await RiderDispatchStatusService.fetch(rideId);
      _driversNotified = dispatch.driversNotified;
    }

    if (RiderRideStatuses.isActive(effectiveStatus) ||
        effectiveStatus == 'payment_confirmed') {
      await _refreshDriverProfile(rideId, ride.riderToken);
      _ref.read(driverTrackingProvider.notifier).startTracking(rideId);
    }

    final presentation =
        await _buildPresentation(ride, record, effectiveStatus);

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
      presentation: await _buildPresentation(
        ride,
        {},
        snapshot.resolveEffectiveStatus(),
      ),
      source: source,
    );
  }

  void resetForRideChange({String? previousRideId}) {
    final rideId = previousRideId ??
        _ref.read(riderRideBackendRecordProvider)?.rideRequestId;
    if (rideId != null) RiderRideStateVersionGate.reset(rideId);
    final projected = _ref.read(riderRideBackendRecordProvider);
    if (projected == null ||
        previousRideId == null ||
        projected.rideRequestId == previousRideId) {
      _ref.read(riderRideBackendRecordProvider.notifier).state = null;
    }
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
    _vehicleLabel =
        (map['vehicle_label'] ?? map['vehicle_model'] ?? '').toString();
    _vehiclePlate = (map['vehicle_plate'] ?? map['plate'] ?? '').toString();
  }

  Future<RideStatePresentation> _buildPresentation(
    RideRequestState ride,
    Map<String, dynamic> record,
    String effectiveStatus,
  ) async {
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
    if (driverLocation != null &&
        booking.pickup != null &&
        booking.pickup!.hasValidCoords &&
        driverLocation.lat != 0 &&
        driverLocation.lng != 0) {
      driverKmToPickup = NearbySupplyService.distanceKm(
        driverLocation.lat,
        driverLocation.lng,
        booking.pickup!.lat,
        booking.pickup!.lng,
      );
      final target = effectiveStatus == 'in_progress'
          ? booking.destination
          : booking.pickup;
      if (target != null && target.hasValidCoords) {
        etaMinutes = await RiderEtaService.etaMinutes(
          fromLat: driverLocation.lat,
          fromLng: driverLocation.lng,
          toLat: target.lat,
          toLng: target.lng,
        );
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
      paymentMethodLabel: booking.paymentMethods.isNotEmpty
          ? booking.paymentMethods.first
          : null,
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
