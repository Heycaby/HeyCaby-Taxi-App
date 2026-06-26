import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

import 'rider_notification_lifecycle_service.dart';
import 'rider_device_permission_snapshot.dart';
import 'rider_permission_backend_sync.dart';

/// Syncs OS permission truth to backend for analytics/ops visibility.
class RiderPermissionBootstrap extends ConsumerStatefulWidget {
  const RiderPermissionBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RiderPermissionBootstrap> createState() =>
      _RiderPermissionBootstrapState();
}

class _RiderPermissionBootstrapState
    extends ConsumerState<RiderPermissionBootstrap> {
  bool _ran = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runOnce());
  }

  Future<void> _runOnce() async {
    if (!mounted || _ran) return;
    _ran = true;

    final snap = await RiderDevicePermissionSnapshot.read();
    if (!mounted) return;
    await RiderPermissionBackendSync.push(
      locationGranted: snap.locationGranted,
      notificationsGranted: snap.notificationsGranted,
    );
    final identity = await ref.read(riderIdentityProvider.future);
    if (!mounted) return;
    if (identity.hasSession &&
        identity.identityId != null &&
        identity.identityId!.isNotEmpty) {
      await HeyCabyFcmRegistration.sync(appRole: 'rider');
      await RiderNotificationLifecycleService.trackEvent(
        'app_open',
        riderIdentityId: identity.identityId,
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
