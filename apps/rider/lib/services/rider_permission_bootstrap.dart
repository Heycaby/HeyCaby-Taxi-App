import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/settings_provider.dart';
import 'rider_device_permission_snapshot.dart';
import 'rider_permission_backend_sync.dart';

/// Requests notification permission early and syncs OS permission truth to prefs + backend.
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

    final n = await Permission.notification.status;
    if (n == PermissionStatus.denied) {
      await Permission.notification.request();
    }

    final snap = await RiderDevicePermissionSnapshot.read();
    if (!mounted) return;
    await ref.read(settingsProvider.notifier).syncDevicePermissions(
          locationGranted: snap.locationGranted,
          notificationsGranted: snap.notificationsGranted,
        );
    await RiderPermissionBackendSync.push(
      locationGranted: snap.locationGranted,
      notificationsGranted: snap.notificationsGranted,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
