import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/driver_data_providers.dart';
import '../providers/driver_earnings_targets_notifier.dart';
import '../providers/driver_resync_generation_provider.dart';

/// Refreshes hub goal state when [driver_earnings_targets] changes in Supabase.
class DriverHubGoalsRealtimeListener extends ConsumerStatefulWidget {
  const DriverHubGoalsRealtimeListener({super.key});

  @override
  ConsumerState<DriverHubGoalsRealtimeListener> createState() =>
      _DriverHubGoalsRealtimeListenerState();
}

class _DriverHubGoalsRealtimeListenerState
    extends ConsumerState<DriverHubGoalsRealtimeListener> {
  RealtimeChannel? _channel;
  String? _boundDriverId;
  int? _resyncGen;

  void _applyResync(int gen) {
    if (_resyncGen == gen) return;
    _resyncGen = gen;
    _channel?.unsubscribe();
    _channel = null;
    _boundDriverId = null;
  }

  void _bind(String? id) {
    if (id == null || id.isEmpty) {
      _channel?.unsubscribe();
      _channel = null;
      _boundDriverId = null;
      return;
    }
    if (id == _boundDriverId && _channel != null) return;

    _channel?.unsubscribe();
    _boundDriverId = id;
    _channel = HeyCabySupabase.client
        .channel('driver-earnings-targets-$id')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'driver_earnings_targets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: id,
          ),
          callback: (_) {
            unawaited(
              ref.read(driverEarningsTargetsProvider.notifier).reloadFromServer(),
            );
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _applyResync(ref.watch(driverResyncGenerationProvider));
    ref.listen(driverIdProvider, (prev, next) {
      next.whenData(_bind);
    });
    ref.watch(driverIdProvider).whenData(_bind);
    return const SizedBox.shrink();
  }
}
