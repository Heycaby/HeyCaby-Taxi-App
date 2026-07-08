import 'package:flutter/foundation.dart';
import 'package:heycaby_api/heycaby_api.dart';

/// Live SDA wave status for the rider searching screen.
class RiderDispatchStatus {
  const RiderDispatchStatus({
    required this.ok,
    this.state = 'starting',
    this.wave = 0,
    this.waveOuterKm = 5,
    this.driversNotified = 0,
    this.driversPending = 0,
    this.closestKm,
    this.fastestEtaMin,
    this.waveTimeoutSeconds = 10,
    this.waveElapsedSeconds = 0,
    this.progress = 0.1,
    this.favoriteDriverName,
    this.surge = false,
    this.night = false,
    this.collapsedWaves = false,
  });

  final bool ok;
  final String state;
  final int wave;
  final double waveOuterKm;
  final int driversNotified;
  final int driversPending;
  final double? closestKm;
  final double? fastestEtaMin;
  final int waveTimeoutSeconds;
  final int waveElapsedSeconds;
  final double progress;
  final String? favoriteDriverName;
  final bool surge;
  final bool night;
  final bool collapsedWaves;

  bool get isNoDrivers => state == 'no_drivers';
  bool get isMatched => state == 'matched';
  bool get isWaveActive => state == 'wave_active';

  factory RiderDispatchStatus.fromJson(Map<String, dynamic> json) {
    return RiderDispatchStatus(
      ok: json['ok'] == true,
      state: json['state']?.toString() ?? 'starting',
      wave: (json['wave'] as num?)?.toInt() ?? 0,
      waveOuterKm: (json['wave_outer_km'] as num?)?.toDouble() ?? 5,
      driversNotified: (json['drivers_notified'] as num?)?.toInt() ?? 0,
      driversPending: (json['drivers_pending'] as num?)?.toInt() ?? 0,
      closestKm: (json['closest_km'] as num?)?.toDouble(),
      fastestEtaMin: (json['fastest_eta_min'] as num?)?.toDouble(),
      waveTimeoutSeconds: (json['wave_timeout_seconds'] as num?)?.toInt() ?? 10,
      waveElapsedSeconds: (json['wave_elapsed_seconds'] as num?)?.toInt() ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.1,
      favoriteDriverName: json['favorite_driver_name']?.toString(),
      surge: json['surge'] == true,
      night: json['night'] == true,
      collapsedWaves: json['collapsed_waves'] == true,
    );
  }

  static const RiderDispatchStatus empty =
      RiderDispatchStatus(ok: false, state: 'starting');
}

class RiderDispatchStatusService {
  RiderDispatchStatusService._();

  static Future<RiderDispatchStatus> fetch(String rideRequestId) async {
    try {
      final raw = await HeyCabySupabase.client.rpc(
        'fn_rider_dispatch_status',
        params: {'p_ride_request_id': rideRequestId},
      );
      if (raw is! Map) return RiderDispatchStatus.empty;
      return RiderDispatchStatus.fromJson(Map<String, dynamic>.from(raw));
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('RiderDispatchStatusService.fetch failed: $e\n$st');
      }
      return RiderDispatchStatus.empty;
    }
  }
}
