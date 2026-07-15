import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'supabase_client.dart';

class HeyCabyNotificationReadiness {
  const HeyCabyNotificationReadiness({
    required this.authorized,
    required this.alertsEnabled,
    required this.soundsEnabled,
    required this.timeSensitiveEnabled,
    required this.deviceRegistered,
  });

  final bool authorized;
  final bool alertsEnabled;
  final bool soundsEnabled;
  final bool timeSensitiveEnabled;

  /// True when this device's FCM token exists in [push_devices] for the app role.
  final bool deviceRegistered;

  bool get ready =>
      authorized && alertsEnabled && soundsEnabled && deviceRegistered;
}

/// FCM token lifecycle: [push_devices] via RPC only (no Expo).
///
/// Call [bindRiderIdentity] or [bindDriver] once, then [sync] when auth + identity are ready.
class HeyCabyFcmRegistration {
  HeyCabyFcmRegistration._();

  static String? Function()? _riderIdentityId;
  static bool _refreshWired = false;

  /// Rider: returns current `rider_identities.id` when logged in.
  static void bindRiderIdentity(String? Function() resolver) {
    _riderIdentityId = resolver;
  }

  static void bindDriver() {
    _riderIdentityId = null;
  }

  static Future<void> wireTokenRefresh({required String appRole}) async {
    if (_refreshWired) return;
    _refreshWired = true;
    FirebaseMessaging.instance.onTokenRefresh.listen((_) async {
      await sync(appRole: appRole);
    });
  }

  static Future<void> _ensureOsNotificationPermission() async {
    if (Platform.isAndroid) {
      final st = await Permission.notification.status;
      if (!st.isGranted) {
        await Permission.notification.request();
      }
      return;
    }
    if (Platform.isIOS || Platform.isMacOS) {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      // Proxy is disabled in Info.plist — native AppDelegate forwards the token;
      // this nudges iOS to deliver it before we poll in [_resolveFcmToken].
      await FirebaseMessaging.instance.getAPNSToken();
    }
  }

  /// iOS/macOS: FCM requires an APNs device token first (Firebase proxy off).
  static Future<bool> _waitForApnsToken({
    int maxAttempts = 20,
  }) async {
    if (!Platform.isIOS && !Platform.isMacOS) return true;

    for (var i = 0; i < maxAttempts; i++) {
      try {
        final apns = await FirebaseMessaging.instance.getAPNSToken();
        if (apns != null && apns.isNotEmpty) {
          return true;
        }
      } catch (e) {
        if (kDebugMode && i == 0) {
          debugPrint('HeyCabyFcm getAPNSToken: $e');
        }
      }
      final delayMs = i < 5 ? 400 : 800;
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
    return false;
  }

  static Future<String?> _resolveFcmToken() async {
    if (Platform.isIOS || Platform.isMacOS) {
      final apnsReady = await _waitForApnsToken();
      if (!apnsReady) {
        if (kDebugMode) {
          debugPrint(
            'HeyCabyFcm: APNs token not ready (simulator, entitlements, or '
            'notification permission?)',
          );
        }
        return null;
      }
    }

    final attempts = Platform.isIOS ? 8 : 2;
    for (var i = 0; i < attempts; i++) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.length >= 10) {
          return token;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              'HeyCabyFcm getToken attempt ${i + 1}/$attempts failed: $e');
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    return null;
  }

  static Future<String?> _resolveApnsToken() async {
    if (!Platform.isIOS && !Platform.isMacOS) return null;
    final ready = await _waitForApnsToken();
    if (!ready) return null;
    try {
      final token = await FirebaseMessaging.instance.getAPNSToken();
      return token == null || token.isEmpty ? null : token;
    } catch (e) {
      if (kDebugMode) debugPrint('HeyCabyFcm getAPNSToken failed: $e');
      return null;
    }
  }

