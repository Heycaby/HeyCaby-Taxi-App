import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_connectivity_provider.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_location_provider.dart';
import '../providers/driver_resync_generation_provider.dart';
import '../router.dart';
import '../services/driver_connectivity_status.dart';
import '../services/driver_operational_restore_service.dart';
import '../services/driver_offline_action_queue.dart';

/// Reconnect: resync providers, realtime, operational state (Program 3E).
class DriverResilienceListener extends ConsumerStatefulWidget {
  const DriverResilienceListener({super.key});

  @override
  ConsumerState<DriverResilienceListener> createState() =>
      _DriverResilienceListenerState();
}

class _DriverResilienceListenerState
    extends ConsumerState<DriverResilienceListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(driverConnectivityProvider.notifier).refresh());
    }
  }

  Future<void> _onReconnect() async {
    final queued = DriverOfflineActionQueue.instance.pendingCount;
    ref.read(driverResyncGenerationProvider.notifier).bump();
    ref.invalidate(driverProfileProvider);
    ref.invalidate(driverComplianceProvider);
    ref.invalidate(driverShiftStatsProvider);
    ref.invalidate(driverEarningsProvider);
    ref.invalidate(driverLocationProvider);

    if (HeyCabySupabase.client.auth.currentUser != null) {
      await restoreDriverOperationalState(ref, appRouter);
    }

    await DriverOfflineActionQueue.instance.flush();

    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          queued > 0
              ? DriverStrings.connectivityBackOnlineWithQueue(queued)
              : DriverStrings.connectivityBackOnline,
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DriverConnectivityStatus>(driverConnectivityProvider,
        (previous, next) {
      final wasOffline = previous == DriverConnectivityStatus.offline;
      if (wasOffline && next == DriverConnectivityStatus.online) {
        unawaited(_onReconnect());
      }
    });

    return const SizedBox.shrink();
  }
}
