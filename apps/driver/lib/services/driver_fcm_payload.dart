import 'package:firebase_messaging/firebase_messaging.dart';

/// Parsed FCM data payload for driver push categories (Program 3C).
class DriverFcmPayload {
  const DriverFcmPayload({
    this.category,
    this.rideRequestId,
    this.rideInviteId,
    this.expiresAt,
    this.screen,
    this.notificationId,
    this.requestId,
    this.title,
    this.body,
    this.rawData,
  });

  final String? category;
  final String? rideRequestId;
  final String? rideInviteId;
  final DateTime? expiresAt;
  final String? screen;
  final String? notificationId;
  final String? requestId;
  final String? title;
  final String? body;
  final Map<String, dynamic>? rawData;

  factory DriverFcmPayload.fromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    return DriverFcmPayload.fromData(
      data,
      notificationTitle: title,
      notificationBody: body,
    );
  }

  factory DriverFcmPayload.fromData(
    Map<String, dynamic> data, {
    String notificationTitle = '',
    String notificationBody = '',
  }) {
    final category = (data['category'] as String?)?.trim();
    final rideId = (data['ride_request_id'] as String?)?.trim();
    final inviteId = (data['ride_invite_id'] as String?)?.trim();
    final expiresAt = DateTime.tryParse(data['expires_at']?.toString() ?? '');
    final screen = (data['screen'] as String?)?.trim();
    final notificationId = (data['notification_id'] as String?)?.trim();
    final requestId = (data['request_id'] as String?)?.trim();

    return DriverFcmPayload(
      category: category?.isNotEmpty == true
          ? category
          : _inferCategory(
              screen: screen,
              title: notificationTitle,
            ),
      rideRequestId: rideId?.isNotEmpty == true ? rideId : null,
      rideInviteId: inviteId?.isNotEmpty == true ? inviteId : null,
      expiresAt: expiresAt?.toUtc(),
      screen: screen?.isNotEmpty == true ? screen : null,
      notificationId:
          notificationId?.isNotEmpty == true ? notificationId : null,
      requestId: requestId?.isNotEmpty == true ? requestId : null,
      title: notificationTitle.isNotEmpty ? notificationTitle : null,
      body: notificationBody.isNotEmpty ? notificationBody : null,
      rawData: data,
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
