import 'package:flutter/foundation.dart';
import 'package:heycaby_api/heycaby_api.dart';

import 'rider_lifecycle_proof_logger.dart';
import '../models/live_ride_activity_phase.dart';
import 'live_ride_activity_payload.dart';
import 'rider_dispatch_status_service.dart';
import 'rider_driver_profile_service.dart';
import 'rider_notification_router.dart'
    show behaviorForCategory, RiderNotificationBehavior;
import 'rider_notify_live_activity.dart';
import 'rider_ride_lifecycle_snapshot.dart';
import 'rider_ride_snapshot_service.dart';
import 'rider_ride_state_version.dart';

/// **Single door** for backend ride truth → Live Activity (+ optional in-app sync).
///
/// Every trigger (realtime, FCM, poll, resume, background FCM) must call
/// [refreshRideStateFromServer] or [refreshRideStateFromRow].
///
/// ActivityKit is updated only inside [RiderNotifyLiveActivity] — never elsewhere.
abstract final class RiderRideStateRefresh {
  /// Fetch full row → resolve lifecycle → version gate → ActivityKit.
  static Future<void> refreshRideStateFromServer({
    required String rideRequestId,
    required String source,
    RideStatePresentation? presentation,
  }) async {
    try {
      final row = await RiderRideSnapshotService.fetch(
        rideRequestId: rideRequestId,
      );
      if (row == null) return;
      await refreshRideStateFromRow(
        row: Map<String, dynamic>.from(row),
        rideRequestId: rideRequestId,
        source: source,
        presentation: presentation ?? presentationFromRow(row),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RideLifecycleEngine] refresh failed source=$source: $e');
      }
    }
  }

  /// Apply a pre-fetched row (realtime path after full fetch, or tests).
  static Future<void> refreshRideStateFromRow({
    required Map<String, dynamic> row,
    required String rideRequestId,
    required String source,
    RideStatePresentation? presentation,
  }) async {
    final snapshot = RiderRideLifecycleSnapshot.fromRow(
      row,
      rideRequestId: rideRequestId,
    );
    final version = snapshot.rideVersion;
    final effectiveStatus = snapshot.resolveEffectiveStatus();
    final terminal = RiderRideStatuses.isTerminal(effectiveStatus);

    if (!RiderRideStateVersionGate.shouldApply(
      rideRequestId: rideRequestId,
      incomingVersion: version,
      source: source,
    )) {
      if (terminal) {
        await RiderNotifyLiveActivity.end();
      }
      return;
    }

    if (kDebugMode) {
      debugPrint(
        '[RideLifecycleEngine] refreshRideState source=$source ride=$rideRequestId '
        'rideVersion=$version effectiveStatus=$effectiveStatus',
      );
    }

    var pres = presentation ?? presentationFromRow(row);

    if (RiderRideStatuses.isSearch(effectiveStatus)) {
      final dispatch = await RiderDispatchStatusService.fetch(rideRequestId);
      pres = pres.copyWith(driversNotified: dispatch.driversNotified);
    }

    if (RiderRideStatuses.isActive(effectiveStatus) ||
        effectiveStatus == 'payment_confirmed') {
      if (pres.driverName.trim().isEmpty) {
        final riderToken = row['rider_token']?.toString();
        final profile = await RiderDriverProfileService.fetchForRide(
          rideRequestId: rideRequestId,
          riderToken: riderToken,
        );
        if (profile != null) {
          pres = pres.copyWith(
            driverName: (profile['full_name'] ?? profile['driver_name'] ?? '')
                .toString(),
            vehicleLabel:
                (profile['vehicle_label'] ?? profile['vehicle_model'] ?? '')
                    .toString(),
            vehiclePlate:
                (profile['vehicle_plate'] ?? profile['plate'] ?? '').toString(),
          );
        }
      }
    }

    await _syncLiveActivity(
      snapshot: snapshot,
      effectiveStatus: effectiveStatus,
      presentation: pres,
      source: source,
    );

    RiderRideStateVersionGate.markApplied(
      rideRequestId: rideRequestId,
      version: version,
      source: source,
    );
  }

  /// Local-only refresh (grace countdown, driver location ETA) — no version gate.
  static Future<void> refreshLocalPresentation({
    required RiderRideLifecycleSnapshot snapshot,
    required String effectiveStatus,
    required RideStatePresentation presentation,
    required String source,
  }) async {
    await _syncLiveActivity(
      snapshot: snapshot,
      effectiveStatus: effectiveStatus,
      presentation: presentation,
      source: source,
    );
  }

  static Future<void> _syncLiveActivity({
    required RiderRideLifecycleSnapshot snapshot,
    required String effectiveStatus,
    required RideStatePresentation presentation,
    required String source,
  }) async {
    final status = effectiveStatus;
    final paymentStatus = snapshot.paymentStatus;
    final waitingInfo = snapshot.waitingInfo;

    if (status.isEmpty) {
      await RiderNotifyLiveActivity.end();
      return;
    }

    final phase = LiveRideActivityPayload.resolveActivePhase(
      rideStatus: status,
      waitingInfo: waitingInfo,
      driverKmToPickup: presentation.driverKmToPickup,
      paymentPending: status == 'completed' &&
          (paymentStatus ?? '').toLowerCase() != 'paid',
      paymentComplete: status == 'payment_confirmed' ||
          (paymentStatus ?? '').toLowerCase() == 'paid',
    );

    if (kDebugMode) {
      final grace = waitingInfo?.remainingGraceSecondsNow();
      debugPrint(
        '[RideLifecycleEngine] resolvedPhase=${phase.wireValue} '
        'rideVersion=${snapshot.rideVersion} source=$source '
        '${grace != null ? 'freeWait=$grace' : ''}',
      );
    }

    if (RiderRideStatuses.isTerminal(status)) {
      await RiderNotifyLiveActivity.endTerminalRide(
        rideRequestId: snapshot.rideRequestId,
        status: status,
        driverName: presentation.driverName,
        vehicleLabel: presentation.vehicleLabel,
        plate: presentation.vehiclePlate,
        etaMinutes: presentation.etaMinutes,
        destination: presentation.destinationSummary,
        paymentComplete: status == 'payment_confirmed' ||
            (paymentStatus ?? '').toLowerCase() == 'paid',
        paymentPending: status == 'completed' &&
            (paymentStatus ?? '').toLowerCase() != 'paid',
        rideVersion: snapshot.rideVersion,
      );
      return;
    }

    if (RiderRideStatuses.isSearch(status)) {
      await RiderNotifyLiveActivity.syncNotifySearch(
        rideRequestId: snapshot.rideRequestId,
        pickupSummary: presentation.pickupSummary,
        destinationSummary: presentation.destinationSummary,
        startedAt: presentation.rideCreatedAt ?? DateTime.now(),
        driversNotified: presentation.driversNotified,
        rideVersion: snapshot.rideVersion,
      );
      RiderLifecycleProofLogger.widgetUpdated(
        rideId: snapshot.rideRequestId,
        phase: 'searching',
        rideVersion: snapshot.rideVersion,
      );
      return;
    }

    if (RiderRideStatuses.isActive(status) || status == 'payment_confirmed') {
      await RiderNotifyLiveActivity.syncActiveRide(
        rideRequestId: snapshot.rideRequestId,
        status: status,
        driverName: presentation.driverName,
        vehicleLabel: presentation.vehicleLabel,
        plate: presentation.vehiclePlate,
        etaMinutes: presentation.etaMinutes,
        destination: presentation.destinationSummary,
        waitingInfo: waitingInfo,
        driverKmToPickup: presentation.driverKmToPickup,
        rideVersion: snapshot.rideVersion,
        paymentMethodLabel: presentation.paymentMethodLabel,
        paymentPending: false,
        paymentComplete: status == 'payment_confirmed',
      );
      return;
    }

    await RiderNotifyLiveActivity.end();
  }
}

