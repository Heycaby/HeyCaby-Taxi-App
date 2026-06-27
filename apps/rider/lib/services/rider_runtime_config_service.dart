import 'package:heycaby_api/heycaby_api.dart';

class RiderRuntimeTuning {
  const RiderRuntimeTuning({
    required this.searchWindowMinutes,
    required this.noDriverDelaySeconds,
    required this.nearTermWindowHours,
    required this.maxSearchRadiusKm,
    required this.driverLocationMaxAgeMinutes,
  });

  final int searchWindowMinutes;
  final int noDriverDelaySeconds;
  final int nearTermWindowHours;
  final double maxSearchRadiusKm;
  final int driverLocationMaxAgeMinutes;

  static const fallback = RiderRuntimeTuning(
    searchWindowMinutes: 10,
    noDriverDelaySeconds: 5,
    nearTermWindowHours: 48,
    maxSearchRadiusKm: 12,
    driverLocationMaxAgeMinutes: 3,
  );

  factory RiderRuntimeTuning.fromJson(Map<String, dynamic> json) {
    final search = (json['search'] as Map?)?.cast<String, dynamic>() ?? const {};
    return RiderRuntimeTuning(
      searchWindowMinutes: (search['driver_search_window_minutes'] as num?)?.toInt() ??
          (json['search_window_minutes'] as num?)?.toInt() ??
          fallback.searchWindowMinutes,
      noDriverDelaySeconds: (search['no_driver_card_delay_seconds'] as num?)?.toInt() ??
          (json['no_driver_delay_seconds'] as num?)?.toInt() ??
          fallback.noDriverDelaySeconds,
      nearTermWindowHours: (search['near_term_scheduled_window_hours'] as num?)?.toInt() ??
          fallback.nearTermWindowHours,
      maxSearchRadiusKm: (search['max_search_radius_km'] as num?)?.toDouble() ??
          (json['search_radius_km'] as num?)?.toDouble() ??
          fallback.maxSearchRadiusKm,
      driverLocationMaxAgeMinutes:
          (search['driver_location_max_age_minutes'] as num?)?.toInt() ??
              fallback.driverLocationMaxAgeMinutes,
    );
  }
}

class RiderRuntimeConfigService {
  RiderRuntimeTuning _tuning = RiderRuntimeTuning.fallback;
  DateTime? _lastFetchAt;

  RiderRuntimeTuning get current => _tuning;

  Future<RiderRuntimeTuning> refresh({bool force = false}) async {
    if (!force && _lastFetchAt != null) {
      final age = DateTime.now().difference(_lastFetchAt!);
      if (age < const Duration(minutes: 5)) return _tuning;
    }
    final raw = await HeyCabySupabase.client.rpc('fn_driver_runtime_configuration');
    _tuning = RiderRuntimeTuning.fromJson(
      raw is Map ? Map<String, dynamic>.from(raw) : const {},
    );
    _lastFetchAt = DateTime.now();
    return _tuning;
  }
}

final riderRuntimeConfig = RiderRuntimeConfigService();
