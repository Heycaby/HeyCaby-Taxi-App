import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/rider_search_window.dart';

/// Ongoing local notification so riders see “still searching” on the lock screen
/// and in the shade after **Notify me** (home_widget alone does not run when the app is suspended).
class RiderNotifySearchNotifications {
  RiderNotifySearchNotifications._();

  static const int notificationId = 91001;
  static const String _channelId = 'heycaby_notify_search_v1';
  static const String openHomePayload = 'notify_search_open_home';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Same instance used for permission checks on iOS ([checkPermissions]).
  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  static void Function()? _onTapOpenHome;
  static bool _initialized = false;

  static void bindTapHandler(void Function() openHome) {
    _onTapOpenHome = openHome;
  }

  /// Call from [main] before [runApp]. [bindTapHandler] must be set from UI
  /// before the user can tap a notification.
  static Future<void> pluginInitialize() async {
    if (kIsWeb) return;
    if (!defaultTargetPlatform.supportsNotify) return;
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    _initialized = true;
  }

  static void _onNotificationResponse(NotificationResponse response) {
    if (response.payload == openHomePayload) {
      _onTapOpenHome?.call();
    }
  }

  /// If the app was opened by tapping this notification, consume it once.
  static Future<void> handleColdStartIfLaunchedFromNotification() async {
    if (kIsWeb || !_initialized) return;
    if (!defaultTargetPlatform.supportsNotify) return;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return;
      final payload = details?.notificationResponse?.payload;
      if (payload == openHomePayload) {
        _onTapOpenHome?.call();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RiderNotifySearchNotifications.handleColdStart: $e');
      }
    }
  }

  /// Request OS permission — call when the user opts into **Notify me**.
  static Future<bool> ensureNotifyPermission() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: false,
          ) ??
          false;
      return granted;
    }
    return true;
  }

  static Future<void> showOrUpdate({
    required String pickupSummary,
    required String destinationSummary,
    required DateTime startedAt,
  }) async {
    if (kIsWeb || !_initialized) return;
    if (!defaultTargetPlatform.supportsNotify) return;

    final elapsed = DateTime.now().difference(startedAt);
    final remaining = kRiderDriverSearchWindow - elapsed;
    final minutesLeft = remaining.isNegative
        ? 0
        : (remaining.inSeconds / 60).ceil().clamp(0, 999);

    const title = 'HeyCaby · Searching for driver';
    final dest = destinationSummary.trim();
    final pickup = pickupSummary.trim();
    final routeLine = dest.isNotEmpty
        ? 'To: $dest'
        : (pickup.isNotEmpty ? 'Pickup: $pickup' : 'Tap to open HeyCaby');
    final body = '$routeLine · ~$minutesLeft min left in search window';

    final android = AndroidNotificationDetails(
      _channelId,
      'Driver search',
      channelDescription:
          'Shown while HeyCaby looks for a driver after you use Notify me.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: true,
      autoCancel: false,
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
      showWhen: false,
      onlyAlertOnce: true,
    );

    const darwin = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: true,
      presentSound: false,
    );

    await _plugin.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: android,
        iOS: darwin,
        macOS: darwin,
      ),
      payload: openHomePayload,
    );
  }

  static Future<void> dismiss() async {
    if (kIsWeb || !_initialized) return;
    if (!defaultTargetPlatform.supportsNotify) return;
    await _plugin.cancel(id: notificationId);
  }
}

extension on TargetPlatform {
  bool get supportsNotify =>
      this == TargetPlatform.android || this == TargetPlatform.iOS;
}