/// Status sets shared by engine + refresh (avoid circular imports).
abstract final class RiderRideStatuses {
  static const search = {'pending', 'bidding'};
  static const active = {
    'assigned',
    'accepted',
    'driver_found',
    'driver_en_route',
    'driver_nearby',
    'driver_arrived',
    'arrived',
    'in_progress',
  };
  static const terminal = {
    'completed',
    'payment_confirmed',
    'cancelled',
    'canceled',
    'rejected',
    'declined',
    'missed',
    'expired',
  };

  static bool isSearch(String? s) => s != null && search.contains(s);
  static bool isActive(String? s) => s != null && active.contains(s);
  static bool isTerminal(String? s) => s != null && terminal.contains(s);
}

/// FCM / push categories that should trigger [RiderRideStateRefresh].
bool isRideLifecyclePushCategory(String? category) {
  switch (behaviorForCategory(category)) {
    case RiderNotificationBehavior.driverAccepted:
    case RiderNotificationBehavior.driverPingOnMyWay:
    case RiderNotificationBehavior.driverPingOutside:
    case RiderNotificationBehavior.driverPingArrived:
    case RiderNotificationBehavior.driverPingOther:
    case RiderNotificationBehavior.tripStarted:
    case RiderNotificationBehavior.tripCompleted:
    case RiderNotificationBehavior.payment:
    case RiderNotificationBehavior.rideCancelled:
      return true;
    case RiderNotificationBehavior.rideOffer:
    case RiderNotificationBehavior.chat:
    case RiderNotificationBehavior.rating:
    case RiderNotificationBehavior.generic:
      return false;
  }
}

/// Background FCM entry (no Riverpod — app may be suspended).
abstract final class RiderRideStateBackgroundRefresh {
  static Future<void> ensureBackendReady() async {
    await HeyCabySupabase.initialize();
    try {
      if (HeyCabySupabase.client.auth.currentSession == null) {
        await HeyCabySupabase.client.auth.signInAnonymously();
      }
    } catch (_) {}
  }

  static Future<void> handlePushData(Map<String, dynamic> data) async {
    final category = data['category']?.toString();
    if (!isRideLifecyclePushCategory(category)) return;

    final rideId = rideRequestIdFromPushData(data);
    if (rideId == null || rideId.isEmpty) return;

    await RiderRideStateRefresh.refreshRideStateFromServer(
      rideRequestId: rideId,
      source: 'fcm_background',
    );
  }
}
