import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/driver_runtime_models.dart';
import '../providers/driver_runtime_providers.dart';

/// Client-side contract version — must stay aligned with Supabase `runtime_version`.
const kDriverRuntimeContractVersion = 3;

/// Invalidate cached runtime and refetch via [driverRuntimeSnapshotProvider].
void invalidateDriverRuntime(WidgetRef ref) {
  ref.read(driverRuntimeServiceProvider).invalidateCache();
  ref.invalidate(driverRuntimeSnapshotProvider);
}

/// Mutation → refresh runtime → render.
Future<DriverRuntimeSnapshot> refreshDriverRuntime(WidgetRef ref) async {
  invalidateDriverRuntime(ref);
  return ref
      .read(driverRuntimeServiceProvider)
      .fetchRuntime(cacheFor: Duration.zero);
}
