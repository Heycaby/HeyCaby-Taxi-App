import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/driver_runtime_models.dart';
import '../services/driver_runtime_service.dart';

final driverRuntimeServiceProvider =
    Provider<DriverRuntimeService>((_) => DriverRuntimeService());

final driverRuntimeSnapshotProvider = FutureProvider<DriverRuntimeSnapshot>((ref) async {
  return ref.read(driverRuntimeServiceProvider).fetchRuntime();
});

final driverRemoteConfigProvider = FutureProvider<DriverRemoteConfig>((ref) async {
  final runtime = await ref.watch(driverRuntimeSnapshotProvider.future);
  return runtime.config;
});

final driverReadinessProvider = FutureProvider<DriverReadinessState?>((ref) async {
  final runtime = await ref.watch(driverRuntimeSnapshotProvider.future);
  if (!runtime.ok) return null;
  return runtime.readiness;
});