  /// Reads native notification readiness without changing driver availability.
  /// [appRole] must be `driver` or `rider` — server registration is checked for that role.
  static Future<HeyCabyNotificationReadiness> readiness({
    required String appRole,
  }) async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    final authorized =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    final isApple = Platform.isIOS || Platform.isMacOS;
    final token = await _resolveFcmToken();
    var deviceRegistered = false;
    if (token != null && token.length >= 10) {
      deviceRegistered = await _isDeviceRegisteredOnServer(
        appRole: appRole,
        fcmToken: token,
      );
      if (!deviceRegistered) {
        await sync(appRole: appRole);
        deviceRegistered = await _isDeviceRegisteredOnServer(
          appRole: appRole,
          fcmToken: token,
        );
      }
    }
    return HeyCabyNotificationReadiness(
      authorized: authorized,
      alertsEnabled:
          !isApple || settings.alert == AppleNotificationSetting.enabled,
      soundsEnabled:
          !isApple || settings.sound == AppleNotificationSetting.enabled,
      timeSensitiveEnabled: !isApple ||
          settings.timeSensitive == AppleNotificationSetting.enabled,
      deviceRegistered: deviceRegistered,
    );
  }

  static Future<bool> _isDeviceRegisteredOnServer({
    required String appRole,
    required String fcmToken,
  }) async {
    try {
      if (HeyCabySupabase.client.auth.currentUser?.id == null) return false;
      final res = await HeyCabySupabase.client.rpc(
        'fn_is_push_device_registered',
        params: {
          'p_app_role': appRole,
          'p_fcm_token': fcmToken,
        },
      );
      if (res is Map) {
        return res['registered'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openNotificationSettings() => openAppSettings();

  /// Registers or updates the device FCM token for the signed-in user.
  /// Returns true when the server acknowledged registration.
  static Future<bool> sync({required String appRole}) async {
    try {
      final uid = HeyCabySupabase.client.auth.currentUser?.id;
      if (uid == null) return false;

      await _ensureOsNotificationPermission();

      final token = await _resolveFcmToken();
      if (token == null || token.length < 10) {
        if (kDebugMode) {
          debugPrint(
              'HeyCabyFcm: no FCM token (permission/APNs/Firebase config?)');
        }
        return false;
      }

      final apnsToken = await _resolveApnsToken();
      // Debug is unambiguously APNs sandbox. Release/profile may be signed
      // with either development provisioning (local device) or production
      // provisioning (TestFlight/App Store), so the backend resolves it from
      // Apple's response instead of trusting Flutter build mode.
      final apnsEnvironment =
          (Platform.isIOS || Platform.isMacOS) && kDebugMode ? 'sandbox' : null;

      final deviceParams = <String, dynamic>{
        'p_fcm_token': token,
        'p_platform': Platform.isIOS ? 'ios' : 'android',
        'p_apns_token': apnsToken,
        'p_apns_environment': apnsEnvironment,
      };

      if (appRole == 'rider') {
        final rid = _riderIdentityId?.call();
        if (rid == null || rid.isEmpty) return false;
        final res = await HeyCabySupabase.client.rpc(
          'fn_register_push_device',
          params: {
            ...deviceParams,
            'p_app_role': 'rider',
            'p_rider_identity_id': rid,
          },
        );
        if (res is Map && res['success'] == true) return true;
        if (kDebugMode && res is Map) {
          debugPrint('HeyCabyFcm register: $res');
        }
        return false;
      }

      if (appRole == 'driver') {
        final res = await HeyCabySupabase.client.rpc(
          'fn_register_push_device',
          params: {
            ...deviceParams,
            'p_app_role': 'driver',
          },
        );
        if (res is Map && res['success'] == true) return true;
        if (kDebugMode && res is Map) {
          debugPrint('HeyCabyFcm register: $res');
        }
        return false;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('HeyCabyFcm sync failed: $e');
      }
      return false;
    }
  }

  /// Clears server rows for this auth user for [appRole] and deletes the local FCM token.
  static Future<void> unregisterAll({required String appRole}) async {
    try {
      await HeyCabySupabase.client.rpc(
        'fn_unregister_all_my_push_devices',
        params: {'p_app_role': appRole},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('HeyCabyFcm unregister RPC: $e');
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      if (kDebugMode) debugPrint('HeyCabyFcm deleteToken: $e');
    }
  }
}
