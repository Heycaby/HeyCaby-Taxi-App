import 'package:firebase_messaging/firebase_messaging.dart';

/// Parsed FCM data payload for driver push categories (Program 3C).
class DriverFcmPayload {
  const DriverFcmPayload({
    this.category,
    this.rideRequestId,
    this.screen,
    this.notificationId,
  });

  final String? category;
  final String? rideRequestId;
  final String? screen;
  final String? notificationId;

  factory DriverFcmPayload.fromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final title = message.notification?.title ?? '';
    return DriverFcmPayload.fromData(
      data,
      notificationTitle: title,
    );
  }

  factory DriverFcmPayload.fromData(
    Map<String, dynamic> data, {
    String notificationTitle = '',
  }) {
    final category = (data['category'] as String?)?.trim();
    final rideId = (data['ride_request_id'] as String?)?.trim();
    final screen = (data['screen'] as String?)?.trim();
    final notificationId = (data['notification_id'] as String?)?.trim();

    return DriverFcmPayload(
      category: category?.isNotEmpty == true
          ? category
          : _inferCategory(
              screen: screen,
              title: notificationTitle,
            ),
      rideRequestId: rideId?.isNotEmpty == true ? rideId : null,
      screen: screen?.isNotEmpty == true ? screen : null,
      notificationId: notificationId?.isNotEmpty == true ? notificationId : null,
    );
  }

  static String? _inferCategory({String? screen, required String title}) {
    if (screen == 'incoming') return 'incoming_ride';
    final lower = title.toLowerCase();
    if (lower.contains('cancelled') || lower.contains('geannuleerd')) {
      return 'ride_phase';
    }
    if (title.startsWith('💬')) return 'chat';
    if (lower.contains('rating') || title.startsWith('⭐')) return 'rating';
    return null;
  }

  String? get effectiveCategory => category;
}
