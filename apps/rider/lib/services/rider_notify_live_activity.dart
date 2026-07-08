import 'package:flutter/foundation.dart';
import 'package:live_activities/live_activities.dart';

import '../constants/heycaby_widget_config.dart';
import '../constants/rider_search_window.dart';
import '../models/ride_waiting_info.dart';

/// iOS 16.1+ Live Activity for "notify me" / background driver search
/// and active ride tracking (driver found → en route → arrived → in progress).
///
/// Payload keys must match what `HeyCabyWidgetsLiveActivity.swift` reads from the
/// App Group `UserDefaults` via `LiveActivitiesAppAttributes.prefixedKey`.
class RiderNotifyLiveActivity {
  RiderNotifyLiveActivity._();

  static final LiveActivities _live = LiveActivities();

  static const String searchActivityId = 'heycaby_notify_search';
  static const String rideActivityId = 'heycaby_active_ride';

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
      if (await _live.areActivitiesSupported() != true) return false;
      if (await _live.areActivitiesEnabled() != true) return false;
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
  }) async {
    if (!await _available()) return;

    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    final route = destinationSummary.isNotEmpty
        ? (pickupSummary.isNotEmpty
            ? '$pickupSummary → $destinationSummary'
            : destinationSummary)
        : pickupSummary;

    try {
      await _live.createOrUpdateActivity(
        searchActivityId,
        {
          'title': 'Searching for driver',
          'subtitle': route.isEmpty ? 'HeyCaby' : route,
          'status': '${elapsed}s in search window',
          'eta': '',
          'timelineStep': '0',
        },
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
    double? quotedFareEuro,
    int? liveFareCents,
  }) async {
    if (!await _available()) return;

    try {
      await _live.endActivity(searchActivityId);
    } catch (_) {}

    if (status == 'completed' || status == 'cancelled' || status == 'canceled') {
      await endActiveRide();
      return;
    }

    final (title, subtitle, statusLabel, eta) = _ridePhaseContent(
      status: status,
      driverName: driverName,
      vehicleLabel: vehicleLabel,
      plate: plate,
      etaMinutes: etaMinutes,
      destination: destination,
    );

    final timelineStep = _timelineStepForStatus(status);
    final payload = <String, dynamic>{
      'title': title,
      'subtitle': subtitle,
      'status': statusLabel,
      'eta': eta,
      'timelineStep': '$timelineStep',
      'graceRemaining': '',
      'totalFare': '',
      'waitFee': '',
    };

    if (waitingInfo != null) {
      if (waitingInfo.isInGracePeriod) {
        payload['graceRemaining'] =
            _formatMmSs(waitingInfo.remainingGraceSecondsNow());
      }
      final totalCents = waitingInfo.totalFareCentsNow(
        quotedFareEuro: quotedFareEuro,
        liveFareCents: liveFareCents,
      );
      if (totalCents > 0) {
        payload['totalFare'] = '€${(totalCents / 100).toStringAsFixed(2)}';
      }
      final waitCents = waitingInfo.waitingFeeCentsNow();
      if (waitCents > 0) {
        payload['waitFee'] = '+€${(waitCents / 100).toStringAsFixed(2)}';
      }
    }

    try {
      await _live.createOrUpdateActivity(
        rideActivityId,
        payload,
        staleIn: const Duration(hours: 3),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('RiderNotifyLiveActivity.syncActiveRide: $e');
    }
  }

  static int _timelineStepForStatus(String status) {
    switch (status) {
      case 'accepted':
      case 'assigned':
        return 1;
      case 'driver_arrived':
      case 'arrived':
        return 2;
      case 'in_progress':
        return 3;
      case 'completed':
        return 4;
      default:
        return 0;
    }
  }

  static String _formatMmSs(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final m = (safe % 3600) ~/ 60;
    final s = (safe % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static (String, String, String, String) _ridePhaseContent({
    required String status,
    required String driverName,
    required String vehicleLabel,
    required String plate,
    required int? etaMinutes,
    String? destination,
  }) {
    final name = driverName.isEmpty ? 'Your driver' : driverName;
    final vehicle = [vehicleLabel, plate]
        .where((s) => s.isNotEmpty)
        .join(' · ');
    final etaStr = etaMinutes != null ? '$etaMinutes min' : '';

    switch (status) {
      case 'accepted':
      case 'assigned':
        return (
          'Driver on the way',
          vehicle.isEmpty ? name : '$name · $vehicle',
          'Heading to pickup',
          etaStr,
        );
      case 'driver_arrived':
      case 'arrived':
        return (
          'Driver arrived',
          vehicle.isEmpty ? name : '$name · $vehicle',
          'At pickup location',
          '',
        );
      case 'in_progress':
        return (
          'Trip in progress',
          destination ?? 'On the way',
          'En route to destination',
          etaStr,
        );
      default:
        return (
          'HeyCaby',
          name,
          status,
          '',
        );
    }
  }

  static Future<void> endActiveRide() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _live.endActivity(rideActivityId);
    } catch (e) {
      if (kDebugMode) debugPrint('RiderNotifyLiveActivity.endActiveRide: $e');
    }
  }

  static Future<void> end() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _live.endActivity(searchActivityId);
    } catch (e) {
      if (kDebugMode) debugPrint('RiderNotifyLiveActivity.end: $e');
    }
  }
}
