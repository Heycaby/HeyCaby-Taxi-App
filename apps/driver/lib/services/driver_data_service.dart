import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode;
import 'dart:io' show TlsException;

import 'package:flutter/foundation.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions, FunctionException;

/// Thrown when profile photo upload fails due to TLS/network (e.g. SSLV3_ALERT_BAD_RECORD_MAC).
/// UI should show a connection-specific message; this is not a code or backend bug.
class ProfilePhotoConnectionException implements Exception {
  const ProfilePhotoConnectionException();
}

/// Error code returned in `save_vehicle_info` RPC map when kenteken is taken ([DriverDataService]).
const String kVehiclePlateDuplicateCode = 'duplicate_vehicle_plate';

bool _isVehiclePlateUniqueViolation(Object? error) {
  final s = error?.toString() ?? '';
  return s.contains('drivers_vehicle_plate_unique') ||
      s.contains('vehicle_plate_unique') ||
      (s.contains('23505') && s.contains('duplicate'));
}

Map<String, dynamic> _normalizeSaveVehicleInfoResponse(Map<String, dynamic> m) {
  final err = m['error'] ?? m['message'];
  if (err != null && _isVehiclePlateUniqueViolation(err)) {
    return {
      ...m,
      'error': kVehiclePlateDuplicateCode,
    };
  }
  return m;
}

/// Returned by [DriverDataService.startVeriffVerificationAndPersist]; open [url] in the system browser.
@immutable
class VeriffSessionResult {
  const VeriffSessionResult({
    required this.url,
    this.sessionId,
  });

  final String url;
  final String? sessionId;
}

/// Response from Edge Function `claim-founding-driver` (after first app login).
@immutable
class ClaimFoundingDriverResult {
  const ClaimFoundingDriverResult({
    required this.isFoundingDriver,
    this.foundingNumber,
    this.needsProfilePhoto = false,
    this.needsVehiclePhoto = false,
  });

  final bool isFoundingDriver;
  final int? foundingNumber;
  final bool needsProfilePhoto;
  final bool needsVehiclePhoto;
}

/// Result of Edge Function `driver-support-chat` (Lee / AI driver support).
@immutable
class DriverSupportChatResult {
  const DriverSupportChatResult({
    required this.ok,
    this.reply,
    this.error,
    this.ticketId,
  });

  final bool ok;
  final String? reply;
  final String? error;
  /// When the function creates or merges a ticket, server may return this id.
  final String? ticketId;
}

/// Fetches driver data from Supabase views and functions.
/// Column names in fromJson may need adjustment to match your migration output.
/// Backend: zone_demand_live, get_driver_earnings_summary, scheduled_rides_available,
/// driver_passenger_comments, drivers (shift/stats), driver_locations (zone).
class DriverDataService {
  final _client = HeyCabySupabase.client;

  /// Resolve driver_id from drivers table where user_id = current auth user.
  Future<String?> getDriverId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final res = await _client
          .from('drivers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      return res?['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Ensures a `drivers` row exists for the signed-in user (e.g. after DB reset).
  /// Prefers RPC `get_or_create_driver` (migration 043+); falls back to insert.
  Future<String?> ensureDriverId() => bootstrapDriverRow();

  /// Links a web `founding_driver_signups` row to this auth user and upserts `drivers`.
  /// Call once after session is established, **before** [bootstrapDriverRow] / [getDriverId].
  /// Non-founding drivers get `is_founding_driver: false`; failures return null (login continues).
  Future<ClaimFoundingDriverResult?> claimFoundingDriver() async {
    Future<dynamic> invokeWithToken() async {
      final session = _client.auth.currentSession;
      if (session == null) return null;
      return _client.functions.invoke(
        'claim-founding-driver',
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
        },
      );
    }

    bool readBool(Map<String, dynamic> m, String snake, String camel) {
      final v = m[snake] ?? m[camel];
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true';
      return false;
    }

    int? readInt(Map<String, dynamic> m, String snake, String camel) {
      final v = m[snake] ?? m[camel];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim());
      return null;
    }

    ClaimFoundingDriverResult? parseBody(dynamic data) {
      if (data is! Map) return null;
      final map = Map<String, dynamic>.from(data);
      if (map['error'] != null) {
        if (kDebugMode) {
          debugPrint('claim-founding-driver: ${map['error']}');
        }
        return null;
      }
      final isFd = readBool(map, 'is_founding_driver', 'isFoundingDriver');
      return ClaimFoundingDriverResult(
        isFoundingDriver: isFd,
        foundingNumber: readInt(map, 'founding_number', 'foundingNumber'),
        needsProfilePhoto: readBool(map, 'needs_profile_photo', 'needsProfilePhoto'),
        needsVehiclePhoto: readBool(map, 'needs_vehicle_photo', 'needsVehiclePhoto'),
      );
    }

