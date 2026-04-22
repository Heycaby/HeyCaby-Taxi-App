import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ride swap (migration 042) — aligned with live Supabase RPCs:
/// `offer_ride_swap`, `can_driver_take_swap`, `claim_ride_swap`, `cancel_ride_swap`
/// (underscore-prefixed args only). Passenger push / emergency paging are server-side.
///
/// Open listing from `ride_swaps` (migration 042).
@immutable
class RideSwapListing {
  const RideSwapListing({
    required this.id,
    required this.urgency,
    required this.status,
    this.pickupAt,
    this.swapExpiresAt,
    this.pickupAddress,
    this.destinationAddress,
    this.pickupLat,
    this.pickupLng,
    this.estimatedDistanceKm,
    this.estimatedDurationMin,
    this.rideType,
    this.paymentMethods,
    this.offeredFare,
    this.rideRequestId,
  });

  final String id;
  final String urgency;
  final String status;
  final DateTime? pickupAt;
  final DateTime? swapExpiresAt;
  final String? pickupAddress;
  final String? destinationAddress;
  final double? pickupLat;
  final double? pickupLng;
  final double? estimatedDistanceKm;
  final int? estimatedDurationMin;
  final String? rideType;
  final List<String>? paymentMethods;
  final double? offeredFare;
  final String? rideRequestId;

