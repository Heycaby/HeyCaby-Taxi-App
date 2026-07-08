import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_utils/heycaby_utils.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'screens/ios_update_required_app.dart';
import 'services/heycaby_widget_sync.dart';
import 'services/rider_notify_live_activity.dart';
import 'services/rider_notification_channels.dart';
import 'services/rider_notify_search_notifications.dart';
import 'services/rider_permission_bootstrap.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final iosTooOld = await checkIosBelowMinimum();
  if (iosTooOld != null) {
    runApp(RiderIosUpdateRequiredApp(systemVersion: iosTooOld.systemVersion));
    return;
  }

  await HeycabyWidgetSync.init();
  await RiderNotifyLiveActivity.init();
  await RiderNotifySearchNotifications.pluginInitialize();
  await RiderNotificationChannels.ensureInitialized();

  const mapboxToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
  if (mapboxToken.isNotEmpty) {
    MapboxOptions.setAccessToken(mapboxToken);
  }

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e, st) {
    debugPrint('Firebase init failed (add firebase_options / GoogleService files): $e $st');
  }

  await HeyCabySupabase.initialize();

  // Ensure an anonymous auth session so realtime subscriptions and
  // RLS-protected queries work for guest riders who haven't signed in.
  try {
    if (HeyCabySupabase.client.auth.currentSession == null) {
      await HeyCabySupabase.client.auth.signInAnonymously();
    }
  } catch (e) {
    debugPrint('Anonymous sign-in failed: $e');
  }

  runApp(
    const ProviderScope(
      child: RiderPermissionBootstrap(
        child: HeyCabyRiderApp(),
      ),
    ),
  );
}
