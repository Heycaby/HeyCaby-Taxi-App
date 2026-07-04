import 'package:flutter/foundation.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../models/driver_runtime_models.dart';
import '../utils/driver_runtime_refresh.dart';

/// Supabase-first driver runtime — single RPC for config + readiness + health.
class DriverRuntimeService {
  DriverRuntimeSnapshot? _cachedRuntime;
  DateTime? _cachedAt;

  Future<DriverRuntimeSnapshot> fetchRuntime(
      {Duration cacheFor = const Duration(seconds: 20)}) async {
    if (_cachedRuntime != null && _cachedAt != null) {
      if (DateTime.now().difference(_cachedAt!) < cacheFor) {
        return _cachedRuntime!;
      }
    }

    try {
      final raw = await HeyCabySupabase.client.rpc('fn_driver_runtime');
      final snapshot = DriverRuntimeSnapshot.fromRpc(raw);
      if (snapshot.ok) {
        if (snapshot.runtimeVersion > 0 &&
            snapshot.runtimeVersion != kDriverRuntimeContractVersion &&
            kDebugMode) {
          debugPrint(
            'fn_driver_runtime version mismatch: server=${snapshot.runtimeVersion} '
            'client=$kDriverRuntimeContractVersion',
          );
        }
        appPublicLinks.apply(snapshot.config.links);
        _cachedRuntime = snapshot;
        _cachedAt = DateTime.now();
      }
      return snapshot;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('fn_driver_runtime failed: $e\n$st');
      }
      return DriverRuntimeSnapshot(
        ok: false,
        canGoOnline: false,
        readiness:
            const DriverReadinessState(canGoOnline: false, checklist: []),
        config: DriverRemoteConfig.fromJson(const {}),
        error: e.toString(),
      );
    }
  }

  void invalidateCache() {
    _cachedRuntime = null;
    _cachedAt = null;
  }

  Future<DriverRemoteConfig> fetchRemoteConfig() async {
    final runtime = await fetchRuntime();
    return runtime.config;
  }

  Future<DriverReadinessState> fetchReadiness() async {
    final runtime = await fetchRuntime();
    return runtime.readiness;
  }

  Future<DriverStatusDecision> setStatusV1({
    required String status,
    double? lat,
    double? lng,
  }) async {
    if (status == 'available' && (lat == null || lng == null)) {
      return const DriverStatusDecision(
        status: 'offline',
        blockedReason: 'location_required',
        message: 'Turn on location before going online.',
      );
    }
    try {
      final raw = await HeyCabySupabase.client.rpc(
        'fn_driver_set_status',
        params: {
          'p_status': status,
          if (lat != null) 'p_lat': lat,
          if (lng != null) 'p_lng': lng,
        },
      );
      invalidateCache();
      if (raw is! Map) {
        return const DriverStatusDecision(
            status: 'offline', message: 'Invalid status response');
      }
      final json = Map<String, dynamic>.from(raw);
      return DriverStatusDecision.fromJson(json);
    } catch (e) {
      if (kDebugMode) debugPrint('fn_driver_set_status failed: $e');
      return DriverStatusDecision(
        status: 'offline',
        message: e.toString(),
      );
    }
  }
}
