import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/driver_data_providers.dart';
import '../providers/driver_resync_generation_provider.dart';

/// Listens for `drivers` row updates for the signed-in driver and refreshes profile/compliance.
/// Used when admin approves documents in Supabase (no app restart).
class DriverProfileRealtimeListener extends ConsumerStatefulWidget {
  const DriverProfileRealtimeListener({super.key});

  @override
  ConsumerState<DriverProfileRealtimeListener> createState() =>
      _DriverProfileRealtimeListenerState();
}

class _DriverProfileRealtimeListenerState extends ConsumerState<DriverProfileRealtimeListener> {
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
        .channel('drivers-profile-$id')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'drivers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: id,
          ),
          callback: (_) {
            ref.invalidate(driverProfileProvider);
            ref.invalidate(driverComplianceProvider);
            // Pickup radius + mirrored return discount sync on drivers; rate rows still from profiles.
            ref.invalidate(driverRateProfilesProvider);
            ref.invalidate(activeRateProfileProvider);
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