  static RideSwapListing? fromRow(Map<String, dynamic> j) {
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

    try {
      return RideSwapListing(
        id: j['id'] as String,
        urgency: (j['urgency'] as String?) ?? 'standard',
        status: (j['status'] as String?) ?? 'open',
        pickupAt: parse(j['pickup_at']),
        swapExpiresAt: parse(j['swap_expires_at']),
        pickupAddress: j['pickup_address'] as String?,
        destinationAddress: j['destination_address'] as String?,
        pickupLat: (j['pickup_lat'] as num?)?.toDouble(),
        pickupLng: (j['pickup_lng'] as num?)?.toDouble(),
        estimatedDistanceKm: (j['estimated_distance_km'] as num?)?.toDouble(),
        estimatedDurationMin: (j['estimated_duration_min'] as num?)?.toInt(),
        rideType: j['ride_type'] as String?,
        paymentMethods: pay(j['payment_methods']),
        offeredFare: (j['offered_fare'] as num?)?.toDouble() ??
            (j['estimated_fare'] as num?)?.toDouble(),
        rideRequestId: j['ride_request_id'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static int urgencyRank(String u) {
    switch (u.toLowerCase()) {
      case 'emergency':
        return 0;
      case 'urgent':
        return 1;
      case 'moderate':
        return 2;
      case 'standard':
        return 3;
      default:
        return 4;
    }
  }
}

/// Haversine distance in km.
double distanceKmToPickup(double? driverLat, double? driverLng, double? pickupLat, double? pickupLng) {
  if (driverLat == null || driverLng == null || pickupLat == null || pickupLng == null) {
    return double.infinity;
  }
  const r = 6371.0;
  final dLat = _rad(pickupLat - driverLat);
  final dLng = _rad(pickupLng - driverLng);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(driverLat)) * math.cos(_rad(pickupLat)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

double _rad(double d) => d * math.pi / 180.0;

/// RPC + queries for migration 042 `ride_swaps` API.
class RideSwapService {
  RideSwapService({SupabaseClient? client}) : _client = client ?? HeyCabySupabase.client;

  final SupabaseClient _client;

  Map<String, dynamic>? _asMap(dynamic r) {
    if (r == null) return null;
    if (r is Map<String, dynamic>) return r;
    if (r is Map) return Map<String, dynamic>.from(r);
    return null;
  }

  /// Open swaps for the feed (not expired).
  Future<List<RideSwapListing>> fetchOpenSwaps({int limit = 100}) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final res = await _client
          .from('ride_swaps')
          .select(
            'id, urgency, status, pickup_at, swap_expires_at, '
            'pickup_address, destination_address, pickup_lat, pickup_lng, '
            'estimated_distance_km, estimated_duration_min, ride_type, payment_methods, '
            'ride_request_id',
          )
          .eq('status', 'open')
          .gt('swap_expires_at', now)
          .order('pickup_at', ascending: true)
          .limit(limit);
      final list = <RideSwapListing>[];
      for (final e in res as List) {
        final row = RideSwapListing.fromRow(e as Map<String, dynamic>);
        if (row != null) list.add(row);
      }
      return list;
    } catch (e) {
      if (kDebugMode) debugPrint('fetchOpenSwaps: $e');
      return [];
    }
  }

  /// Open swap row for this ride (for cancel). Returns null if none.
  Future<String?> fetchOpenSwapIdForRide({
    required String offeringDriverId,
    required String rideRequestId,
  }) async {
    try {
      final res = await _client
          .from('ride_swaps')
          .select('id')
          .eq('ride_request_id', rideRequestId)
          .eq('offering_driver_id', offeringDriverId)
          .eq('status', 'open')
          .maybeSingle();
      return res?['id'] as String?;
    } catch (e) {
      if (kDebugMode) debugPrint('fetchOpenSwapIdForRide: $e');
      return null;
    }
  }

  /// Sort: urgency rank → pickup time → distance (urgent/emergency only for distance).
  List<RideSwapListing> sortForFeed(
    List<RideSwapListing> raw, {
    double? driverLat,
    double? driverLng,
  }) {
    final copy = List<RideSwapListing>.from(raw);
    copy.sort((a, b) {
      final ra = RideSwapListing.urgencyRank(a.urgency);
      final rb = RideSwapListing.urgencyRank(b.urgency);
      if (ra != rb) return ra.compareTo(rb);
      final ta = a.pickupAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.pickupAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (ta != tb) return ta.compareTo(tb);
      final ua = a.urgency.toLowerCase();
      if (ua == 'urgent' || ua == 'emergency') {
        final da = distanceKmToPickup(driverLat, driverLng, a.pickupLat, a.pickupLng);
        final db = distanceKmToPickup(driverLat, driverLng, b.pickupLat, b.pickupLng);
        return da.compareTo(db);
      }
      return 0;
    });
    return copy;
  }

  Future<Map<String, dynamic>?> offerRideSwap({
    required String driverId,
    required String rideId,
    required String reason,
    String? detail,
  }) async {
    try {
      final params = <String, dynamic>{
        '_driver_id': driverId,
        '_ride_id': rideId,
        '_reason': reason,
      };
      if (detail != null && detail.trim().isNotEmpty) {
        params['_detail'] = detail.trim();
      }
      final r = await _client.rpc('offer_ride_swap', params: params);
      return _asMap(r);
    } catch (e) {
      if (kDebugMode) debugPrint('offer_ride_swap: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> canDriverTakeSwap({
    required String driverId,
    required DateTime pickupAt,
    required int estimatedDurationMin,
  }) async {
    try {
      final r = await _client.rpc(
        'can_driver_take_swap',
        params: {
          '_driver_id': driverId,
          '_pickup_at': pickupAt.toUtc().toIso8601String(),
          '_est_duration': estimatedDurationMin,
        },
      );
      return _asMap(r);
    } catch (e) {
      if (kDebugMode) debugPrint('can_driver_take_swap: $e');
      return null;
    }
  }

  /// [claimerId] must be `drivers.id` (same as [driverIdProvider]).
  Future<Map<String, dynamic>?> claimRideSwap({
    required String claimerId,
    required String swapId,
  }) async {
    try {
      final r = await _client.rpc(
        'claim_ride_swap',
        params: {
          '_claimer_id': claimerId,
          '_swap_id': swapId,
        },
      );
      return _asMap(r);
    } catch (e) {
      if (kDebugMode) debugPrint('claim_ride_swap: $e');
      return null;
    }
  }

  /// Withdraw an open listing (offering driver only). [driverId] = `drivers.id`.
  Future<Map<String, dynamic>?> cancelRideSwap({
    required String driverId,
    required String swapId,
  }) async {
    try {
      final r = await _client.rpc(
        'cancel_ride_swap',
        params: {
          '_driver_id': driverId,
          '_swap_id': swapId,
        },
      );
      return _asMap(r);
    } catch (e) {
      if (kDebugMode) debugPrint('cancel_ride_swap: $e');
      return null;
    }
  }
}
