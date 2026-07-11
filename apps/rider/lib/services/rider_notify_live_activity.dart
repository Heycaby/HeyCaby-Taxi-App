import 'package:flutter/foundation.dart';
import 'package:live_activities/live_activities.dart';

import '../constants/heycaby_widget_config.dart';
import '../constants/rider_search_window.dart';
import '../models/live_ride_activity_phase.dart';
import '../models/ride_waiting_info.dart';
import 'live_ride_activity_payload.dart';
import 'rider_lifecycle_proof_logger.dart';

/// iOS 16.1+ Live Activity for driver search and active ride tracking.
///
/// Payload keys must match `HeyCabyWidgetsLiveActivity.swift` (App Group UserDefaults).
class RiderNotifyLiveActivity {
  RiderNotifyLiveActivity._();

  static final LiveActivities _live = LiveActivities();

  static const String kRideLiveActivityId = 'heycaby_ride_live';

  /// Legacy ids — merged into [kRideLiveActivityId] so lock screen always updates in place.
  static const String searchActivityId = kRideLiveActivityId;
  static const String rideActivityId = kRideLiveActivityId;

  static LiveRideActivityPhase? _lastPhase;
  static int? _lastGraceSeconds;
  static int? _lastWaitFeeCents;
  static DateTime? _lastPaidWaitPushAt;

