import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Android notification channels for Program 3C (ping vs chat vs ride).
class RiderNotificationChannels {
  RiderNotificationChannels._();

  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized || kIsWeb || !Platform.isAndroid) return;

    final plugin = FlutterLocalNotificationsPlugin();
    const channels = [
      AndroidNotificationChannel(
        'heycaby_ping_urgent',
        'Driver ping (urgent)',
        description: 'Driver is outside or needs your attention',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
      AndroidNotificationChannel(
        'heycaby_ping_standard',
        'Driver ping',
        description: 'Driver status updates (on the way, delay)',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
      AndroidNotificationChannel(
        'heycaby_ping_soft',
        'Driver message',
        description: 'Light driver updates',
        importance: Importance.defaultImportance,
        playSound: true,
      ),
      AndroidNotificationChannel(
        'heycaby_ride_events',
        'Ride updates',
        importance: Importance.high,
        playSound: true,
      ),
      AndroidNotificationChannel(
        'heycaby_chat',
        'Chat messages',
        importance: Importance.defaultImportance,
        playSound: true,
      ),
    ];

    final android =
        plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      for (final ch in channels) {
        await android.createNotificationChannel(ch);
      }
    }
    _initialized = true;
  }
}
