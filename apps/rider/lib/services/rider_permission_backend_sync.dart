import 'package:flutter/foundation.dart';
import 'package:heycaby_api/heycaby_api.dart';

/// Pushes device permission flags to `rider_identities` (best-effort).
class RiderPermissionBackendSync {
  RiderPermissionBackendSync._();

  static Future<void> push({
    required bool locationGranted,
    required bool notificationsGranted,
    String? riderIdentityId,
  }) async {
    try {
      final stored = await SecureStorage.getRiderIdentity();
      final id = riderIdentityId ?? stored['rider_identity_id'];
      if (id == null || id.isEmpty) return;

      await HeyCabySupabase.client.from('rider_identities').update({
        'app_location_permission_granted': locationGranted,
        'app_notification_permission_granted': notificationsGranted,
        'app_permissions_synced_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RiderPermissionBackendSync.push: $e');
      }
    }
  }
}
