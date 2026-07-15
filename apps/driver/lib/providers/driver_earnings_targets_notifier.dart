import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'driver_data_providers.dart';

/// Live earnings goals (daily/weekly/biweekly/monthly) with optimistic updates.
class DriverEarningsTargetsNotifier extends AsyncNotifier<Map<String, double>> {
  @override
  Future<Map<String, double>> build() async {
    final id = await ref.watch(driverIdProvider.future);
    if (id == null) return {};
    return ref.read(driverDataServiceProvider).getEarningsTargets(id);
  }

  Future<void> reloadFromServer() async {
    final id = await ref.read(driverIdProvider.future);
    if (id == null) {
      state = const AsyncData({});
      return;
    }
    try {
      final map = await ref.read(driverDataServiceProvider).getEarningsTargets(id);
      state = AsyncData(map);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<bool> saveTarget(String period, double amount) async {
    if (amount <= 0) return false;
    final id = await ref.read(driverIdProvider.future);
    if (id == null) return false;

    final previous = state.valueOrNull ?? {};
    state = AsyncData({...previous, period: amount});
    try {
      await ref
          .read(driverDataServiceProvider)
          .upsertEarningsTarget(id, period, amount);
      return true;
    } catch (_) {
      state = AsyncData(previous);
      return false;
    }
  }

  Future<bool> removeTarget(String period) async {
    final id = await ref.read(driverIdProvider.future);
    if (id == null) return false;

    final previous = state.valueOrNull ?? {};
    final next = Map<String, double>.from(previous)..remove(period);
    state = AsyncData(next);
    try {
      await ref
          .read(driverDataServiceProvider)
          .deleteEarningsTarget(id, period);
      return true;
    } catch (_) {
      state = AsyncData(previous);
      return false;
    }
  }
}

final driverEarningsTargetsProvider =
    AsyncNotifierProvider<DriverEarningsTargetsNotifier, Map<String, double>>(
  DriverEarningsTargetsNotifier.new,
);
