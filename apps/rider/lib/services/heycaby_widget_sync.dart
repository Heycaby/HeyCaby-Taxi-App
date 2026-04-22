import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:home_widget/home_widget.dart';

import '../constants/heycaby_widget_config.dart';

/// Bridges ride state → home / lock-screen widgets via [home_widget].
/// iOS: App Group + WidgetKit kinds `WidgetA`–`WidgetD`.
/// Android: same keys in SharedPreferences; refresh via [kHeyCabyAndroidHomeWidgetProvider] when you add the receiver.
class HeycabyWidgetSync {
  HeycabyWidgetSync._();

  static double? _lastPublishedKm;
  static int? _lastPublishedMin;

  static bool get _web => kIsWeb;

  static bool get _nativeMobile =>
      !_web &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  static Future<void> init() async {
    if (_web) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await HomeWidget.setAppGroupId(kHeyCabyIosWidgetAppGroup);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('HeycabyWidgetSync.init: $e');
    }
  }

  static Future<void> _save(String key, String? value) async {
    if (!_nativeMobile) return;
    try {
      await HomeWidget.saveWidgetData<String>(key, value ?? '');
    } catch (e) {
      if (kDebugMode) debugPrint('HeycabyWidgetSync.save $key: $e');
    }
  }

  static const _iosKinds = ['WidgetA', 'WidgetB', 'WidgetC', 'WidgetD'];

  static Future<void> _reloadKinds() async {
    if (!_nativeMobile) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        for (final kind in _iosKinds) {
          await HomeWidget.updateWidget(iOSName: kind, name: kind);
        }
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        await HomeWidget.updateWidget(
          name: 'HeyCabyWidgets',
          qualifiedAndroidName: kHeyCabyAndroidHomeWidgetProvider,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('HeycabyWidgetSync._reloadKinds: $e');
    }
  }

  static Future<void> clearAll() async {
    if (!_nativeMobile) return;
    await _save('widget_a_status', 'inactive');
    await _save('widget_b_status', 'inactive');
    await _save('widget_c_status', 'inactive');
    await _save('widget_d_status', 'inactive');
    await _save('widget_d_total_km', '');
    _lastPublishedKm = null;
    _lastPublishedMin = null;
    await _reloadKinds();
  }

  /// After user dismisses the home “notify me” chip — only clears Widget A when it shows notify state.
  static Future<void> clearNotifyChipWidget() async {
    if (!_nativeMobile) return;
    try {
      final st = await HomeWidget.getWidgetData<String>('widget_a_status');
      if (st != 'notify_background') return;
      await _save('widget_a_status', 'inactive');
      await _reloadKinds();
    } catch (e) {
      if (kDebugMode) debugPrint('HeycabyWidgetSync.clearNotifyChipWidget: $e');
    }
  }

  /// Home-screen “notify me” background search (no active ride request row).
  static Future<void> syncNotifyBackgroundSearch({
    required String pickup,
    required String destination,
    required DateTime startedAt,
  }) async {
    if (!_nativeMobile) return;
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    await _save('widget_b_status', 'inactive');
    await _save('widget_c_status', 'inactive');
    await _save('widget_d_status', 'inactive');
    await _save('widget_a_status', 'notify_background');
    await _save('widget_a_pickup', pickup);
    await _save('widget_a_destination', destination);
    await _save('widget_a_search_elapsed', '$elapsed');
    await _save('widget_a_driver_name', '');
    await _save('widget_a_car', '');
    await _save('widget_a_plate', '');
    await _save('widget_a_rating', '');
    await _save('widget_a_eta_minutes', '');
    await _reloadKinds();
  }

  /// Instant / in-app search (Widgets A + clears D).
  static Future<void> syncInstantSearching({
    required String pickup,
    required int searchElapsedSeconds,
    String status = 'searching',
  }) async {
    if (!_nativeMobile) return;
    await _save('widget_b_status', 'inactive');
    await _save('widget_c_status', 'inactive');
    await _save('widget_d_status', 'inactive');
    await _save('widget_a_status', status);
    await _save('widget_a_pickup', pickup);
    await _save('widget_a_search_elapsed', '$searchElapsedSeconds');
    await _save('widget_a_driver_name', '');
    await _save('widget_a_car', '');
    await _save('widget_a_plate', '');
    await _save('widget_a_rating', '');
    await _save('widget_a_eta_minutes', '');
    await _reloadKinds();
  }

  static Future<void> refreshInstantDriverFromRide({
    required String rideId,
    required String pickup,
  }) async {
    if (!_nativeMobile) return;
    try {
      final row = await HeyCabySupabase.client
          .from('ride_requests')
          .select('driver_id, status')
          .eq('id', rideId)
          .maybeSingle();
      final driverId = row?['driver_id'] as String?;
      final st = row?['status'] as String? ?? '';
      if (driverId == null ||
          (st != 'assigned' &&
              st != 'accepted' &&
              st != 'driver_arrived' &&
              st != 'arrived')) {
        return;
      }
      final d = await HeyCabySupabase.client
          .from('drivers')
          .select('full_name, vehicle_model, vehicle_make, vehicle_plate')
          .eq('id', driverId)
          .maybeSingle();
      if (d == null) return;
      final trust = await HeyCabySupabase.client
          .from('driver_trust_scores')
          .select('score')
          .eq('driver_id', driverId)
          .maybeSingle();
      final name = d['full_name'] as String? ?? '';
      final first = name.trim().split(RegExp(r'\s+')).first;
      final car = [
        d['vehicle_make'] as String?,
        d['vehicle_model'] as String?,
      ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
      await _save('widget_a_status', 'driver_found');
      await _save('widget_a_pickup', pickup);
      await _save('widget_a_driver_name', first);
      await _save('widget_a_car', car);
      await _save('widget_a_plate', d['vehicle_plate'] as String? ?? '');
      final score = trust?['score'];
      await _save('widget_a_rating', score != null ? '$score' : '');
      await _save('widget_a_eta_minutes', '');
      await _save('widget_a_search_elapsed', '0');
      await _reloadKinds();
    } catch (e) {
      if (kDebugMode) debugPrint('HeycabyWidgetSync.refreshInstantDriver: $e');
    }
  }

  static Future<void> syncScheduledRide({
    required String origin,
    required String destination,
    required int departureEpochSec,
    String status = 'scheduled',
    String? driverName,
    String? car,
    String? plate,
    String? rating,
  }) async {
    if (!_nativeMobile) return;
    await _save('widget_a_status', 'inactive');
    await _save('widget_d_status', 'inactive');
    await _save('widget_b_status', status);
    await _save('widget_b_origin', origin);
    await _save('widget_b_destination', destination);
    await _save('widget_b_departure_epoch', '$departureEpochSec');
    await _save('widget_b_driver_name', driverName ?? '');
    await _save('widget_b_car', car ?? '');
    await _save('widget_b_plate', plate ?? '');
    await _save('widget_b_rating', rating ?? '');
    await _reloadKinds();
  }

  /// Re-read Supabase for scheduled ride; use `driver_assigned` when a driver is set and pickup is within 30 minutes.
  static Future<void> refreshScheduledRideFromRideId(String rideId) async {
    if (!_nativeMobile) return;
    try {
      final row = await HeyCabySupabase.client
          .from('ride_requests')
          .select(
            'driver_id, scheduled_pickup_at, pickup_address, destination_address',
          )
          .eq('id', rideId)
          .maybeSingle();
      if (row == null) return;
      final origin = row['pickup_address'] as String? ?? '';
      final dest = row['destination_address'] as String? ?? '';
      final raw = row['scheduled_pickup_at'];
      final dep = raw == null ? null : DateTime.tryParse(raw.toString());
      if (dep == null) return;
      final depSec = dep.millisecondsSinceEpoch ~/ 1000;
      final driverId = row['driver_id'] as String?;
      final minsToDep = dep.difference(DateTime.now()).inMinutes;
      if (driverId != null && minsToDep <= 30 && minsToDep >= -120) {
        final d = await HeyCabySupabase.client
            .from('drivers')
            .select('full_name, vehicle_model, vehicle_make, vehicle_plate')
            .eq('id', driverId)
            .maybeSingle();
        if (d != null) {
          final trust = await HeyCabySupabase.client
              .from('driver_trust_scores')
              .select('score')
              .eq('driver_id', driverId)
              .maybeSingle();
          final name = d['full_name'] as String? ?? '';
          final first = name.trim().split(RegExp(r'\s+')).first;
          final car = [
            d['vehicle_make'] as String?,
            d['vehicle_model'] as String?,
          ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
          final score = trust?['score'];
          await syncScheduledRide(
            origin: origin,
            destination: dest,
            departureEpochSec: depSec,
            status: 'driver_assigned',
            driverName: first,
            car: car,
            plate: d['vehicle_plate'] as String? ?? '',
            rating: score != null ? '$score' : '',
          );
          return;
        }
      }
      await syncScheduledRide(
        origin: origin,
        destination: dest,
        departureEpochSec: depSec,
        status: 'scheduled',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('HeycabyWidgetSync.refreshScheduledRideFromRideId: $e');
      }
    }
  }

  static Future<void> syncMarketplace({
    required String origin,
    required String destination,
    required int bidCount,
    required String bestPrice,
    required String bestRating,
    required int expiryEpochSec,
    String status = 'waiting',
  }) async {
    if (!_nativeMobile) return;
    await _save('widget_d_status', 'inactive');
    await _save('widget_c_status', status);
    await _save('widget_c_origin', origin);
    await _save('widget_c_destination', destination);
    await _save('widget_c_bid_count', '$bidCount');
    await _save('widget_c_best_price', bestPrice);
    await _save('widget_c_best_rating', bestRating);
    await _save('widget_c_expiry_epoch', '$expiryEpochSec');
    await _reloadKinds();
  }

  static Future<void> ensureOnRideBaselineKm({
    required double pickupLat,
    required double pickupLng,
    required double destLat,
    required double destLng,
  }) async {
    if (!_nativeMobile) return;
    final existing = await HomeWidget.getWidgetData<String>('widget_d_total_km');
    if (existing != null && existing.isNotEmpty) return;
    final km = Geolocator.distanceBetween(
          pickupLat,
          pickupLng,
          destLat,
          destLng,
        ) /
        1000.0;
    await _save('widget_d_total_km', km.toStringAsFixed(2));
  }

  static Future<void> syncOnRideProgress({
    required String destination,
    required String destinationCity,
    required double destLat,
    required double destLng,
    required double driverLat,
    required double driverLng,
  }) async {
    if (!_nativeMobile) return;
    final totalRaw =
        await HomeWidget.getWidgetData<String>('widget_d_total_km');
    var totalKm = double.tryParse(totalRaw ?? '') ?? 0;
    if (totalKm <= 0) {
      totalKm = 1;
    }
    final kmRemaining = Geolocator.distanceBetween(
          driverLat,
          driverLng,
          destLat,
          destLng,
        ) /
        1000.0;
    final progress = (1.0 - (kmRemaining / totalKm)).clamp(0.0, 1.0);
    final pct = (progress * 100).round();
    final minutes = (kmRemaining / 0.35).ceil().clamp(1, 999);
    final now = DateTime.now();
    final eta = now.add(Duration(minutes: minutes));

    if (_lastPublishedMin == minutes &&
        _lastPublishedKm != null &&
        (kmRemaining - _lastPublishedKm!).abs() < 0.1) {
      return;
    }
    _lastPublishedMin = minutes;
    _lastPublishedKm = kmRemaining;

    await _save('widget_a_status', 'inactive');
    await _save('widget_b_status', 'inactive');
    await _save('widget_c_status', 'inactive');
    await _save('widget_d_status', 'in_progress');
    await _save('widget_d_destination', destination);
    await _save('widget_d_destination_city', destinationCity);
    await _save('widget_d_eta_epoch', '${eta.millisecondsSinceEpoch ~/ 1000}');
    await _save('widget_d_minutes_remaining', '$minutes');
    await _save('widget_d_km_remaining', kmRemaining.toStringAsFixed(1));
    await _save('widget_d_progress_pct', '$pct');
    await _reloadKinds();
  }

  static Future<void> clearOnRideBaseline() async {
    await _save('widget_d_total_km', '');
  }
}
