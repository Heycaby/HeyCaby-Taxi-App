import 'package:flutter/foundation.dart';
import 'package:heycaby_api/heycaby_api.dart';

class RiderNotificationLifecycleService {
  const RiderNotificationLifecycleService._();

  static Future<void> trackEvent(
    String eventKey, {
    Map<String, dynamic>? payload,
    String? riderIdentityId,
  }) async {
    try {
      await HeyCabySupabase.client.rpc(
        'fn_track_rider_lifecycle_event',
        params: <String, dynamic>{
          'p_event_key': eventKey,
          'p_event_payload': payload ?? <String, dynamic>{},
          'p_rider_identity_id': riderIdentityId,
        },
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Rider lifecycle event failed ($eventKey): $error');
      }
    }
  }
}