  static Future<void> init() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _live.init(
        appGroupId: kHeyCabyIosWidgetAppGroup,
        urlScheme: kHeyCabyWidgetUrlScheme,
        requireNotificationPermission: false,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('RiderNotifyLiveActivity.init: $e');
    }
  }

  static Future<bool> _available() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
    try {
      if (await _live.areActivitiesSupported() != true) {
        if (kDebugMode) {
          debugPrint('RiderNotifyLiveActivity: not supported on this device');
        }
        return false;
      }
      if (await _live.areActivitiesEnabled() != true) {
        if (kDebugMode) {
          debugPrint(
            'RiderNotifyLiveActivity: disabled — enable Live Activities for HeyCaby in Settings',
          );
        }
        return false;
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('RiderNotifyLiveActivity.capability: $e');
      return false;
    }
  }

  static Future<void> syncNotifySearch({
    required String pickupSummary,
    required String destinationSummary,
    required DateTime startedAt,
    int driversNotified = 0,
    int rideVersion = 0,
  }) async {
    if (!await _available()) return;

    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    final route = destinationSummary.isNotEmpty
        ? (pickupSummary.isNotEmpty
            ? '$pickupSummary → $destinationSummary'
            : destinationSummary)
        : pickupSummary;

    final payload = LiveRideActivityPayload.searching(
      routeLine: route,
      driversNotified: driversNotified,
      elapsedSeconds: elapsed,
    );

    try {
      await _live.createOrUpdateActivity(
        kRideLiveActivityId,
        _withVersion(payload.toActivityMap(), rideVersion),
        staleIn: kRiderDriverSearchWindow,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('RiderNotifyLiveActivity.sync: $e');
    }
  }

  static Future<void> syncActiveRide({
    required String status,
    required String driverName,
    required String vehicleLabel,
    required String plate,
    required int? etaMinutes,
    String? destination,
    RideWaitingInfo? waitingInfo,
    double? driverKmToPickup,
    bool paymentPending = false,
    bool paymentComplete = false,
    String? paymentMethodLabel,
    int rideVersion = 0,
  }) async {
    if (!await _available()) return;

    if (status == 'completed' || status == 'cancelled' || status == 'canceled') {
      _resetThrottle();
      if (paymentComplete) {
        await _pushActiveRidePayload(
          LiveRideActivityPayload.activeRide(
            rideStatus: status,
            driverName: driverName,
            vehicleLabel: vehicleLabel,
            plate: plate,
            etaMinutes: etaMinutes,
            destination: destination,
            paymentComplete: true,
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 4));
      }
      await endActiveRide();
      return;
    }

    final phase = LiveRideActivityPayload.resolveActivePhase(
      rideStatus: status,
      waitingInfo: waitingInfo,
      driverKmToPickup: driverKmToPickup,
      paymentPending: paymentPending,
      paymentComplete: paymentComplete,
    );

    if (_shouldThrottleUpdate(phase: phase, waitingInfo: waitingInfo)) {
      return;
    }

    final payload = LiveRideActivityPayload.activeRide(
      rideStatus: status,
      driverName: driverName,
      vehicleLabel: vehicleLabel,
      plate: plate,
      etaMinutes: etaMinutes,
      destination: destination,
      waitingInfo: waitingInfo,
      driverKmToPickup: driverKmToPickup,
      paymentPending: paymentPending,
      paymentComplete: paymentComplete,
      paymentMethodLabel: paymentMethodLabel,
    );

    await _pushActiveRidePayload(payload, rideVersion: rideVersion);
  }

  static Map<String, dynamic> _withVersion(
    Map<String, dynamic> map,
    int rideVersion,
  ) {
    if (rideVersion > 0) {
      map['rideVersion'] = '$rideVersion';
    }
    return map;
  }

  static Future<void> _pushActiveRidePayload(
    LiveRideActivityPayload payload, {
    int rideVersion = 0,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint(
          '[RideLifecycleEngine] liveActivity update phase=${payload.phase.wireValue} '
          'status=${payload.status}',
        );
      }
      RiderLifecycleProofLogger.widgetUpdated(
        rideId: kRideLiveActivityId,
        phase: payload.phase.wireValue,
        rideVersion: rideVersion,
      );
      await _live.createOrUpdateActivity(
        kRideLiveActivityId,
        _withVersion(payload.toActivityMap(), rideVersion),
        staleIn: const Duration(hours: 3),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('RiderNotifyLiveActivity.syncActiveRide: $e');
    }
  }

  static bool _shouldThrottleUpdate({
    required LiveRideActivityPhase phase,
    RideWaitingInfo? waitingInfo,
  }) {
    if (phase == LiveRideActivityPhase.outsideFreeWait && waitingInfo != null) {
      final rem = waitingInfo.remainingGraceSecondsNow();
      if (_lastPhase == phase && _lastGraceSeconds == rem) return true;
      _lastGraceSeconds = rem;
      _lastPhase = phase;
      return false;
    }

    if (phase == LiveRideActivityPhase.outsidePaidWait && waitingInfo != null) {
      final fee = waitingInfo.waitingFeeCentsNow();
      final now = DateTime.now();
      if (_lastPhase == phase &&
          _lastWaitFeeCents == fee &&
          _lastPaidWaitPushAt != null &&
          now.difference(_lastPaidWaitPushAt!) <
              const Duration(seconds: 30)) {
        return true;
      }
      _lastWaitFeeCents = fee;
      _lastPaidWaitPushAt = now;
      _lastPhase = phase;
      return false;
    }

    _lastPhase = phase;
    if (phase != LiveRideActivityPhase.outsideFreeWait) {
      _lastGraceSeconds = null;
    }
    if (phase != LiveRideActivityPhase.outsidePaidWait) {
      _lastWaitFeeCents = null;
      _lastPaidWaitPushAt = null;
    }
    return false;
  }

  static void _resetThrottle() {
    _lastPhase = null;
    _lastGraceSeconds = null;
    _lastWaitFeeCents = null;
    _lastPaidWaitPushAt = null;
  }

  static Future<void> endActiveRide() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    _resetThrottle();
    try {
      await _live.endActivity(kRideLiveActivityId);
    } catch (e) {
      if (kDebugMode) debugPrint('RiderNotifyLiveActivity.endActiveRide: $e');
    }
  }

  static Future<void> end() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _live.endActivity(kRideLiveActivityId);
    } catch (e) {
      if (kDebugMode) debugPrint('RiderNotifyLiveActivity.end: $e');
    }
  }
}
