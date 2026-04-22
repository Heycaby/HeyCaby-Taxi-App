import 'package:flutter/foundation.dart';
import 'package:live_activities/live_activities.dart';

import '../constants/heycaby_widget_config.dart';
import '../constants/rider_search_window.dart';

/// iOS 16.1+ Live Activity for “notify me” / background driver search.
///
/// Requires the Widget extension target to include [ActivityConfiguration] for
/// [LiveActivitiesAppAttributes] (see `ios/HeyCabyWidgets/HeyCabyWidgets.swift`)
/// and **Push Notifications** capability if `Activity.request` with `pushType: .token`
/// is rejected without it.
class RiderNotifyLiveActivity {
  RiderNotifyLiveActivity._();

  static final LiveActivities _live = LiveActivities();

  /// Stable logical id; the plugin maps this to a deterministic UUID.
  static const String activityId = 'heycaby_notify_search';

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

  static Future<void> syncNotifySearch({
    required String pickupSummary,
    required String destinationSummary,
    required DateTime startedAt,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      if (await _live.areActivitiesSupported() != true) return;
      if (await _live.areActivitiesEnabled() != true) return;
    } catch (e) {
      if (kDebugMode) debugPrint('RiderNotifyLiveActivity.capability: $e');
      return;
    }

    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    final route = destinationSummary.isNotEmpty
        ? (pickupSummary.isNotEmpty
            ? '$pickupSummary → $destinationSummary'
            : destinationSummary)
        : pickupSummary;

    try {
      await _live.createOrUpdateActivity(
        activityId,
        {
          'headline': 'Searching for driver',
          'subtitle': route.isEmpty ? 'HeyCaby' : route,
          'detail': '${elapsed}s in search window',
        },
        staleIn: kRiderDriverSearchWindow,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('RiderNotifyLiveActivity.sync: $e');
    }
  }

  static Future<void> end() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _live.endActivity(activityId);
    } catch (e) {
      if (kDebugMode) debugPrint('RiderNotifyLiveActivity.end: $e');
    }
  }
}
