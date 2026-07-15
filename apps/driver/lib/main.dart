import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_utils/heycaby_utils.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'screens/driver_ios_update_required_app.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // The provider notification itself owns background/lock-screen display.
  // Normal taxi offers must not be converted to CallKit or VoIP calls.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final iosTooOld = await checkIosBelowMinimum();
  if (iosTooOld != null) {
    runApp(DriverIosUpdateRequiredApp(systemVersion: iosTooOld.systemVersion));
    return;
  }

  // Only set when Dart compile-time define is non-empty. Calling
  // setAccessToken('') overwrites the native default and clears MBXAccessToken
  // from Info.plist (Secrets.xcconfig), which breaks the map if defines are
  // missing while the plist token is valid.
  const mapboxToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
  if (mapboxToken.isNotEmpty) {
    MapboxOptions.setAccessToken(mapboxToken);
  }

  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e, st) {
    debugPrint(
        'Firebase init failed (add firebase_options / GoogleService files): $e $st');
  }

  await HeyCabySupabase.initialize();

  runApp(
    ProviderScope(
      overrides: [
        themeProvider.overrideWith(DriverThemeNotifier.new),
      ],
      child: const HeyCabyDriverApp(),
    ),
  );
}
