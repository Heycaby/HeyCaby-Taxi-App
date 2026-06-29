import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/rider_search_window.dart';
import '../utils/rider_effective_locale_bridge.dart';

/// Ongoing local notification so riders see “still searching” on the lock screen
/// and in the shade after **Notify me** (home_widget alone does not run when the app is suspended).
class RiderNotifySearchNotifications {
  RiderNotifySearchNotifications._();

  static const int notificationId = 91001;
  // Bump channel id when changing sound behavior so Android recreates it.
  static const String _channelId = 'heycaby_notify_search_v2';
  static const String openHomePayload = 'notify_search_open_home';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Same instance used for permission checks on iOS ([checkPermissions]).
  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  static void Function()? _onTapOpenHome;
  static bool _initialized = false;

  static String get _lang {
    final code = RiderEffectiveLocaleBridge.languageCode;
    if (code == 'ar') return 'ar';
    if (code == 'en') return 'en';
    return 'nl';
  }

  static String _t(String nl, String en, String ar) {
    switch (_lang) {
      case 'ar':
        return ar;
      case 'en':
        return en;
      default:
        return nl;
    }
  }

  static ({String title, String body}) _buildPersonalizedCopy({
    required int variant,
    required String destinationSummary,
    required String pickupSummary,
    required int minutesLeft,
  }) {
    final dest = destinationSummary.trim();
    final pickup = pickupSummary.trim();
    final tripLabel = dest.isNotEmpty
        ? dest
        : (pickup.isNotEmpty
            ? pickup
            : _t('je bestemming', 'your destination', 'وجهتك'));

    switch (variant % 3) {
      case 0:
        return (
          title: _t(
            'HeyCaby - We zoeken je chauffeur',
            'HeyCaby - Finding your perfect driver',
            'HeyCaby - نبحث عن السائق المناسب',
          ),
          body: _t(
            'Even geduld, we koppelen je aan de beste chauffeur in de buurt.\n'
                'Je rit naar $tripLabel is actief.\n'
                'Nog ongeveer $minutesLeft min in deze zoekronde.',
            'Hang tight, we are matching you with the best nearby driver.\n'
                'Your trip to $tripLabel is active.\n'
                'About $minutesLeft min left in this search window.',
            'لحظة من فضلك، نحن نطابقك مع أفضل سائق قريب.\n'
                'رحلتك إلى $tripLabel نشطة.\n'
                'متبقٍ حوالي $minutesLeft دقيقة في نافذة البحث.',
          ),
        );
      case 1:
        return (
          title: _t(
            'HeyCaby - Matching bezig',
            'HeyCaby - Your ride match is in progress',
            'HeyCaby - جارٍ مطابقة رحلتك',
          ),
          body: _t(
            'We selecteren zorgvuldig de juiste chauffeur voor je.\n'
                'Bestemming: $tripLabel\n'
                'Nog $minutesLeft min om je rit te bevestigen.',
            'We are carefully selecting the right driver for you.\n'
                'Destination: $tripLabel\n'
                '$minutesLeft min left to secure your ride.',
            'نحن نختار السائق المناسب لك بعناية.\n'
                'الوجهة: $tripLabel\n'
                'متبقٍ $minutesLeft دقيقة لتأمين الرحلة.',
          ),
        );
      default:
        return (
          title: _t(
            'HeyCaby - We zijn ermee bezig',
            'HeyCaby - We are on it for you',
            'HeyCaby - نحن نتابع لأجلك',
          ),
          body: _t(
            'Bedankt voor het wachten - we zoeken nog naar chauffeurs in de buurt.\n'
                'Rit: $tripLabel\n'
                'Nog ongeveer $minutesLeft min in deze ronde.',
            'Thanks for waiting - we are still searching nearby drivers.\n'
                'Trip: $tripLabel\n'
                'Roughly $minutesLeft min left in this round.',
            'شكرًا لانتظارك - ما زلنا نبحث عن سائقين قريبين.\n'
                'الرحلة: $tripLabel\n'
                'متبقٍ تقريبًا $minutesLeft دقيقة في هذه الجولة.',
          ),
        );
    }
  }

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
      requestSoundPermission: true,
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
    final current = await _readNotifyPermissionStatus();
    if (current == PermissionStatus.granted ||
        current == PermissionStatus.provisional) {
      return true;
    }
    if (current == PermissionStatus.permanentlyDenied ||
        current == PermissionStatus.restricted) {
      return false;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final requested = await Permission.notification.request();
      return requested.isGranted || requested == PermissionStatus.provisional;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      final after = await _readNotifyPermissionStatus();
      return after == PermissionStatus.granted ||
          after == PermissionStatus.provisional;
    }
    return true;
  }

  static Future<PermissionStatus> _readNotifyPermissionStatus() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final opts = await ios?.checkPermissions();
        if (opts == null) return PermissionStatus.denied;
        if (opts.isEnabled ||
            opts.isProvisionalEnabled ||
            opts.isAlertEnabled ||
            opts.isBadgeEnabled) {
          return PermissionStatus.granted;
        }
      } catch (_) {
        // Fall through to permission_handler as a fallback.
      }
    }
    return Permission.notification.status;
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

    // Rotate copy across rides (stable for a given ride via startedAt).
    final variant = startedAt.millisecondsSinceEpoch ~/ 1000;
    final copy = _buildPersonalizedCopy(
      variant: variant,
      destinationSummary: destinationSummary,
      pickupSummary: pickupSummary,
      minutesLeft: minutesLeft,
    );
    final title = copy.title;
    final body = copy.body;

    final android = AndroidNotificationDetails(
      _channelId,
      _t('Zoeken naar chauffeur', 'Driver search', 'البحث عن سائق'),
      channelDescription:
          _t(
            'Getoond terwijl HeyCaby een chauffeur zoekt nadat je op "Meld mij" tikte.',
            'Shown while HeyCaby looks for a driver after you use Notify me.',
            'يظهر أثناء بحث HeyCaby عن سائق بعد استخدام خيار "أعلمني".',
          ),
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: true,
      autoCancel: false,
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
      showWhen: false,
      onlyAlertOnce: true,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: _t(
          'Tik om HeyCaby te openen',
          'Tap to open HeyCaby',
          'اضغط لفتح HeyCaby',
        ),
      ),
    );

    const darwin = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: true,
      presentSound: true,
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
