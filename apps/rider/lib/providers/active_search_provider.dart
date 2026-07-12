import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/rider_search_window.dart';
import '../services/heycaby_widget_sync.dart';
import '../services/sound_service.dart';
import '../services/stale_ride_cleanup.dart';
import 'near_term_ride_request_provider.dart';
import 'ride_request_provider.dart';

const _kPrefsKey = 'heycaby_active_notify_search';
const _kModalDismissedKey = 'heycaby_no_caby_growth_modal_dismissed';

/// Persisted "notify me" background search chip on home (survives rebuilds / cold start).
class ActiveNotifySearch {
  final DateTime startedAt;
  final String? rideRequestId;
  final String bookingMode;
  final String? pickupSummary;
  final String? destinationSummary;

  const ActiveNotifySearch({
    required this.startedAt,
    this.rideRequestId,
    this.bookingMode = 'instant',
    this.pickupSummary,
    this.destinationSummary,
  });

  Map<String, dynamic> toJson() => {
        'startedAt': startedAt.toIso8601String(),
        if (rideRequestId != null) 'rideRequestId': rideRequestId,
        'bookingMode': bookingMode,
        if (pickupSummary != null && pickupSummary!.isNotEmpty)
          'pickupSummary': pickupSummary,
        if (destinationSummary != null && destinationSummary!.isNotEmpty)
          'destinationSummary': destinationSummary,
      };

  factory ActiveNotifySearch.fromJson(Map<String, dynamic> json) {
    return ActiveNotifySearch(
      startedAt: DateTime.parse(json['startedAt'] as String),
      rideRequestId: json['rideRequestId'] as String?,
      bookingMode: (json['bookingMode'] as String?) ?? 'instant',
      pickupSummary: json['pickupSummary'] as String?,
      destinationSummary: json['destinationSummary'] as String?,
    );
  }
}

class ActiveSearchNotifier extends AsyncNotifier<ActiveNotifySearch?> {
  @override
  Future<ActiveNotifySearch?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final s = ActiveNotifySearch.fromJson(map);
      final age = DateTime.now().difference(s.startedAt);
      if (age > kRiderDriverSearchWindow) {
        await prefs.remove(_kPrefsKey);
        return null;
      }
      return s;
    } catch (_) {
      await prefs.remove(_kPrefsKey);
      return null;
    }
  }

  Future<void> start({
    String? rideRequestId,
    required String bookingMode,
    String? pickupSummary,
    String? destinationSummary,
  }) async {
    final s = ActiveNotifySearch(
      startedAt: DateTime.now(),
      rideRequestId: rideRequestId,
      bookingMode: bookingMode,
      pickupSummary: pickupSummary,
      destinationSummary: destinationSummary,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, jsonEncode(s.toJson()));
    state = AsyncData(s);
    await HeycabyWidgetSync.syncNotifyBackgroundSearch(
      pickup: pickupSummary ?? '',
      destination: destinationSummary ?? '',
      startedAt: s.startedAt,
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefsKey);
    state = const AsyncData(null);
    await HeycabyWidgetSync.clearNotifyChipWidget();
  }

  /// Clears the chip and cancels the associated open `ride_request` (if known).
  ///
  /// Cancels on the server and refreshes [nearTermRideRequestProvider] before
  /// clearing prefs so the home sheet does not briefly show the near-term ride
  /// banner for the same ride (stale cache) right after the notify card disappears.
  Future<bool> stopSearchAndCancelRide() async {
    final current = state.valueOrNull;
    final id = current?.rideRequestId;
    var cancelled = id == null;
    try {
      if (id != null) {
        final identity = await ref.read(riderIdentityProvider.future);
        final token = identity.riderToken;
        if (token != null) {
          cancelled = await cancelExpiredRiderOpenRide(
            rideId: id,
            riderToken: token,
            cancellationReason: 'rider_stopped_background_search',
          );
        }
      }
    } catch (_) {}
    if (!cancelled) return false;
    await SoundService().playRideCancelled();
    ref.read(rideRequestProvider.notifier).reset();
    ref.invalidate(nearTermRideRequestProvider);
    try {
      await ref.read(nearTermRideRequestProvider.future);
    } catch (_) {}
    await clear();
    ref.invalidate(ridesTabUpcomingRequestsProvider);
    return true;
  }

  Future<void> expireIfStale() async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (DateTime.now().difference(current.startedAt) >
        kRiderDriverSearchWindow) {
      await clear();
    }
  }

  Future<bool> isGrowthModalDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kModalDismissedKey) ?? false;
  }

  Future<void> markGrowthModalDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kModalDismissedKey, true);
  }
}

final activeSearchProvider =
    AsyncNotifierProvider<ActiveSearchNotifier, ActiveNotifySearch?>(
  ActiveSearchNotifier.new,
);