    try {
      if (_client.auth.currentSession == null) return null;

      dynamic res;
      try {
        res = await invokeWithToken();
      } on FunctionException catch (e) {
        if (e.status == 401) {
          try {
            await _client.auth.refreshSession();
          } catch (_) {}
          res = await invokeWithToken();
        } else {
          if (kDebugMode) debugPrint('claim-founding-driver: $e');
          return null;
        }
      }

      if (res == null) return null;
      // ignore: avoid_dynamic_calls
      final status = res.status as int;
      if (status == 401) {
        try {
          await _client.auth.refreshSession();
        } catch (_) {}
        res = await invokeWithToken();
        if (res == null) return null;
        // ignore: avoid_dynamic_calls
        if (res.status as int != 200) return null;
      } else if (status != 200) {
        if (kDebugMode) debugPrint('claim-founding-driver: HTTP $status');
        return null;
      }

      // ignore: avoid_dynamic_calls
      final raw = res.data;
      if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          return parseBody(decoded);
        } catch (_) {
          return null;
        }
      }
      return parseBody(raw);
    } on FunctionException catch (e, st) {
      if (kDebugMode) debugPrint('claim-founding-driver: $e\n$st');
      return null;
    } catch (e, st) {
      if (kDebugMode) debugPrint('claim-founding-driver: $e\n$st');
      return null;
    }
  }

  /// Idempotent: call after login / on app start so `drivers` + onboarding rows exist.
  /// Always invokes `get_or_create_driver` when present (server ensures row); returns `drivers.id`.
  Future<String?> bootstrapDriverRow() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final res = await _client.rpc(
        'get_or_create_driver',
        params: {'p_user_id': userId},
      );
      final id = _parseDriverIdFromRpc(res);
      if (id != null) return id;
    } catch (e) {
      if (kDebugMode) debugPrint('get_or_create_driver: $e');
    }
    final existing = await getDriverId();
    if (existing != null) return existing;
    try {
      final res = await _client.from('drivers').insert({'user_id': userId}).select('id').maybeSingle();
      return res?['id'] as String?;
    } catch (e) {
      if (kDebugMode) debugPrint('ensureDriverId insert fallback: $e');
      return getDriverId();
    }
  }

  static String? _parseDriverIdFromRpc(dynamic res) {
    if (res is String && res.isNotEmpty) return res;
    if (res is! Map) return null;
    final m = Map<String, dynamic>.from(res);
    final id = m['id'] as String? ?? m['driver_id'] as String?;
    if (id != null && id.isNotEmpty) return id;
    final inner = m['data'];
    if (inner is Map) {
      final im = Map<String, dynamic>.from(inner);
      return im['id'] as String? ?? im['driver_id'] as String?;
    }
    return null;
  }

  /// Server-side profile write (RLS + lock rules). Falls back to direct `drivers` update
  /// if the RPC is missing (older DB).
  Future<Map<String, dynamic>?> saveDriverProfileRpc({
    required String userId,
    String? fullName,
    String? profilePhotoUrl,
  }) async {
    final params = <String, dynamic>{'p_user_id': userId};
    if (fullName != null) params['p_full_name'] = fullName;
    if (profilePhotoUrl != null) params['p_profile_photo_url'] = profilePhotoUrl;
    try {
      final res = await _client.rpc('save_driver_profile', params: params);
      if (res is Map<String, dynamic>) return res;
      if (res is Map) return Map<String, dynamic>.from(res);
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('save_driver_profile: $e');
      return null;
    }
  }

  /// get_driver_earnings_summary(driver_id) → today, this_week, this_month.
  Future<DriverEarningsSummary?> getEarningsSummary(String driverId) async {
    try {
      final res = await _client.rpc(
        'get_driver_earnings_summary',
        params: {'p_driver_id': driverId},
      ) as Map<String, dynamic>?;
      if (res == null) return null;
      return DriverEarningsSummary.fromJson(res);
    } catch (_) {
      return null;
    }
  }

  /// zone_demand_live view — poll every 30s for map circles.
  Future<List<ZoneDemand>> getZoneDemand() async {
    try {
      final res = await _client
          .from('zone_demand_live')
          .select('zone_id, zone_name, center_lat, center_lng, radius_m, waiting_passengers, demand_level');
      return (res as List)
          .map((e) => ZoneDemand.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Driver shift and stats from drivers table.
  Future<DriverShiftStats?> getShiftStats(String driverId) async {
    const extended =
        'shift_start_at, last_break_start_at, continuous_driving_started_at, '
        'shift_total_online_minutes, shift_break_minutes, shift_rides_today, '
        'shift_earnings_today, acceptance_rate, rating, '
        'current_shift_id, break_reminder_interval_minutes';
    try {
      final res = await _client.from('drivers').select(extended).eq('id', driverId).maybeSingle();
      if (res == null) return null;
      return DriverShiftStats.fromJson(Map<String, dynamic>.from(res));
    } catch (_) {
      try {
        final res = await _client
            .from('drivers')
            .select(
              'shift_start_at, last_break_start_at, continuous_driving_started_at, '
              'shift_total_online_minutes, shift_break_minutes, shift_rides_today, '
              'shift_earnings_today, acceptance_rate, rating',
            )
            .eq('id', driverId)
            .maybeSingle();
        if (res == null) return null;
        return DriverShiftStats.fromJson(Map<String, dynamic>.from(res));
      } catch (_) {
        return null;
      }
    }
  }

  /// Trust score + sub-rating averages from `driver_my_rating` (view over `driver_trust_scores`, RLS: auth.uid()).
  /// Does not query `drivers` directly — avoids duplicating rating logic in the app.
  Future<DriverMyRating?> getDriverMyRating() async {
    try {
      final res = await _client
          .from('driver_my_rating')
          .select(
            'public_stars, trust_score, weighted_avg, '
            'avg_punctuality, avg_cleanliness, avg_attitude, avg_driving_safety, avg_communication, '
            'total_valid_ratings, flag_review_needed, flag_review_reason, '
            'in_protected_window, badge_consistency, badge_top_driver, badge_veteran',
          )
          .maybeSingle();
      if (res == null) return null;
      return DriverMyRating.fromJson(Map<String, dynamic>.from(res));
    } catch (_) {
      return null;
    }
  }

  /// driver_rate_profiles — for earnings modal and Driver Hub.
  Future<List<DriverRateProfile>> getRateProfiles(String driverId) async {
    try {
      final res = await _client
          .from('driver_rate_profiles')
          .select()
          .eq('driver_id', driverId)
          .order('sort_order', ascending: true);
      return (res as List)
          .map((e) => DriverRateProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// fn_switch_rate_profile(driver_id, profile_id). On success returns updated state.
  Future<bool> switchRateProfile(String driverId, String profileId) async {
    try {
      await _client.rpc(
        'fn_switch_rate_profile',
        params: {'driver_id': driverId, 'profile_id': profileId},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Hub badge: open tickets + unresolved safety events. Capped at 10 for display "9+".
  Future<int> getHubBadgeCount(String driverId, String? userId) async {
    try {
      int tickets = 0;
      if (userId != null) {
        final r = await _client
            .from('tickets')
            .select('id')
            .eq('user_type', 'driver')
            .eq('user_id', userId)
            .neq('status', 'resolved')
            .limit(10);
        tickets = (r as List).length;
      }
      final r2 = await _client
          .from('driver_safety_events')
          .select('id')
          .eq('driver_id', driverId)
          .eq('resolved', false)
          .limit(10);
      final events = (r2 as List).length;
      final total = tickets + events;
      return total > 9 ? 10 : total; // 10 means show "9+"
    } catch (_) {
      return 0;
    }
  }

  /// Create first rate profile from drivers table if none exist.
  Future<DriverRateProfile?> createFirstRateProfile(String driverId) async {
    try {
      final existing = await _client
          .from('driver_rate_profiles')
          .select('id')
          .eq('driver_id', driverId)
          .maybeSingle();
      if (existing != null) return null;
      final driver = await _client
          .from('drivers')
          .select('base_fare, per_km_rate, per_min_rate, minimum_fare, waiting_time_rate_per_min')
          .eq('id', driverId)
          .maybeSingle();
      if (driver == null) return null;
      final baseFare = (driver['base_fare'] as num?)?.toDouble() ?? 2.50;
      final perKm = (driver['per_km_rate'] as num?)?.toDouble() ?? 2.00;
      final perMin = (driver['per_min_rate'] as num?)?.toDouble() ?? 0.35;
      final minFare = (driver['minimum_fare'] as num?)?.toDouble() ?? 5.00;
      final waitingRate = (driver['waiting_time_rate_per_min'] as num?)?.toDouble() ?? 0.25;
      final res = await _client.from('driver_rate_profiles').insert({
        'driver_id': driverId,
        'profile_name': 'Standaard',
        'base_fare': baseFare,
        'per_km_rate': perKm,
        'per_min_rate': perMin,
        'minimum_fare': minFare,
        'waiting_rate': waitingRate,
        'is_active': true,
        'sort_order': 0,
      }).select().single();
      return DriverRateProfile.fromJson(Map<String, dynamic>.from(res as Map));
    } catch (_) {
      return null;
    }
  }

  /// driver_earnings_targets — for Driver Hub section 1.
  Future<Map<String, double>> getEarningsTargets(String driverId) async {
    try {
      final res = await _client
          .from('driver_earnings_targets')
          .select('target_type, target_amount')
          .eq('driver_id', driverId);
      final map = <String, double>{};
      for (final row in res as List) {
        final type = row['target_type'] as String?;
        final amount = (row['target_amount'] as num?)?.toDouble();
        if (type != null && amount != null) map[type] = amount;
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<void> upsertEarningsTarget(
    String driverId,
    String targetType,
    double targetAmount,
  ) async {
    await _client.from('driver_earnings_targets').upsert({
      'driver_id': driverId,
      'target_type': targetType,
      'target_amount': targetAmount,
    }, onConflict: 'driver_id,target_type');
  }

  /// Recent tickets for Driver Hub help section.
  Future<List<DriverTicket>> getRecentTickets(String? userId, {int limit = 3}) async {
    if (userId == null) return [];
    try {
      final res = await _client
          .from('tickets')
          .select('id, created_at, status, messages, ride_request_id')
          .eq('user_type', 'driver')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (res as List)
          .map((e) => DriverTicket.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// app_config driver_help_url for Help artikelen.
  Future<String> getDriverHelpUrl() async {
    try {
      final res = await _client
          .from('app_config')
          .select('value')
          .eq('key', 'driver_help_url')
          .maybeSingle();
      final v = res?['value'] as String?;
      return v ?? '$kAppPublicWebOrigin/help/drivers';
    } catch (_) {
      return '$kAppPublicWebOrigin/help/drivers';
    }
  }

  /// Log safety event (emergency call, audio recording).
  Future<void> insertSafetyEvent(
    String driverId,
    String eventType, {
    String? rideRequestId,
  }) async {
    await _client.from('driver_safety_events').insert({
      'driver_id': driverId,
      'event_type': eventType,
      if (rideRequestId != null) 'ride_request_id': rideRequestId,
    });
  }

  /// Create new support ticket (Driver Hub "Stuur een bericht").
  Future<void> createTicket(String userId) async {
    await _client.from('tickets').insert({
      'user_type': 'driver',
      'user_id': userId,
      'category': 'driver_support',
      'priority': 'normal',
      'status': 'open',
      'messages': [],
    });
  }

  /// Create or get ride share link for active ride. Returns track URL.
  Future<String?> getOrCreateRideShareUrl(String rideRequestId) async {
    try {
      final existing = await _client
          .from('ride_shares')
          .select('share_token')
          .eq('ride_request_id', rideRequestId)
          .maybeSingle();
      final token = existing?['share_token'] as String?;
      if (token != null && token.isNotEmpty) {
        return '$kAppPublicWebOrigin/track/$token';
      }
      final newRow = await _client.from('ride_shares').insert({
        'ride_request_id': rideRequestId,
      }).select('share_token').single();
      final t = newRow['share_token'] as String?;
      return t != null ? '$kAppPublicWebOrigin/track/$t' : null;
    } catch (_) {
      return null;
    }
  }

  /// Feasible scheduled count: only rides driver can take without overlap. Cached 60s.
  static int? _feasibleCountCache;
  static String? _feasibleCountDriverId;
  static DateTime? _feasibleCountAt;

  Future<int> getFeasibleScheduledCount(String driverId) async {
    const cacheSec = 60;
    if (_feasibleCountCache != null &&
        _feasibleCountDriverId == driverId &&
        _feasibleCountAt != null &&
        DateTime.now().difference(_feasibleCountAt!).inSeconds < cacheSec) {
      return _feasibleCountCache!;
    }
    try {
      final res = await _client
          .from('scheduled_rides_available')
          .select('id, scheduled_pickup_at, estimated_duration_min')
          .order('scheduled_pickup_at', ascending: true)
          .limit(200);
      var count = 0;
      for (final row in res as List) {
        final start = row['scheduled_pickup_at'];
        final dur = (row['estimated_duration_min'] as num?)?.toDouble() ?? 60.0;
        final hasOverlap = await _client.rpc('fn_driver_has_overlap', params: {
          'p_driver_id': driverId,
          'p_proposed_start': start,
          'p_proposed_duration_min': dur,
        });
        if (hasOverlap == false) count++;
      }
      _feasibleCountCache = count;
      _feasibleCountDriverId = driverId;
      _feasibleCountAt = DateTime.now();
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// scheduled_rides_available view — for home card count and scheduled screen.
  /// tab: 'requests' = pending, 'confirmed' = driver accepted.
  Future<List<ScheduledRide>> getScheduledRidesAvailable({
    required String? driverId,
    String tab = 'requests',
    int limit = 20,
  }) async {
    try {
      if (tab == 'confirmed' && driverId != null) {
        return getConfirmedRidesForDriver(driverId, limit: limit);
      }
      var query = _client.from('scheduled_rides_available').select();
      final res = await query
          .order('scheduled_pickup_at', ascending: true)
          .limit(limit);
      return (res as List)
          .map((e) => ScheduledRide.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Confirmed rides for this driver from `ride_requests` (includes `swap_listed`, `status`).
  Future<List<ScheduledRide>> getConfirmedRidesForDriver(String driverId, {int limit = 50}) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      try {
        final res = await _client
            .from('ride_requests')
            .select(
              'id, pickup_address, destination_address, scheduled_pickup_at, '
              'offered_fare, estimated_distance_km, estimated_duration_min, '
              'pickup_lat, pickup_lng, destination_lat, destination_lng, '
              'status, swap_listed, swap_listed_at, payment_methods, vehicle_category, '
              'booking_mode, rider_identity_id, rider_preride_request_sent_at, '
              'rider_preride_deadline, rider_preride_confirmed, preride_commitment_fee_euros, '
              'commitment_fee_tikkie_url, commitment_fee_received, driver_preride_released_at',
            )
            .eq('driver_id', driverId)
            .inFilter('status', ['accepted', 'driver_arrived'])
            .gte('scheduled_pickup_at', now)
            .order('scheduled_pickup_at', ascending: true)
            .limit(limit);
        final list = (res as List)
            .map((e) => ScheduledRide.fromJson(e as Map<String, dynamic>))
            .toList();
        return _withReliabilityTiers(list);
      } catch (_) {
        final res = await _client
            .from('ride_requests')
            .select(
              'id, pickup_address, destination_address, scheduled_pickup_at, '
              'offered_fare, estimated_distance_km, estimated_duration_min, '
              'pickup_lat, pickup_lng, destination_lat, destination_lng, '
              'status, swap_listed, vehicle_category, booking_mode, rider_identity_id, '
              'rider_preride_request_sent_at, rider_preride_deadline, rider_preride_confirmed, '
              'preride_commitment_fee_euros, commitment_fee_tikkie_url, commitment_fee_received, '
              'driver_preride_released_at',
            )
            .eq('driver_id', driverId)
            .inFilter('status', ['accepted', 'driver_arrived'])
            .gte('scheduled_pickup_at', now)
            .order('scheduled_pickup_at', ascending: true)
            .limit(limit);
        final list = (res as List)
            .map((e) => ScheduledRide.fromJson(e as Map<String, dynamic>))
            .toList();
        return _withReliabilityTiers(list);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('getConfirmedRidesForDriver: $e');
      return [];
    }
  }

  /// driver_passenger_comments view — for driver score screen.
  Future<List<DriverComment>> getPassengerComments(String driverId) async {
    try {
      final res = await _client
          .from('driver_passenger_comments')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false)
          .limit(20);
      return (res as List)
          .map((e) => DriverComment.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Hidden comment IDs for dismiss feature.
  Future<Set<String>> getHiddenCommentIds(String driverId) async {
    try {
      final res = await _client
          .from('driver_hidden_comments')
          .select('rating_id')
          .eq('driver_id', driverId);
      return ((res as List))
          .map((e) => (e as Map<String, dynamic>)['rating_id'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  /// Dismiss (hide) a comment from driver's view.
  Future<bool> dismissComment(String driverId, String ratingId) async {
    try {
      await _client.from('driver_hidden_comments').insert({
        'rating_id': ratingId,
        'driver_id': driverId,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Report a comment for admin review.
  /// Returns true on success or if already reported (idempotent).
  Future<bool> reportComment(String driverId, String ratingId) async {
    try {
      await _client.from('driver_comment_reports').insert({
        'rating_id': ratingId,
        'driver_id': driverId,
      });
      return true;
    } catch (e) {
      if (e.toString().contains('duplicate') || e.toString().contains('unique')) {
        return true;
      }
      return false;
    }
  }

  /// Current zone ID from driver_locations.
  Future<String?> getCurrentZoneId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final loc = await _client
          .from('driver_locations')
          .select('current_zone_id')
          .eq('user_id', userId)
          .maybeSingle();
      return loc?['current_zone_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Current zone name from driver_locations + bubble_zones.
  Future<String?> getCurrentZoneName() async {
    final zoneId = await getCurrentZoneId();
    if (zoneId == null) return null;
    try {
      final zone = await _client
          .from('bubble_zones')
          .select('name_display')
          .eq('id', zoneId)
          .maybeSingle();
      return zone?['name_display'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Last 7 days daily earnings (index 0 = 6 days ago, 6 = today).
  Future<List<double>> getWeeklyDailyEarnings(String driverId) async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      final startStr = start.toUtc().toIso8601String().split('T').first;
      final res = await _client
          .from('driver_trip_history')
          .select('ride_request_id, completed_at')
          .eq('driver_id', driverId)
          .gte('completed_at', startStr)
          .order('completed_at', ascending: true);
      final list = res as List;
      if (list.isEmpty) return List.filled(7, 0.0);
      final rrIds = list
          .map((e) => e['ride_request_id'] as String?)
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      final fareMap = <String, double>{};
      if (rrIds.isNotEmpty) {
        final rrs = await _client
            .from('ride_requests')
            .select('id, final_fare')
            .inFilter('id', rrIds);
        for (final rr in rrs as List) {
          final id = rr['id'] as String?;
          if (id != null) {
            fareMap[id] = (rr['final_fare'] as num?)?.toDouble() ?? 0;
          }
        }
      }
      final daily = List.filled(7, 0.0);
      for (final row in list) {
        final dt = _parseDateTime(row['completed_at']);
        if (dt == null) continue;
        final dayStart = DateTime(dt.year, dt.month, dt.day);
        final dayIndex = dayStart.difference(start).inDays;
        if (dayIndex >= 0 && dayIndex < 7) {
          final rrId = row['ride_request_id'] as String?;
          daily[dayIndex] += rrId != null ? (fareMap[rrId] ?? 0) : 0;
        }
      }
      return daily;
    } catch (_) {
      return List.filled(7, 0.0);
    }
  }

  /// Today's completed rides with zone names and fare (Step 7 — zone names only).
  Future<List<TodayRide>> getTodayRides(String driverId) async {
    try {
      final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final res = await _client
          .from('driver_trip_history')
          .select('''
            id, completed_at, distance_km, ride_request_id,
            pickup_zone:bubble_zones!pickup_zone_id(name_display),
            destination_zone:bubble_zones!destination_zone_id(name_display),
            ride_request:ride_requests!ride_request_id(final_fare)
          ''')
          .eq('driver_id', driverId)
          .gte('completed_at', today)
          .order('completed_at', ascending: false)
          .limit(50);
      final list = res as List;
      final rides = <TodayRide>[];
      for (final row in list) {
        final pickupZone = row['pickup_zone'];
        final destZone = row['destination_zone'];
        final rr = row['ride_request'];
        final pickupName = (pickupZone is Map ? pickupZone['name_display'] : null) as String?;
        final destName = (destZone is Map ? destZone['name_display'] : null) as String?;
        final fare = (rr is Map ? (rr['final_fare'] as num?)?.toDouble() : null);
        rides.add(TodayRide(
          id: row['id'] as String? ?? '',
          completedAt: _parseDateTime(row['completed_at']),
          fare: fare,
          pickup: pickupName,
          destination: destName,
          pickupZoneName: pickupName,
          destinationZoneName: destName,
        ));
      }
      return rides;
    } catch (_) {
      return [];
    }
  }

  DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  /// Community posts by channel.
  Future<List<CommunityPost>> getCommunityPosts(String channel, {int limit = 20}) async {
    try {
      var query = _client
          .from('community_posts')
          .select('id, driver_id, content, created_at, channel, ride_request_id, swap_status')
          .eq('channel', channel);
      if (channel == 'swap') {
        query = query.eq('swap_status', 'open');
      }
      final res = await query.order('created_at', ascending: false).limit(limit);
      return (res as List)
          .map((e) => CommunityPost.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Driver profile for Me tab.
  Future<DriverProfile?> getDriverProfile(String driverId) async {
    try {
      final res = await _client
          .from('drivers')
          .select(
            'full_name, vehicle_plate, vehicle_make, vehicle_model, vehicle_year, '
            'rating, avg_rating, pickup_distance_max_km, payment_methods, '
            'is_pet_friendly, is_wheelchair_accessible, profile_photo_url, profile_photo_locked, '
            'is_verified_badge, profile_status, compliance_status, '
            'congratulations_modal_shown, '
            'heading_home_zone_id, home_city, '
            'chauffeurspas_expiry, rijbewijs_expiry, vog_expires_at, taxi_insurance_expiry, '
            'onboarding_feature_tour_shown, '
            'is_founding_driver, founding_number',
          )
          .eq('id', driverId)
          .maybeSingle();
      if (res == null) return null;
      return DriverProfile.fromJson(res);
    } catch (_) {
      return null;
    }
  }

  /// Compliance fields for Documents hub (Wpv 2000 — matches `drivers` columns in Supabase).
  Future<DriverComplianceSnapshot?> getDriverCompliance(String driverId) async {
    const cols = 'compliance_status, chauffeurspas_verified, chauffeurspas_number, chauffeurspas_expiry, '
        'vog_verified, vog_implied_by_chauffeurspas, vog_expires_at, '
        'rijbewijs_verified, rijbewijs_expiry, taxidiploma_verified, '
        'taxi_insurance_verified, taxi_insurance_expiry, taxi_insurance_photo_url, '
        'taxi_insurance_provider, taxi_insurance_policy_number, '
        'kvk_verified, kvk_number, kvk_business_name, kvk_address, '
        'veriff_status, veriff_session_url, veriff_full_name, veriff_id_expiry, '
        'vehicle_verified, vehicle_verification_status, '
        'rdw_apk_vervaldatum, rdw_wam_verzekerd, '
        'vehicle_plate, rdw_merk, rdw_handelsbenaming';
    try {
      final res = await _client.from('drivers').select(cols).eq('id', driverId).maybeSingle();
      if (res == null) return null;
      return DriverComplianceSnapshot.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('getDriverCompliance extended select failed: $e');
      }
      try {
        final res = await _client
            .from('drivers')
            .select(
              'compliance_status, vehicle_plate, chauffeurspas_expiry, rijbewijs_expiry, '
              'vog_expires_at, taxi_insurance_expiry',
            )
            .eq('id', driverId)
            .maybeSingle();
        if (res == null) return null;
        return DriverComplianceSnapshot.fromJsonMinimal(Map<String, dynamic>.from(res));
      } catch (_) {
        return null;
      }
    }
  }

  /// Lee (AI) — Edge Function `driver-support-chat`. Persists user + assistant rows in `tickets.messages`.
  /// [ticketId] optional; server can find/create the driver’s open ticket when omitted.
  ///
  /// Sends an explicit `Authorization: Bearer <access_token>` (some clients omit it for `invoke`)
  /// and retries once after [refreshSession] on **401 Invalid JWT** (expired access token).
  Future<DriverSupportChatResult> sendDriverSupportChatMessage({
    required String message,
    String? ticketId,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return const DriverSupportChatResult(ok: false, error: 'empty_message');
    }
    final body = <String, dynamic>{'message': trimmed};
    if (ticketId != null && ticketId.isNotEmpty) {
      body['ticket_id'] = ticketId;
    }

    Future<dynamic> invokeWithSessionToken() async {
      final session = _client.auth.currentSession;
      if (session == null) {
        return null;
      }
      return _client.functions.invoke(
        'driver-support-chat',
        body: body,
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
        },
      );
    }

    DriverSupportChatResult parseResponse(dynamic res) {
      // ignore: avoid_dynamic_calls
      final code = res.status as int;
      if (code != 200) {
        // ignore: avoid_dynamic_calls
        final body = res.data;
        return DriverSupportChatResult(
          ok: false,
          error: body?.toString() ?? 'HTTP $code',
        );
      }
      // ignore: avoid_dynamic_calls
      final data = res.data;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        if (map['error'] != null) {
          return DriverSupportChatResult(
            ok: false,
            error: map['error'].toString(),
          );
        }
        final tid = map['ticket_id'] as String? ?? map['ticketId'] as String?;
        return DriverSupportChatResult(
          ok: true,
          reply: map['reply'] as String?,
          ticketId: tid,
        );
      }
      return const DriverSupportChatResult(ok: true);
    }

    try {
      if (_client.auth.currentSession == null) {
        return const DriverSupportChatResult(ok: false, error: 'not_signed_in');
      }

      dynamic res;
      try {
        res = await invokeWithSessionToken();
      } on FunctionException catch (e) {
        if (e.status == 401) {
          if (kDebugMode) {
            debugPrint('sendDriverSupportChatMessage: 401 — refreshSession + retry');
          }
          try {
            await _client.auth.refreshSession();
          } catch (err) {
            if (kDebugMode) debugPrint('sendDriverSupportChatMessage: refresh failed: $err');
          }
          res = await invokeWithSessionToken();
        } else {
          rethrow;
        }
      }

      if (res == null) {
        return const DriverSupportChatResult(ok: false, error: 'not_signed_in');
      }

      // ignore: avoid_dynamic_calls
      final status = res.status as int;
      if (status == 401) {
        try {
          await _client.auth.refreshSession();
        } catch (_) {}
        res = await invokeWithSessionToken();
        if (res == null) {
          return const DriverSupportChatResult(ok: false, error: 'not_signed_in');
        }
      }

      return parseResponse(res);
    } on FunctionException catch (e, st) {
      if (kDebugMode) {
        debugPrint('sendDriverSupportChatMessage: $e\n$st');
      }
      if (e.status == 401) {
        return const DriverSupportChatResult(
          ok: false,
          error: 'session_expired',
        );
      }
      return DriverSupportChatResult(ok: false, error: e.toString());
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('sendDriverSupportChatMessage: $e\n$st');
      }
      return DriverSupportChatResult(ok: false, error: e.toString());
    }
  }

  /// Supabase Edge Function `verify-chauffeurspas` (ILT). Invalidates profile after success.
  Future<ChauffeurspasVerifyOutcome> verifyChauffeurspas(String rawInput) async {
    final normalized = rawInput.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
    if (normalized.length < 8) {
      return const ChauffeurspasVerifyOutcome(ok: false, message: 'Enter an 8-digit chauffeurspas number.');
    }
    try {
      final res = await _client.functions.invoke(
        'verify-chauffeurspas',
        body: {'number': normalized},
      );
      if (res.status != 200) {
        return ChauffeurspasVerifyOutcome(
          ok: false,
          message: res.data?.toString() ?? 'Service error (${res.status})',
        );
      }
      final data = res.data;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        if (map['error'] != null) {
          return ChauffeurspasVerifyOutcome(ok: false, message: map['error'].toString());
        }
        if (map['success'] == true || map['valid'] == true || map['verified'] == true) {
          return ChauffeurspasVerifyOutcome(
            ok: true,
            message: map['message']?.toString() ?? 'Verified',
          );
        }
        if (map['ok'] == false || map['valid'] == false) {
          return ChauffeurspasVerifyOutcome(
            ok: false,
            message: map['message']?.toString() ?? 'Not valid',
          );
        }
      }
      return const ChauffeurspasVerifyOutcome(ok: true, message: 'OK');
    } catch (e) {
      return ChauffeurspasVerifyOutcome(ok: false, message: e.toString());
    }
  }

  /// Return trips view (driver_return_trips). Filter for home zone/city happens in Dart.
  Future<List<DriverReturnTrip>> getReturnTrips({int limit = 100}) async {
    try {
      final res = await _client
          .from('driver_return_trips')
          .select()
          .limit(limit);
      return (res as List)
          .map((e) => DriverReturnTrip.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Update active rate profile return discount percentage (0..40).
  Future<bool> updateReturnDiscountPct({
    required String rateProfileId,
    required double returnDiscountPct,
  }) async {
    try {
      await _client.from('driver_rate_profiles').update({
        'return_discount_pct': returnDiscountPct,
      }).eq('id', rateProfileId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Power Mode cards (Step 11). Source: fn_get_power_suggestions(driver_id).
  Future<List<DriverPowerCard>> getPowerSuggestions(String driverId) async {
    try {
      dynamic res;
      try {
        res = await _client.rpc('fn_get_power_suggestions', params: {'p_driver_id': driverId});
      } catch (_) {
        res = await _client.rpc('fn_get_power_suggestions', params: {'driver_id': driverId});
      }
      final list = res is List ? res : (res is Map ? [res] : const []);
      return list
          .whereType<Map>()
          .map((e) => DriverPowerCard.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> dismissPowerCard({required String cardId, required String driverId}) async {
    try {
      try {
        await _client.rpc('fn_dismiss_power_card', params: {'p_card_id': cardId, 'p_driver_id': driverId});
      } catch (_) {
        await _client.rpc('fn_dismiss_power_card', params: {'card_id': cardId, 'driver_id': driverId});
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Union Mode dashboard rows (Step 12). Source: union_mode_dashboard view.
  Future<List<UnionDashboardRow>> getUnionDashboard() async {
    try {
      final res = await _client.from('union_mode_dashboard').select().limit(200);
      return (res as List)
          .map((e) => UnionDashboardRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Union Mode community signals feed (Step 12).
  Future<List<DriverMarketSignal>> getMarketSignals({int limit = 30}) async {
    try {
      final res = await _client
          .from('driver_market_signals')
          .select('id, zone_id, signal_type, description, upvotes, created_at')
          .order('upvotes', ascending: false)
          .limit(limit);
      return (res as List)
          .map((e) => DriverMarketSignal.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> upvoteMarketSignal(DriverMarketSignal signal) async {
    try {
      await _client.from('driver_market_signals').update({'upvotes': signal.upvotes + 1}).eq('id', signal.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Insert signal with duplicate check (same zone/type within 1h). If duplicate found, upvotes it.
  Future<bool> createOrUpvoteMarketSignal({
    required String zoneId,
    required String signalType,
    String? description,
  }) async {
    try {
      final recent = await _client
          .from('driver_market_signals')
          .select('id, upvotes')
          .eq('zone_id', zoneId)
          .eq('signal_type', signalType)
          .gte('created_at', DateTime.now().subtract(const Duration(hours: 1)).toIso8601String())
          .maybeSingle();
      if (recent != null) {
        final id = recent['id'] as String?;
        final up = (recent['upvotes'] as num?)?.toInt() ?? 0;
        if (id != null) {
          await _client.from('driver_market_signals').update({'upvotes': up + 1}).eq('id', id);
          return true;
        }
      }
      await _client.from('driver_market_signals').insert({
        'zone_id': zoneId,
        'signal_type': signalType,
        'description': (description != null && description.trim().isNotEmpty) ? description.trim() : null,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Update vehicle info. Returns true on success.
  Future<bool> updateVehicle(String driverId, {
    String? plate,
    String? make,
    String? model,
    int? year,
  }) async {
    try {
      await _client.from('drivers').update({
        if (plate != null) 'vehicle_plate': plate,
        if (make != null) 'vehicle_make': make,
        if (model != null) 'vehicle_model': model,
        if (year != null) 'vehicle_year': year,
      }).eq('id', driverId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Persists preferences via `save_driver_preferences` (migration 041+). Uses `auth` user id.
  Future<Map<String, dynamic>?> saveDriverPreferences({
    int? pickupDistanceKm,
    List<String>? paymentMethods,
    bool? isPetFriendly,
    bool? isWheelchairAccessible,
    bool? autoAcceptEnabled,
    double? autoAcceptMinFare,
    bool? radarEnabled,
    bool? isElectric,
    bool? isFemaleDriver,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final params = <String, dynamic>{
        'p_user_id': uid,
        if (pickupDistanceKm != null) 'p_pickup_distance_km': pickupDistanceKm,
        if (paymentMethods != null) 'p_payment_methods': paymentMethods,
        if (isPetFriendly != null) 'p_is_pet_friendly': isPetFriendly,
        if (isWheelchairAccessible != null) 'p_is_wheelchair_accessible': isWheelchairAccessible,
        if (autoAcceptEnabled != null) 'p_auto_accept_enabled': autoAcceptEnabled,
        if (autoAcceptMinFare != null) 'p_auto_accept_min_fare': autoAcceptMinFare,
        if (radarEnabled != null) 'p_radar_enabled': radarEnabled,
        if (isElectric != null) 'p_is_electric': isElectric,
        if (isFemaleDriver != null) 'p_is_female_driver': isFemaleDriver,
      };
      final res = await _client.rpc('save_driver_preferences', params: params);
      if (res is Map<String, dynamic>) return res;
      if (res is Map) return Map<String, dynamic>.from(res);
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('saveDriverPreferences: $e');
      return null;
    }
  }

  /// Update driver preferences (wraps [saveDriverPreferences]). `driverId` kept for call sites.
  Future<bool> updateDriverPrefs(String driverId, {
    double? pickupDistanceMaxKm,
    bool? isPetFriendly,
    bool? isWheelchairAccessible,
    List<String>? paymentMethod,
  }) async {
    final res = await saveDriverPreferences(
      pickupDistanceKm: pickupDistanceMaxKm?.round(),
      paymentMethods: paymentMethod,
      isPetFriendly: isPetFriendly,
      isWheelchairAccessible: isWheelchairAccessible,
    );
    return res?['success'] == true;
  }

  /// `save_driver_document` RPC — chauffeurspas, taxi_insurance, kvk, veriff session metadata.
  Future<Map<String, dynamic>?> saveDriverDocument({
    required String documentType,
    String? chauffeurspasNumber,
    String? chauffeurspasExpiry,
    String? insurancePhotoUrl,
    String? insuranceProvider,
    String? insuranceExpiry,
    String? insurancePolicyNr,
    String? kvkNumber,
    String? kvkBusinessName,
    String? kvkAddress,
    String? veriffSessionId,
    String? veriffSessionUrl,
    String? veriffStatus,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final res = await _client.rpc(
        'save_driver_document',
        params: {
          'p_user_id': uid,
          'p_document_type': documentType,
          if (chauffeurspasNumber != null) 'p_chauffeurspas_number': chauffeurspasNumber,
          if (chauffeurspasExpiry != null) 'p_chauffeurspas_expiry': chauffeurspasExpiry,
          if (insurancePhotoUrl != null) 'p_insurance_photo_url': insurancePhotoUrl,
          if (insuranceProvider != null) 'p_insurance_provider': insuranceProvider,
          if (insuranceExpiry != null) 'p_insurance_expiry': insuranceExpiry,
          if (insurancePolicyNr != null) 'p_insurance_policy_nr': insurancePolicyNr,
          if (kvkNumber != null) 'p_kvk_number': kvkNumber,
          if (kvkBusinessName != null) 'p_kvk_business_name': kvkBusinessName,
          if (kvkAddress != null) 'p_kvk_address': kvkAddress,
          if (veriffSessionId != null) 'p_veriff_session_id': veriffSessionId,
          if (veriffSessionUrl != null) 'p_veriff_session_url': veriffSessionUrl,
          if (veriffStatus != null) 'p_veriff_status': veriffStatus,
        },
      );
      if (res is Map<String, dynamic>) return res;
      if (res is Map) return Map<String, dynamic>.from(res);
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('saveDriverDocument: $e');
      return null;
    }
  }

  /// RDW + vehicle save via `save_vehicle_info` RPC.
  Future<Map<String, dynamic>?> saveVehicleInfo({
    required String vehiclePlate,
    required String vehiclePlateEntered,
    String? rdwVoertuigsoort,
    String? rdwMerk,
    String? rdwHandelsbenaming,
    String? rdwEersteKleur,
    String? rdwTweedeKleur,
    String? rdwDatumEersteToelating,
    String? rdwAantalZitplaatsen,
    String? rdwInrichting,
    String? rdwMassaLedigVoertuig,
    String? rdwWamVerzekerd,
    String? rdwApkVervaldatum,
    required String vehicleVerificationStatus,
    String? vehicleType,
    String? vehicleYear,
    String? vehicleColour,
    String? passengerSeats,
    bool isWheelchairAccessible = false,
    bool isElectric = false,
    bool isPetFriendly = false,
    bool isFemaleDriver = false,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final res = await _client.rpc(
        'save_vehicle_info',
        params: {
          'p_user_id': uid,
          'p_vehicle_plate': vehiclePlate,
          'p_vehicle_plate_entered': vehiclePlateEntered,
          if (rdwVoertuigsoort != null) 'p_rdw_voertuigsoort': rdwVoertuigsoort,
          if (rdwMerk != null) 'p_rdw_merk': rdwMerk,
          if (rdwHandelsbenaming != null) 'p_rdw_handelsbenaming': rdwHandelsbenaming,
          if (rdwEersteKleur != null) 'p_rdw_eerste_kleur': rdwEersteKleur,
          if (rdwTweedeKleur != null) 'p_rdw_tweede_kleur': rdwTweedeKleur,
          if (rdwDatumEersteToelating != null) 'p_rdw_datum_eerste_toelating': rdwDatumEersteToelating,
          if (rdwAantalZitplaatsen != null) 'p_rdw_aantal_zitplaatsen': rdwAantalZitplaatsen,
          if (rdwInrichting != null) 'p_rdw_inrichting': rdwInrichting,
          if (rdwMassaLedigVoertuig != null) 'p_rdw_massa_ledig_voertuig': rdwMassaLedigVoertuig,
          if (rdwWamVerzekerd != null) 'p_rdw_wam_verzekerd': rdwWamVerzekerd,
          if (rdwApkVervaldatum != null) 'p_rdw_apk_vervaldatum': rdwApkVervaldatum,
          'p_vehicle_verification_status': vehicleVerificationStatus,
          if (vehicleType != null) 'p_vehicle_type': vehicleType,
          if (vehicleYear != null) 'p_vehicle_year': vehicleYear,
          if (vehicleColour != null) 'p_vehicle_colour': vehicleColour,
          if (passengerSeats != null) 'p_passenger_seats': passengerSeats,
          'p_is_wheelchair_accessible': isWheelchairAccessible,
          'p_is_electric': isElectric,
          'p_is_pet_friendly': isPetFriendly,
          'p_is_female_driver': isFemaleDriver,
        },
      );
      if (res is Map<String, dynamic>) {
        return _normalizeSaveVehicleInfoResponse(res);
      }
      if (res is Map) {
        return _normalizeSaveVehicleInfoResponse(Map<String, dynamic>.from(res));
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('saveVehicleInfo: $e');
      if (_isVehiclePlateUniqueViolation(e)) {
        return {'success': false, 'error': kVehiclePlateDuplicateCode};
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  /// After admin approval — mark congratulations modal as seen.
  Future<bool> dismissCongratulationsModal() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      await _client.from('drivers').update({
        'congratulations_modal_shown': true,
        'congratulations_modal_shown_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('user_id', uid);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('dismissCongratulationsModal: $e');
      return false;
    }
  }

  /// Passenger-visible name on `drivers.full_name`.
  /// Marks the one-time feature tour as shown. Safe to call multiple times.
  Future<void> markFeatureTourShown(String driverId) async {
    try {
      await _client
          .from('drivers')
          .update({'onboarding_feature_tour_shown': true})
          .eq('id', driverId);
    } catch (_) {}
  }

  Future<bool> updateDriverFullName(String driverId, String fullName) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    final t = fullName.trim();
    if (t.isEmpty) return false;
    try {
      final rpc = await saveDriverProfileRpc(userId: uid, fullName: t);
      if (rpc != null) {
        final ok = rpc['success'] == true;
        if (ok) return true;
        if (kDebugMode) debugPrint('save_driver_profile: $rpc');
        return false;
      }
      await _client.from('drivers').update({'full_name': t}).eq('id', driverId);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('updateDriverFullName: $e');
      return false;
    }
  }

  /// Public bucket for profile photos (`driver-documents` is private — public URLs 403).
  static const _profilePhotoBucket = 'driver-photos';

  /// Upload profile photo once, set public URL on `drivers` and lock further driver-side changes.
  /// [profilePhotoLocked] prevents replacement in-app; admin must unlock in DB if needed.
  /// Retries up to 3 times on [TlsException] (network-level SSL errors); throws
  /// [ProfilePhotoConnectionException] on final failure so UI can show a connection-specific message.
  Future<String?> uploadDriverProfilePhotoOnce({
    required String driverId,
    required Uint8List bytes,
    required String contentType,
    String fileExtension = 'jpg',
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    const maxTlsRetries = 3;

    Future<String?> doUpload() async {
      final path = '$driverId/profile-photo.$fileExtension';
      await _client.storage.from(_profilePhotoBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      final url = _client.storage.from(_profilePhotoBucket).getPublicUrl(path);
      final rpc = await saveDriverProfileRpc(userId: uid, profilePhotoUrl: url);
      if (rpc != null) {
        final ok = rpc['success'] == true;
        if (ok) return url;
        if (rpc['error'] == 'profile_photo_locked') {
          if (kDebugMode) debugPrint('uploadDriverProfilePhotoOnce: profile_photo_locked');
        } else if (kDebugMode) {
          debugPrint('save_driver_profile: $rpc');
        }
        return null;
      }
      await _client.from('drivers').update({
        'profile_photo_url': url,
        'profile_photo_locked': true,
      }).eq('id', driverId);
      return url;
    }

    var lastTlsError = 0;
    try {
      return await doUpload();
    } on TlsException catch (e, st) {
      lastTlsError++;
      if (kDebugMode) {
        debugPrint('uploadDriverProfilePhotoOnce: TlsException (attempt $lastTlsError/$maxTlsRetries): $e\n$st');
      }
      for (var i = lastTlsError; i < maxTlsRetries; i++) {
        await Future<void>.delayed(Duration(milliseconds: 300 * (i + 1)));
        try {
          return await doUpload();
        } on TlsException catch (retryE) {
          if (kDebugMode) debugPrint('uploadDriverProfilePhotoOnce: retry $i failed: $retryE');
        }
      }
      throw const ProfilePhotoConnectionException();
    } catch (e) {
      if (e is ProfilePhotoConnectionException) rethrow;
      if (kDebugMode) debugPrint('uploadDriverProfilePhotoOnce: $e');
      return null;
    }
  }

  /// Upload insurance/policy image to `driver-documents` bucket; returns public URL or null.
  Future<String?> uploadDriverInsurancePhoto({
    required String driverId,
    required Uint8List bytes,
    required String contentType,
    String fileExtension = 'jpg',
  }) async {
    try {
      final path =
          '$driverId/insurance-${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      await _client.storage.from('driver-documents').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      return _client.storage.from('driver-documents').getPublicUrl(path);
    } catch (e) {
      if (kDebugMode) debugPrint('uploadDriverInsurancePhoto: $e');
      return null;
    }
  }

  /// Veriff v2: invoke Edge Function `create-driver-veriff-session` (HMAC + `VERIFF_BASE_URL` on server).
  /// Passes [endUserId] = `drivers.id` (UUID) for Veriff audit trail. Persists session via [saveDriverDocument].
  /// Response shape: `{ sessionId, url, verification?: { id, url } }`.
  Future<VeriffSessionResult?> startVeriffVerificationAndPersist() async {
    if (_client.auth.currentUser?.id == null) return null;
    // Edge Functions validate JWT at the gateway; stale sessions → 401 Invalid JWT.
    try {
      final refreshed = await _client.auth.refreshSession();
      if (refreshed.session == null) return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('startVeriffVerificationAndPersist: refreshSession failed: $e');
      }
      return null;
    }
    return _invokeCreateDriverVeriffSession(isRetry: false);
  }

  /// Invokes `create-driver-veriff-session` with an explicit [FunctionsClient.setAuth] so
  /// the user access token is used (gateway rejects anon-only `Authorization` with 401).
  Future<VeriffSessionResult?> _invokeCreateDriverVeriffSession({required bool isRetry}) async {
    final sess = _client.auth.currentSession;
    if (sess == null || sess.accessToken.isEmpty) {
      if (kDebugMode) debugPrint('startVeriffVerificationAndPersist: missing session');
      return null;
    }
    _client.functions.setAuth(sess.accessToken);

    try {
      final driverId = await getDriverId();
      final body = <String, dynamic>{};
      if (driverId != null && driverId.isNotEmpty) {
        body['endUserId'] = driverId;
      }
      final res = await _client.functions.invoke(
        'create-driver-veriff-session',
        body: body.isEmpty ? const {} : body,
      );
      final data = res.data;
      if (data is! Map) return null;
      final map = Map<String, dynamic>.from(data);
      Map<String, dynamic>? verMap;
      final v = map['verification'];
      if (v is Map) verMap = Map<String, dynamic>.from(v);

      final url = map['url'] as String? ??
          map['sessionUrl'] as String? ??
          verMap?['url'] as String?;
      final sid = map['sessionId'] as String? ??
          map['id'] as String? ??
          verMap?['id'] as String? ??
          verMap?['sessionId'] as String?;

      if (url == null || url.isEmpty) return null;
      await saveDriverDocument(
        documentType: 'veriff',
        veriffSessionId: sid,
        veriffSessionUrl: url,
        veriffStatus: 'created',
      );
      return VeriffSessionResult(url: url, sessionId: sid);
    } on FunctionException catch (e) {
      if (e.status == 401 && !isRetry) {
        if (kDebugMode) {
          debugPrint('startVeriffVerificationAndPersist: 401 — refresh + setAuth + retry');
        }
        try {
          await _client.auth.refreshSession();
        } catch (err) {
          if (kDebugMode) debugPrint('startVeriffVerificationAndPersist: retry refresh failed: $err');
        }
        return _invokeCreateDriverVeriffSession(isRetry: true);
      }
      if (kDebugMode) debugPrint('startVeriffVerificationAndPersist: $e');
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('startVeriffVerificationAndPersist: $e');
      return null;
    }
  }

  /// Claim a swap ride. Calls fn_claim_swap_ride RPC. Returns true on success.
  /// Backend: fn_claim_swap_ride(p_post_id uuid, p_claiming_driver_id uuid)
  Future<bool> claimSwapRide(String driverId, String postId) async {
    try {
      await _client.rpc('fn_claim_swap_ride', params: {
        'p_post_id': postId,
        'p_claiming_driver_id': driverId,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Confirm a swap ride. Backend fn_confirm_swap_ride expects (p_post_id, p_passenger_response)
  /// — used when passenger responds to the swap. Driver claim flow uses claimSwapRide only.
  Future<bool> confirmSwapRide(String postId, String passengerResponse) async {
    try {
      await _client.rpc('fn_confirm_swap_ride', params: {
        'p_post_id': postId,
        'p_passenger_response': passengerResponse,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Rides assigned to this driver (for swap post creation).
  Future<List<ScheduledRide>> getDriverAssignedRides(String driverId, {int limit = 20}) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final res = await _client
          .from('ride_requests')
          .select(
            'id, pickup_address, destination_address, scheduled_pickup_at, '
            'offered_fare, estimated_distance_km, booking_mode, rider_identity_id, '
            'rider_preride_request_sent_at, rider_preride_deadline, rider_preride_confirmed, '
            'preride_commitment_fee_euros, commitment_fee_tikkie_url, commitment_fee_received, '
            'driver_preride_released_at, status',
          )
          .eq('driver_id', driverId)
          .neq('status', 'cancelled')
          .gte('scheduled_pickup_at', now)
          .order('scheduled_pickup_at', ascending: true)
          .limit(limit);
      final list = (res as List)
          .map((e) => _rideRequestToScheduledRide(e as Map<String, dynamic>))
          .toList();
      return _withReliabilityTiers(list);
    } catch (_) {
      return [];
    }
  }

  /// Create a community post (general/driver talk channel).
  Future<bool> createCommunityPost(String driverId, String channel, String content) async {
    final text = content.trim();
    if (text.isEmpty) return false;
    try {
      await _client.from('community_posts').insert({
        'driver_id': driverId,
        'channel': channel,
        'content': text,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Create a swap post (offer a ride to another driver).
  Future<bool> createSwapPost(String driverId, String rideRequestId, String content) async {
    try {
      await _client.from('community_posts').insert({
        'driver_id': driverId,
        'channel': 'swap',
        'content': content.trim().isNotEmpty ? content.trim() : 'Offering ride to swap',
        'ride_request_id': rideRequestId,
        'swap_status': 'open',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Marketplace ride requests (is_market=true). Optionally filter by zone.
  Future<List<ScheduledRide>> getAvailableMarketplaceRides({
    String? zoneId,
    int limit = 20,
  }) async {
    try {
      var query = _client
          .from('ride_requests')
          .select(
            'id, pickup_address, destination_address, scheduled_pickup_at, '
            'offered_fare, estimated_distance_km, zone_id',
          )
          .eq('status', 'pending')
          .eq('is_market', true);
      if (zoneId != null && zoneId.isNotEmpty) {
        query = query.eq('zone_id', zoneId);
      }
      final res = await query
          .order('created_at', ascending: false)
          .limit(limit);
      return (res as List)
          .map((e) => _rideRequestToScheduledRide(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Immediate (now) ride requests available for drivers. Uses ride_requests where
  /// status='pending'. Optionally filter by zone. May return empty if RLS restricts.
  Future<List<ScheduledRide>> getAvailableRidesNow({String? zoneId, int limit = 20}) async {
    try {
      var query = _client
          .from('ride_requests')
          .select(
            'id, pickup_address, destination_address, scheduled_pickup_at, '
            'offered_fare, estimated_distance_km, zone_id',
          )
          .eq('status', 'pending');
      if (zoneId != null && zoneId.isNotEmpty) {
        query = query.eq('zone_id', zoneId);
      }
      final res = await query
          .order('created_at', ascending: false)
          .limit(limit);
      return (res as List)
          .map((e) => _rideRequestToScheduledRide(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  ScheduledRide _rideRequestToScheduledRide(Map<String, dynamic> j) {
    DateTime? parse(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }
    return ScheduledRide(
      id: j['id'] as String? ?? '',
      pickupAddress: j['pickup_address'] as String?,
      destinationAddress: j['destination_address'] as String?,
      scheduledPickupAt: parse(j['scheduled_pickup_at']),
      estimatedFare: (j['offered_fare'] as num?)?.toDouble(),
      distanceKm: (j['estimated_distance_km'] as num?)?.toDouble(),
      bookingMode: j['booking_mode'] as String?,
      riderIdentityId: j['rider_identity_id'] as String?,
      riderPrerideRequestSentAt: parse(j['rider_preride_request_sent_at']),
      riderPrerideDeadline: parse(j['rider_preride_deadline']),
      riderPrerideConfirmed: j['rider_preride_confirmed'] as bool? ?? false,
      prerideCommitmentFeeEuros: (j['preride_commitment_fee_euros'] as num?)?.toDouble(),
      commitmentFeeTikkieUrl: j['commitment_fee_tikkie_url'] as String?,
      commitmentFeeReceived: j['commitment_fee_received'] as bool? ?? false,
      driverPrerideReleasedAt: parse(j['driver_preride_released_at']),
      status: j['status'] as String?,
    );
  }

  Future<List<ScheduledRide>> _withReliabilityTiers(List<ScheduledRide> rides) async {
    final ids = rides.map((r) => r.riderIdentityId).whereType<String>().toSet().toList();
    if (ids.isEmpty) return rides;
    try {
      final raw = await _client.rpc(
        'fn_rider_reliability_bulk',
        params: {'p_ids': ids},
      );
      if (raw == null) return rides;
      final map = Map<String, dynamic>.from(raw as Map);
      String? tierFor(String? id) {
        if (id == null) return null;
        final v = map[id];
        if (v is String) return v;
        return null;
      }
      return rides
          .map((r) => r.copyWith(riderReliabilityTier: tierFor(r.riderIdentityId)))
          .toList();
    } catch (_) {
      return rides;
    }
  }

  /// Best-effort rider push/in-app row via Edge Function `driver-agent`.
  void _notifyRiderPrerideRequest(String rideRequestId) {
    unawaited(() async {
      try {
        await _client.functions.invoke(
          'driver-agent',
          body: {
            'event': 'preride_request',
            'ride_request_id': rideRequestId,
          },
        );
      } catch (_) {}
    }());
  }

  /// Driver sends pre-ride confirmation without € commitment.
  Future<Map<String, dynamic>> driverSendPrerideNoFee(String rideRequestId) async {
    final res = await _client.rpc(
      'fn_driver_send_preride_confirmation_no_fee',
      params: {'p_ride_request_id': rideRequestId},
    );
    final map = Map<String, dynamic>.from(res as Map);
    if (map['ok'] == true) {
      _notifyRiderPrerideRequest(rideRequestId);
    }
    return map;
  }

  /// Driver sends pre-ride confirmation with €1–5 and Tikkie URL.
  Future<Map<String, dynamic>> driverSendPrerideWithFee(
    String rideRequestId, {
    required double feeEuros,
    required String tikkieUrl,
  }) async {
    final res = await _client.rpc(
      'fn_driver_send_preride_confirmation',
      params: {
        'p_ride_request_id': rideRequestId,
        'p_fee_euros': feeEuros,
        'p_tikkie_url': tikkieUrl,
      },
    );
    final map = Map<String, dynamic>.from(res as Map);
    if (map['ok'] == true) {
      _notifyRiderPrerideRequest(rideRequestId);
    }
    return map;
  }

  Future<Map<String, dynamic>> driverReleasePrerideRide(String rideRequestId) async {
    final res = await _client.rpc(
      'fn_driver_release_preride_ride',
      params: {'p_ride_request_id': rideRequestId},
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> driverMarkCommitmentFeeReceived(String rideRequestId) async {
    final res = await _client.rpc(
      'fn_driver_mark_commitment_fee_received',
      params: {'p_ride_request_id': rideRequestId},
    );
    return Map<String, dynamic>.from(res as Map);
  }

  /// Latest post from general channel for home sheet preview.
  Future<CommunityPost?> getLatestCommunityPost() async {
    try {
      final res = await _client
          .from('community_posts')
          .select('id, driver_id, content, created_at')
          .eq('channel', 'general')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res == null) return null;
      return CommunityPost.fromJson(res);
    } catch (_) {
      return null;
    }
  }
}

@immutable
class DriverEarningsSummary {
  final double todayEuros;
  final int todayRides;
  final double weekEuros;
  final int weekRides;
  final double monthEuros;
  final int monthRides;

  const DriverEarningsSummary({
    this.todayEuros = 0,
    this.todayRides = 0,
    this.weekEuros = 0,
    this.weekRides = 0,
    this.monthEuros = 0,
    this.monthRides = 0,
  });

  static DriverEarningsSummary fromJson(Map<String, dynamic> j) {
    return DriverEarningsSummary(
      todayEuros: (j['today_euros'] as num?)?.toDouble() ?? 0,
      todayRides: (j['today_rides'] as num?)?.toInt() ?? 0,
      weekEuros: (j['week_euros'] as num?)?.toDouble() ?? 0,
      weekRides: (j['week_rides'] as num?)?.toInt() ?? 0,
      monthEuros: (j['month_euros'] as num?)?.toDouble() ?? 0,
      monthRides: (j['month_rides'] as num?)?.toInt() ?? 0,
    );
  }

  String formatEuros(double v) => '€${v.toStringAsFixed(2)}';
}

@immutable
class ZoneDemand {
  final String zoneId;
  final String? zoneName;
  final double? centerLat;
  final double? centerLng;
  final double? radiusM;
  final int waitingPassengers;
  final String? demandLevel;

  const ZoneDemand({
    required this.zoneId,
    this.zoneName,
    this.centerLat,
    this.centerLng,
    this.radiusM,
    this.waitingPassengers = 0,
    this.demandLevel,
  });

  static ZoneDemand fromJson(Map<String, dynamic> j) {
    return ZoneDemand(
      zoneId: j['zone_id'] as String? ?? '',
      zoneName: j['zone_name'] as String?,
      centerLat: (j['center_lat'] as num?)?.toDouble(),
      centerLng: (j['center_lng'] as num?)?.toDouble(),
      radiusM: (j['radius_m'] as num?)?.toDouble(),
      waitingPassengers: (j['waiting_passengers'] as num?)?.toInt() ?? 0,
      demandLevel: j['demand_level'] as String?,
    );
  }
}

@immutable
class DriverRateProfile {
  final String id;
  final String driverId;
  final String profileName;
  final double baseFare;
  final double perKmRate;
  final double perMinRate;
  final double minimumFare;
  final double waitingRate;
  final bool isActive;
  final int sortOrder;
  final double? returnDiscountPct;

  const DriverRateProfile({
    required this.id,
    required this.driverId,
    required this.profileName,
    this.baseFare = 2.50,
    this.perKmRate = 2.00,
    this.perMinRate = 0.35,
    this.minimumFare = 5.00,
    this.waitingRate = 0.25,
    this.isActive = false,
    this.sortOrder = 0,
    this.returnDiscountPct,
  });

  static DriverRateProfile fromJson(Map<String, dynamic> j) {
    return DriverRateProfile(
      id: j['id'] as String? ?? '',
      driverId: j['driver_id'] as String? ?? '',
      profileName: j['profile_name'] as String? ?? 'Standaard',
      baseFare: (j['base_fare'] as num?)?.toDouble() ?? 2.50,
      perKmRate: (j['per_km_rate'] as num?)?.toDouble() ?? 2.00,
      perMinRate: (j['per_min_rate'] as num?)?.toDouble() ?? 0.35,
      minimumFare: (j['minimum_fare'] as num?)?.toDouble() ?? 5.00,
      waitingRate: (j['waiting_rate'] as num?)?.toDouble() ?? 0.25,
      isActive: j['is_active'] as bool? ?? false,
      sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      returnDiscountPct: (j['return_discount_pct'] as num?)?.toDouble(),
    );
  }

  String get ratesLine =>
      '€${perKmRate.toStringAsFixed(2)}/km · €${perMinRate.toStringAsFixed(2)}/min · €${baseFare.toStringAsFixed(2)} start';
}

@immutable
class DriverTicket {
  final String id;
  final DateTime? createdAt;
  final String status;
  final List<dynamic> messages;
  final String? rideRequestId;
  final String? zoneName;

  const DriverTicket({
    required this.id,
    this.createdAt,
    this.status = 'open',
    this.messages = const [],
    this.rideRequestId,
    this.zoneName,
  });

  static DriverTicket fromJson(Map<String, dynamic> j) {
    DateTime? parse(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }
    final msgs = j['messages'];
    return DriverTicket(
      id: j['id'] as String? ?? '',
      createdAt: parse(j['created_at']),
      status: j['status'] as String? ?? 'open',
      messages: msgs is List ? msgs : const [],
      rideRequestId: j['ride_request_id'] as String?,
      zoneName: j['zone_name'] as String?,
    );
  }

  bool get hasDriverReplied => messages.isNotEmpty;
  String get statusLabel => status == 'resolved'
      ? 'Opgelost'
      : hasDriverReplied
          ? 'In behandeling'
          : 'U heeft niet gereageerd';
}

/// One row from `driver_my_rating` / `driver_trust_scores` (migration 040).
@immutable
class DriverMyRating {
  final double? publicStars;
  final double? trustScore;
  final double? weightedAvg;
  final double? avgPunctuality;
  final double? avgCleanliness;
  final double? avgAttitude;
  final double? avgDrivingSafety;
  final double? avgCommunication;
  final int? totalValidRatings;
  final bool flagReviewNeeded;
  final String? flagReviewReason;
  final bool inProtectedWindow;
  final bool badgeConsistency;
  final bool badgeTopDriver;
  final bool badgeVeteran;

  const DriverMyRating({
    this.publicStars,
    this.trustScore,
    this.weightedAvg,
    this.avgPunctuality,
    this.avgCleanliness,
    this.avgAttitude,
    this.avgDrivingSafety,
    this.avgCommunication,
    this.totalValidRatings,
    this.flagReviewNeeded = false,
    this.flagReviewReason,
    this.inProtectedWindow = false,
    this.badgeConsistency = false,
    this.badgeTopDriver = false,
    this.badgeVeteran = false,
  });

  static DriverMyRating fromJson(Map<String, dynamic> j) {
    double? d(String k) => (j[k] as num?)?.toDouble();
    return DriverMyRating(
      publicStars: d('public_stars'),
      trustScore: d('trust_score'),
      weightedAvg: d('weighted_avg'),
      avgPunctuality: d('avg_punctuality'),
      avgCleanliness: d('avg_cleanliness'),
      avgAttitude: d('avg_attitude'),
      avgDrivingSafety: d('avg_driving_safety'),
      avgCommunication: d('avg_communication'),
      totalValidRatings: (j['total_valid_ratings'] as num?)?.toInt(),
      flagReviewNeeded: j['flag_review_needed'] as bool? ?? false,
      flagReviewReason: j['flag_review_reason'] as String?,
      inProtectedWindow: j['in_protected_window'] as bool? ?? false,
      badgeConsistency: j['badge_consistency'] as bool? ?? false,
      badgeTopDriver: j['badge_top_driver'] as bool? ?? false,
      badgeVeteran: j['badge_veteran'] as bool? ?? false,
    );
  }
}

@immutable
class DriverShiftStats {
  final DateTime? shiftStartAt;
  final DateTime? lastBreakStartAt;
  final DateTime? continuousDrivingStartedAt;
  final int shiftTotalOnlineMinutes;
  final int shiftBreakMinutes;
  final int shiftRidesToday;
  final double shiftEarningsToday;
  final double? acceptanceRate;
  final double? rating;
  final String? currentShiftId;
  final int breakReminderIntervalMinutes;
  const DriverShiftStats({
    this.shiftStartAt,
    this.lastBreakStartAt,
    this.continuousDrivingStartedAt,
    this.shiftTotalOnlineMinutes = 0,
    this.shiftBreakMinutes = 0,
    this.shiftRidesToday = 0,
    this.shiftEarningsToday = 0,
    this.acceptanceRate,
    this.rating,
    this.currentShiftId,
    this.breakReminderIntervalMinutes = 120,
  });

  static DriverShiftStats fromJson(Map<String, dynamic> j) {
    DateTime? parse(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }
    return DriverShiftStats(
      shiftStartAt: parse(j['shift_start_at']),
      lastBreakStartAt: parse(j['last_break_start_at']),
      continuousDrivingStartedAt: parse(j['continuous_driving_started_at']),
      shiftTotalOnlineMinutes: (j['shift_total_online_minutes'] as num?)?.toInt() ?? 0,
      shiftBreakMinutes: (j['shift_break_minutes'] as num?)?.toInt() ?? 0,
      shiftRidesToday: (j['shift_rides_today'] as num?)?.toInt() ?? 0,
      shiftEarningsToday: (j['shift_earnings_today'] as num?)?.toDouble() ?? 0,
      acceptanceRate: (j['acceptance_rate'] as num?)?.toDouble(),
      rating: (j['rating'] as num?)?.toDouble(),
      currentShiftId: j['current_shift_id'] as String?,
      breakReminderIntervalMinutes:
          (j['break_reminder_interval_minutes'] as num?)?.toInt() ?? 120,
    );
  }

  /// Dutch law: 4.5 hours continuous driving → 30 min break required.
  int get continuousDrivingMinutes {
    final start = continuousDrivingStartedAt;
    if (start == null) return 0;
    return DateTime.now().difference(start).inMinutes;
  }

  bool get isApproachingBreakLimit => continuousDrivingMinutes >= 195; // 3h15m
  bool get hasExceededBreakLimit => continuousDrivingMinutes >= 270; // 4.5h
}

@immutable
class ScheduledRide {
  final String id;
  final String? pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String? destinationAddress;
  final double? destinationLat;
  final double? destinationLng;
  final DateTime? scheduledPickupAt;
  final double? estimatedFare;
  final double? distanceKm;
  final String? vehicleCategory;
  /// From `ride_requests` when loading confirmed rides (swap migration 042).
  final String? status;
  final bool? swapListed;
  final DateTime? swapListedAt;
  final int? estimatedDurationMin;
  final List<String>? paymentMethods;
  final String? bookingMode;
  final String? riderIdentityId;
  final DateTime? riderPrerideRequestSentAt;
  final DateTime? riderPrerideDeadline;
  final bool riderPrerideConfirmed;
  final double? prerideCommitmentFeeEuros;
  final String? commitmentFeeTikkieUrl;
  final bool commitmentFeeReceived;
  final DateTime? driverPrerideReleasedAt;
  /// From [fn_rider_reliability_bulk]: new | reliable | amber | risk
  final String? riderReliabilityTier;

  const ScheduledRide({
    required this.id,
    this.pickupAddress,
    this.pickupLat,
    this.pickupLng,
    this.destinationAddress,
    this.destinationLat,
    this.destinationLng,
    this.scheduledPickupAt,
    this.estimatedFare,
    this.distanceKm,
    this.vehicleCategory,
    this.status,
    this.swapListed,
    this.swapListedAt,
    this.estimatedDurationMin,
    this.paymentMethods,
    this.bookingMode,
    this.riderIdentityId,
    this.riderPrerideRequestSentAt,
    this.riderPrerideDeadline,
    this.riderPrerideConfirmed = false,
    this.prerideCommitmentFeeEuros,
    this.commitmentFeeTikkieUrl,
    this.commitmentFeeReceived = false,
    this.driverPrerideReleasedAt,
    this.riderReliabilityTier,
  });

  static ScheduledRide fromJson(Map<String, dynamic> j) {
    DateTime? parse(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }
    List<String>? pay(dynamic v) {
      if (v == null) return null;
      if (v is List) return v.map((e) => e.toString()).toList();
      return null;
    }
    return ScheduledRide(
      id: j['id'] as String? ?? '',
      pickupAddress: j['pickup_address'] as String?,
      pickupLat: (j['pickup_lat'] as num?)?.toDouble(),
      pickupLng: (j['pickup_lng'] as num?)?.toDouble(),
      destinationAddress: j['destination_address'] as String?,
      destinationLat: (j['destination_lat'] as num?)?.toDouble(),
      destinationLng: (j['destination_lng'] as num?)?.toDouble(),
      scheduledPickupAt: parse(j['scheduled_pickup_at']),
      estimatedFare: (j['estimated_fare'] as num?)?.toDouble() ??
          (j['offered_fare'] as num?)?.toDouble(),
      distanceKm: (j['distance_km'] as num?)?.toDouble() ??
          (j['estimated_distance_km'] as num?)?.toDouble(),
      vehicleCategory: j['vehicle_category'] as String?,
      status: j['status'] as String?,
      swapListed: j['swap_listed'] as bool?,
      swapListedAt: parse(j['swap_listed_at']),
      estimatedDurationMin: (j['estimated_duration_min'] as num?)?.toInt(),
      paymentMethods: pay(j['payment_methods']),
      bookingMode: j['booking_mode'] as String?,
      riderIdentityId: j['rider_identity_id'] as String?,
      riderPrerideRequestSentAt: parse(j['rider_preride_request_sent_at']),
      riderPrerideDeadline: parse(j['rider_preride_deadline']),
      riderPrerideConfirmed: j['rider_preride_confirmed'] as bool? ?? false,
      prerideCommitmentFeeEuros: (j['preride_commitment_fee_euros'] as num?)?.toDouble(),
      commitmentFeeTikkieUrl: j['commitment_fee_tikkie_url'] as String?,
      commitmentFeeReceived: j['commitment_fee_received'] as bool? ?? false,
      driverPrerideReleasedAt: parse(j['driver_preride_released_at']),
      riderReliabilityTier: j['rider_reliability_tier'] as String?,
    );
  }

  ScheduledRide copyWith({
    String? id,
    String? pickupAddress,
    double? pickupLat,
    double? pickupLng,
    String? destinationAddress,
    double? destinationLat,
    double? destinationLng,
    DateTime? scheduledPickupAt,
    double? estimatedFare,
    double? distanceKm,
    String? vehicleCategory,
    String? status,
    bool? swapListed,
    DateTime? swapListedAt,
    int? estimatedDurationMin,
    List<String>? paymentMethods,
    String? bookingMode,
    String? riderIdentityId,
    DateTime? riderPrerideRequestSentAt,
    DateTime? riderPrerideDeadline,
    bool? riderPrerideConfirmed,
    double? prerideCommitmentFeeEuros,
    String? commitmentFeeTikkieUrl,
    bool? commitmentFeeReceived,
    DateTime? driverPrerideReleasedAt,
    String? riderReliabilityTier,
  }) {
    return ScheduledRide(
      id: id ?? this.id,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      scheduledPickupAt: scheduledPickupAt ?? this.scheduledPickupAt,
      estimatedFare: estimatedFare ?? this.estimatedFare,
      distanceKm: distanceKm ?? this.distanceKm,
      vehicleCategory: vehicleCategory ?? this.vehicleCategory,
      status: status ?? this.status,
      swapListed: swapListed ?? this.swapListed,
      swapListedAt: swapListedAt ?? this.swapListedAt,
      estimatedDurationMin: estimatedDurationMin ?? this.estimatedDurationMin,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      bookingMode: bookingMode ?? this.bookingMode,
      riderIdentityId: riderIdentityId ?? this.riderIdentityId,
      riderPrerideRequestSentAt: riderPrerideRequestSentAt ?? this.riderPrerideRequestSentAt,
      riderPrerideDeadline: riderPrerideDeadline ?? this.riderPrerideDeadline,
      riderPrerideConfirmed: riderPrerideConfirmed ?? this.riderPrerideConfirmed,
      prerideCommitmentFeeEuros: prerideCommitmentFeeEuros ?? this.prerideCommitmentFeeEuros,
      commitmentFeeTikkieUrl: commitmentFeeTikkieUrl ?? this.commitmentFeeTikkieUrl,
      commitmentFeeReceived: commitmentFeeReceived ?? this.commitmentFeeReceived,
      driverPrerideReleasedAt: driverPrerideReleasedAt ?? this.driverPrerideReleasedAt,
      riderReliabilityTier: riderReliabilityTier ?? this.riderReliabilityTier,
    );
  }

  /// Estimated ride duration for swap collision checks; default 30 min.
  int get effectiveDurationMin => estimatedDurationMin ?? 30;

  bool get isScheduledBooking => bookingMode == 'scheduled';

  /// ~16–40 minutes before [scheduledPickupAt], driver may send confirmation request.
  bool get canSendPrerideConfirmation {
    if (!isScheduledBooking || scheduledPickupAt == null) return false;
    if (riderPrerideRequestSentAt != null) return false;
    if (status != 'accepted' && status != 'driver_arrived' && status != 'assigned') {
      return false;
    }
    final mins = scheduledPickupAt!.difference(DateTime.now()).inMinutes;
    return mins >= 16 && mins <= 40;
  }

  bool get prerideAwaitingRider {
    if (riderPrerideRequestSentAt == null || riderPrerideConfirmed) return false;
    final d = riderPrerideDeadline;
    if (d == null) return true;
    return DateTime.now().isBefore(d);
  }

  bool get canReleaseAfterPrerideDeadline {
    if (riderPrerideRequestSentAt == null || riderPrerideConfirmed) return false;
    final d = riderPrerideDeadline;
    if (d == null) return false;
    return DateTime.now().isAfter(d);
  }

  bool get canMarkCommitmentReceived =>
      prerideCommitmentFeeEuros != null &&
      !commitmentFeeReceived &&
      riderPrerideConfirmed;

  bool get canOfferSwap {
    if (status != null && status != 'accepted' && status != 'driver_arrived') {
      return false;
    }
    final pickup = scheduledPickupAt;
    if (pickup == null) return false;
    final mins = pickup.difference(DateTime.now()).inMinutes;
    return mins > 15;
  }
}

@immutable
class DriverComment {
  final String? ratingId;
  final String? riderComment;
  final double? rating;
  final DateTime? createdAt;

  const DriverComment({
    this.ratingId,
    this.riderComment,
    this.rating,
    this.createdAt,
  });

  static DriverComment fromJson(Map<String, dynamic> j) {
    DateTime? parse(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }
    return DriverComment(
      ratingId: j['rating_id'] as String?,
      riderComment: j['rider_comment'] as String?,
      rating: (j['rider_rating_of_driver'] as num?)?.toDouble(),
      createdAt: parse(j['created_at']),
    );
  }
}

@immutable
class TodayRide {
  final String id;
  final DateTime? completedAt;
  final double? fare;
  final String? pickup;
  final String? destination;
  final String? pickupZoneName;
  final String? destinationZoneName;

  const TodayRide({
    required this.id,
    this.completedAt,
    this.fare,
    this.pickup,
    this.destination,
    this.pickupZoneName,
    this.destinationZoneName,
  });

  String get displayRoute {
    final from = pickupZoneName ?? pickup ?? '—';
    final to = destinationZoneName ?? destination ?? '—';
    return '$from → $to';
  }
}

@immutable
class CommunityPost {
  final String id;
  final String? authorDriverId;
  final String? body;
  final DateTime? createdAt;
  final String? channel;
  final String? rideRequestId;
  final String? swapStatus;

  const CommunityPost({
    required this.id,
    this.authorDriverId,
    this.body,
    this.createdAt,
    this.channel,
    this.rideRequestId,
    this.swapStatus,
  });

  bool get isSwapOpen => channel == 'swap' && rideRequestId != null && swapStatus == 'open';

  static CommunityPost fromJson(Map<String, dynamic> j) {
    DateTime? parse(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }
    return CommunityPost(
      id: j['id'] as String? ?? '',
      authorDriverId: j['driver_id'] as String?,
      body: j['content'] as String?,
      createdAt: parse(j['created_at']),
      channel: j['channel'] as String?,
      rideRequestId: j['ride_request_id'] as String?,
      swapStatus: j['swap_status'] as String?,
    );
  }
}

@immutable
class DriverProfile {
  final String? fullName;
  final String? vehiclePlate;
  final String? vehicleMake;
  final String? vehicleModel;
  final int? vehicleYear;
  final double? rating;
  final double? avgRating;
  final double? pickupDistanceMaxKm;
  final List<String>? paymentMethod;
  final bool isPetFriendly;
  final bool isWheelchairAccessible;
  final String? profilePhotoUrl;
  final bool profilePhotoLocked;
  final bool isVerifiedBadge;
  final String? profileStatus;
  final String? complianceStatus;
  final bool? congratulationsModalShown;
  final String? headingHomeZoneId;
  final String? homeCity;
  final DateTime? chauffeurspasExpiry;
  final DateTime? rijbewijsExpiry;
  final DateTime? vogExpiresAt;
  final DateTime? taxiInsuranceExpiry;
  final bool onboardingFeatureTourShown;
  final bool isFoundingDriver;
  final int? foundingNumber;

  const DriverProfile({
    this.fullName,
    this.vehiclePlate,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleYear,
    this.rating,
    this.avgRating,
    this.pickupDistanceMaxKm,
    this.paymentMethod,
    this.isPetFriendly = false,
    this.isWheelchairAccessible = false,
    this.profilePhotoUrl,
    this.profilePhotoLocked = false,
    this.isVerifiedBadge = false,
    this.profileStatus,
    this.complianceStatus,
    this.congratulationsModalShown,
    this.headingHomeZoneId,
    this.homeCity,
    this.chauffeurspasExpiry,
    this.rijbewijsExpiry,
    this.vogExpiresAt,
    this.taxiInsuranceExpiry,
    this.onboardingFeatureTourShown = false,
    this.isFoundingDriver = false,
    this.foundingNumber,
  });

  bool get hasDocumentExpired {
    final now = DateTime.now();
    for (final d in [chauffeurspasExpiry, rijbewijsExpiry, vogExpiresAt, taxiInsuranceExpiry]) {
      if (d != null && d.isBefore(now)) return true;
    }
    return false;
  }

  bool get hasDocumentExpiringWithin30Days {
    final now = DateTime.now();
    final limit = now.add(const Duration(days: 30));
    for (final d in [chauffeurspasExpiry, rijbewijsExpiry, vogExpiresAt, taxiInsuranceExpiry]) {
      if (d != null && !d.isBefore(now) && d.isBefore(limit)) return true;
    }
    return false;
  }

  static DriverProfile fromJson(Map<String, dynamic> j) {
    List<String>? parsePayment(dynamic v) {
      if (v == null) return null;
      if (v is List) return v.map((e) => e.toString()).toList();
      return null;
    }
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }
    final paymentList =
        parsePayment(j['payment_methods']) ?? parsePayment(j['payment_method']);
    return DriverProfile(
      fullName: (j['full_name'] as String?)?.trim(),
      vehiclePlate: j['vehicle_plate'] as String?,
      vehicleMake: j['vehicle_make'] as String?,
      vehicleModel: j['vehicle_model'] as String?,
      vehicleYear: (j['vehicle_year'] as num?)?.toInt(),
      rating: (j['rating'] as num?)?.toDouble(),
      avgRating: (j['avg_rating'] as num?)?.toDouble(),
      pickupDistanceMaxKm: (j['pickup_distance_max_km'] as num?)?.toDouble(),
      paymentMethod: paymentList ?? const ['cash'],
      isPetFriendly: (j['is_pet_friendly'] as bool?) ?? false,
      isWheelchairAccessible: (j['is_wheelchair_accessible'] as bool?) ?? false,
      profilePhotoUrl: j['profile_photo_url'] as String?,
      profilePhotoLocked: (j['profile_photo_locked'] as bool?) ?? false,
      isVerifiedBadge: (j['is_verified_badge'] as bool?) ?? false,
      profileStatus: j['profile_status'] as String?,
      complianceStatus: j['compliance_status'] as String?,
      congratulationsModalShown: j['congratulations_modal_shown'] as bool?,
      headingHomeZoneId: j['heading_home_zone_id'] as String?,
      homeCity: j['home_city'] as String?,
      chauffeurspasExpiry: parseDate(j['chauffeurspas_expiry']),
      rijbewijsExpiry: parseDate(j['rijbewijs_expiry']),
      vogExpiresAt: parseDate(j['vog_expires_at']),
      taxiInsuranceExpiry: parseDate(j['taxi_insurance_expiry']),
      onboardingFeatureTourShown: (j['onboarding_feature_tour_shown'] as bool?) ?? false,
      isFoundingDriver: (j['is_founding_driver'] as bool?) ?? false,
      foundingNumber: (j['founding_number'] as num?)?.toInt(),
    );
  }

  String get vehicleDisplay {
    final parts = <String>[];
    if (vehiclePlate != null && vehiclePlate!.isNotEmpty) parts.add(vehiclePlate!);
    if (vehicleMake != null) parts.add(vehicleMake!);
    if (vehicleModel != null) parts.add(vehicleModel!);
    if (vehicleYear != null) parts.add(vehicleYear.toString());
    return parts.isEmpty ? '—' : parts.join(' ');
  }

  bool get acceptsCash => paymentMethod?.contains('cash') ?? false;
  bool get acceptsTikkie => paymentMethod?.contains('tikkie') ?? false;
  bool get acceptsCard => paymentMethod?.contains('card') ?? false;
  bool get acceptsInvoice => paymentMethod?.contains('invoice') ?? false;

  /// Star rating shown in UI (prefer `avg_rating`).
  double get displayRating => avgRating ?? rating ?? 0.0;
}

/// Live compliance snapshot for driver Documents hub (Dutch Wpv 2000).
@immutable
class DriverComplianceSnapshot {
  final String? complianceStatus;
  final bool? chauffeurspasVerified;
  /// Stored pass number; when set, app treats chauffeurspas as locked.
  final String? chauffeurspasNumber;
  final DateTime? chauffeurspasExpiry;
  final bool? vogVerified;
  final bool? vogImpliedByChauffeurspas;
  final DateTime? vogExpiresAt;
  final bool? rijbewijsVerified;
  final DateTime? rijbewijsExpiry;
  final bool? taxidiplomaVerified;
  final bool? taxiInsuranceVerified;
  final DateTime? taxiInsuranceExpiry;
  final String? taxiInsurancePhotoUrl;
  final String? taxiInsuranceProvider;
  final String? taxiInsurancePolicyNumber;
  final bool? kvkVerified;
  final String? kvkNumber;
  final String? kvkBusinessName;
  final String? kvkAddress;
  final String? veriffStatus;
  final String? veriffSessionUrl;
  final String? veriffFullName;
  final DateTime? veriffIdExpiry;
  final bool? vehicleVerified;
  final String? vehicleVerificationStatus;
  final String? rdwApkVervaldatum;
  final String? rdwWamVerzekerd;
  final String? vehiclePlate;
  final String? rdwMerk;
  final String? rdwHandelsbenaming;

  const DriverComplianceSnapshot({
    this.complianceStatus,
    this.chauffeurspasVerified,
    this.chauffeurspasNumber,
    this.chauffeurspasExpiry,
    this.vogVerified,
    this.vogImpliedByChauffeurspas,
    this.vogExpiresAt,
    this.rijbewijsVerified,
    this.rijbewijsExpiry,
    this.taxidiplomaVerified,
    this.taxiInsuranceVerified,
    this.taxiInsuranceExpiry,
    this.taxiInsurancePhotoUrl,
    this.taxiInsuranceProvider,
    this.taxiInsurancePolicyNumber,
    this.kvkVerified,
    this.kvkNumber,
    this.kvkBusinessName,
    this.kvkAddress,
    this.veriffStatus,
    this.veriffSessionUrl,
    this.veriffFullName,
    this.veriffIdExpiry,
    this.vehicleVerified,
    this.vehicleVerificationStatus,
    this.rdwApkVervaldatum,
    this.rdwWamVerzekerd,
    this.vehiclePlate,
    this.rdwMerk,
    this.rdwHandelsbenaming,
  });

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  /// RDW APK field is often `YYYYMMDD` as text.
  static DateTime? parseRdwApkDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final s = raw.replaceAll(RegExp(r'\D'), '');
    if (s.length >= 8) {
      final y = int.tryParse(s.substring(0, 4));
      final m = int.tryParse(s.substring(4, 6));
      final d = int.tryParse(s.substring(6, 8));
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
    return DateTime.tryParse(raw);
  }

  DateTime? get apkExpiry => parseRdwApkDate(rdwApkVervaldatum);

  factory DriverComplianceSnapshot.fromJson(Map<String, dynamic> j) {
    return DriverComplianceSnapshot(
      complianceStatus: j['compliance_status'] as String?,
      chauffeurspasVerified: j['chauffeurspas_verified'] as bool?,
      chauffeurspasNumber: j['chauffeurspas_number'] as String?,
      chauffeurspasExpiry: _parseDate(j['chauffeurspas_expiry']),
      vogVerified: j['vog_verified'] as bool?,
      vogImpliedByChauffeurspas: j['vog_implied_by_chauffeurspas'] as bool?,
      vogExpiresAt: _parseDate(j['vog_expires_at']),
      rijbewijsVerified: j['rijbewijs_verified'] as bool?,
      rijbewijsExpiry: _parseDate(j['rijbewijs_expiry']),
      taxidiplomaVerified: j['taxidiploma_verified'] as bool?,
      taxiInsuranceVerified: j['taxi_insurance_verified'] as bool?,
      taxiInsuranceExpiry: _parseDate(j['taxi_insurance_expiry']),
      taxiInsurancePhotoUrl: j['taxi_insurance_photo_url'] as String?,
      taxiInsuranceProvider: j['taxi_insurance_provider'] as String?,
      taxiInsurancePolicyNumber: j['taxi_insurance_policy_number'] as String?,
      kvkVerified: j['kvk_verified'] as bool?,
      kvkNumber: j['kvk_number'] as String?,
      kvkBusinessName: j['kvk_business_name'] as String?,
      kvkAddress: j['kvk_address'] as String?,
      veriffStatus: j['veriff_status'] as String?,
      veriffSessionUrl: j['veriff_session_url'] as String?,
      veriffFullName: j['veriff_full_name'] as String?,
      veriffIdExpiry: _parseDate(j['veriff_id_expiry']),
      vehicleVerified: j['vehicle_verified'] as bool?,
      vehicleVerificationStatus: j['vehicle_verification_status'] as String?,
      rdwApkVervaldatum: j['rdw_apk_vervaldatum'] as String?,
      rdwWamVerzekerd: j['rdw_wam_verzekerd'] as String?,
      vehiclePlate: j['vehicle_plate'] as String?,
      rdwMerk: j['rdw_merk'] as String?,
      rdwHandelsbenaming: j['rdw_handelsbenaming'] as String?,
    );
  }

  factory DriverComplianceSnapshot.fromJsonMinimal(Map<String, dynamic> j) {
    return DriverComplianceSnapshot(
      complianceStatus: j['compliance_status'] as String?,
      chauffeurspasNumber: j['chauffeurspas_number'] as String?,
      chauffeurspasExpiry: _parseDate(j['chauffeurspas_expiry']),
      vogExpiresAt: _parseDate(j['vog_expires_at']),
      rijbewijsExpiry: _parseDate(j['rijbewijs_expiry']),
      taxiInsuranceExpiry: _parseDate(j['taxi_insurance_expiry']),
      vehiclePlate: j['vehicle_plate'] as String?,
    );
  }
}

@immutable
class ChauffeurspasVerifyOutcome {
  final bool ok;
  final String message;

  const ChauffeurspasVerifyOutcome({required this.ok, required this.message});
}

@immutable
class DriverReturnTrip {
  final String id;
  final String? rideRequestId;
  final String? pickupZoneId;
  final String? destinationZoneId;
  final String? pickupZoneName;
  final String? destinationZoneName;
  final String? destinationCity;
  final double? offeredFare;
  final double? distanceKm;
  final double? estimatedDurationMin;

  const DriverReturnTrip({
    required this.id,
    this.rideRequestId,
    this.pickupZoneId,
    this.destinationZoneId,
    this.pickupZoneName,
    this.destinationZoneName,
    this.destinationCity,
    this.offeredFare,
    this.distanceKm,
    this.estimatedDurationMin,
  });

  static DriverReturnTrip fromJson(Map<String, dynamic> j) {
    double? d(dynamic v) => (v as num?)?.toDouble();
    String? s(dynamic v) => v is String ? v : null;

    // View column names may differ; prefer common variants.
    return DriverReturnTrip(
      id: s(j['id']) ?? '',
      rideRequestId: s(j['ride_request_id']) ?? s(j['request_id']),
      pickupZoneId: s(j['pickup_zone_id']),
      destinationZoneId: s(j['destination_zone_id']) ?? s(j['dropoff_zone_id']),
      pickupZoneName: s(j['pickup_zone_name']) ?? s(j['pickup_zone']) ?? s(j['pickup_zone_display']),
      destinationZoneName: s(j['destination_zone_name']) ?? s(j['destination_zone']) ?? s(j['destination_zone_display']),
      destinationCity: s(j['destination_city']) ?? s(j['dropoff_city']) ?? s(j['city']),
      offeredFare: d(j['offered_fare']) ?? d(j['fare']) ?? d(j['final_fare']),
      distanceKm: d(j['distance_km']),
      estimatedDurationMin: d(j['estimated_duration_min']) ?? d(j['duration_min']),
    );
  }
}

@immutable
class DriverPowerCard {
  final String id;
  final String cardType;
  final String? title;
  final String? subtitle;
  final String? zoneId;
  final double? valueA;
  final double? valueB;
  final double? valueC;
  final String? actionUrl;

  const DriverPowerCard({
    required this.id,
    required this.cardType,
    this.title,
    this.subtitle,
    this.zoneId,
    this.valueA,
    this.valueB,
    this.valueC,
    this.actionUrl,
  });

  static DriverPowerCard fromJson(Map<String, dynamic> j) {
    double? d(dynamic v) => (v as num?)?.toDouble();
    return DriverPowerCard(
      id: j['id'] as String? ?? '',
      cardType: j['card_type'] as String? ?? '',
      title: j['title'] as String? ?? j['zone_name'] as String?,
      subtitle: j['subtitle'] as String?,
      zoneId: j['zone_id'] as String?,
      valueA: d(j['value_a']),
      valueB: d(j['value_b']),
      valueC: d(j['value_c']),
      actionUrl: j['action_url'] as String?,
    );
  }
}

@immutable
class UnionDashboardRow {
  final String? zoneId;
  final String? zoneName;
  final int passengersWaiting;
  final int driversOnline;
  final String? marketBalance;
  final double? avgOfferedFare;

  const UnionDashboardRow({
    this.zoneId,
    this.zoneName,
    this.passengersWaiting = 0,
    this.driversOnline = 0,
    this.marketBalance,
    this.avgOfferedFare,
  });

  static UnionDashboardRow fromJson(Map<String, dynamic> j) {
    return UnionDashboardRow(
      zoneId: j['zone_id'] as String?,
      zoneName: (j['zone_name'] as String?) ?? (j['name_display'] as String?),
      passengersWaiting: (j['passengers_waiting'] as num?)?.toInt() ?? 0,
      driversOnline: (j['drivers_online'] as num?)?.toInt() ?? 0,
      marketBalance: j['market_balance'] as String?,
      avgOfferedFare: (j['avg_offered_fare'] as num?)?.toDouble(),
    );
  }
}

@immutable
class DriverMarketSignal {
  final String id;
  final String zoneId;
  final String signalType;
  final String? description;
  final int upvotes;
  final DateTime? createdAt;

  const DriverMarketSignal({
    required this.id,
    required this.zoneId,
    required this.signalType,
    this.description,
    this.upvotes = 0,
    this.createdAt,
  });

  static DriverMarketSignal fromJson(Map<String, dynamic> j) {
    DateTime? parse(dynamic v) => v is String ? DateTime.tryParse(v) : null;
    return DriverMarketSignal(
      id: j['id'] as String? ?? '',
      zoneId: j['zone_id'] as String? ?? '',
      signalType: j['signal_type'] as String? ?? '',
      description: j['description'] as String?,
      upvotes: (j['upvotes'] as num?)?.toInt() ?? 0,
      createdAt: parse(j['created_at']),
    );
  }
}
