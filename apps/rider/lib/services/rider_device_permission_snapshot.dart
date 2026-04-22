import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'rider_notify_search_notifications.dart';

/// OS-level permission truth for Account settings (not stored prefs alone).
class RiderDevicePermissionSnapshot {
  const RiderDevicePermissionSnapshot({
    required this.locationGranted,
    required this.notificationsGranted,
  });

  final bool locationGranted;
  final bool notificationsGranted;

  static Future<bool> _iosNotificationsFromUserNotifications() async {
    try {
      final plugin = RiderNotifySearchNotifications.plugin;
      final ios = plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final opts = await ios?.checkPermissions();
      if (opts == null) return false;
      return opts.isEnabled ||
          opts.isProvisionalEnabled ||
          opts.isAlertEnabled ||
          opts.isBadgeEnabled;
    } catch (_) {
      return false;
    }
  }

  /// Location: when-in-use, always, or iOS approximate (`limited`).
  /// Also cross-checks [Geolocator] when the handler status looks wrong.
  ///
  /// Notifications: on iOS, [Permission.notification] is wrong unless
  /// `PERMISSION_NOTIFICATIONS=1` is set for the permission_handler_apple pod;
  /// we also read [UNUserNotificationCenter] via flutter_local_notifications.
  static Future<RiderDevicePermissionSnapshot> read() async {
    final locPh = await Permission.locationWhenInUse.status;
    var locationOk = locPh.isGranted || locPh == PermissionStatus.limited;

    try {
      final gp = await Geolocator.checkPermission();
      if (gp == LocationPermission.always ||
          gp == LocationPermission.whileInUse) {
        locationOk = true;
      }
    } catch (_) {}

    final notifPh = await Permission.notification.status;
    var notifOk = notifPh.isGranted || notifPh == PermissionStatus.provisional;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final fromCenter = await _iosNotificationsFromUserNotifications();
      notifOk = notifOk || fromCenter;
    }

    return RiderDevicePermissionSnapshot(
      locationGranted: locationOk,
      notificationsGranted: notifOk,
    );
  }
}
