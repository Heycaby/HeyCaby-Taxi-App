import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'supabase_client.dart';

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
    }
  }

  static Future<String?> _resolveFcmToken() async {
    final attempts = Platform.isIOS ? 5 : 2;
    for (var i = 0; i < attempts; i++) {
      String? token;
      try {
        token = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('HeyCabyFcm getToken attempt ${i + 1}/$attempts failed: $e');
        }
      }
      if (token != null && token.length >= 10) {
        return token;
      }
      if (Platform.isIOS) {
        try {
          await FirebaseMessaging.instance.getAPNSToken();
        } catch (_) {}
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return null;
  }

  /// Registers or updates the device FCM token for the signed-in user.
  static Future<void> sync({required String appRole}) async {
    try {
      final uid = HeyCabySupabase.client.auth.currentUser?.id;
      if (uid == null) return;

      await _ensureOsNotificationPermission();

      final token = await _resolveFcmToken();
      if (token == null || token.length < 10) {
        if (kDebugMode) {
          debugPrint('HeyCabyFcm: no FCM token (permission/APNs/Firebase config?)');
        }
        return;
      }

      if (appRole == 'rider') {
        final rid = _riderIdentityId?.call();
        if (rid == null || rid.isEmpty) return;
        final res = await HeyCabySupabase.client.rpc(
          'fn_register_push_device',
          params: {
            'p_fcm_token': token,
            'p_platform': Platform.isIOS ? 'ios' : 'android',
            'p_app_role': 'rider',
            'p_rider_identity_id': rid,
          },
        );
        if (kDebugMode && res is Map && res['success'] != true) {
          debugPrint('HeyCabyFcm register: $res');
        }
        return;
      }

      if (appRole == 'driver') {
        final res = await HeyCabySupabase.client.rpc(
          'fn_register_push_device',
          params: {
            'p_fcm_token': token,
            'p_platform': Platform.isIOS ? 'ios' : 'android',
            'p_app_role': 'driver',
          },
        );
        if (kDebugMode && res is Map && res['success'] != true) {
          debugPrint('HeyCabyFcm register: $res');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('HeyCabyFcm sync failed: $e');
      }
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
