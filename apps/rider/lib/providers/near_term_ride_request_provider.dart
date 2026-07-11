import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../constants/rider_near_term_window.dart';
import '../constants/rider_rides_status_contract.dart';
import '../constants/rider_search_window.dart';
import '../services/rider_my_rides_service.dart';
import '../services/stale_ride_cleanup.dart';

DateTime? _parseScheduledPickup(dynamic raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString())?.toLocal();
}

bool _isFutureScheduledRide(DateTime? scheduledPickupAt, DateTime now) =>
    scheduledPickupAt != null && scheduledPickupAt.isAfter(now);

/// Instant/marketplace live search expires after [kRiderDriverSearchWindow].
/// Future scheduled pickups stay open until pickup or explicit cancel.
Future<bool> _expireStaleInstantRideIfNeeded({
  required String rideId,
  required String riderToken,
  required DateTime createdAt,
  required DateTime now,
  required DateTime? scheduledPickupAt,
}) async {
  if (_isFutureScheduledRide(scheduledPickupAt, now)) return false;
  if (now.difference(createdAt) <= kRiderDriverSearchWindow) return false;
  await cancelExpiredRiderOpenRide(
    rideId: rideId,
    riderToken: riderToken,
  );
  return true;
}

/// Open `ride_requests` row worth highlighting on Home (matching soon or scheduled soon).
class NearTermRideSnapshot {
  final String id;
  final String status;
  final String pickupAddress;
  final String destinationAddress;
  final DateTime? scheduledPickupAt;
  final String? bookingMode;
  final DateTime createdAt;

  const NearTermRideSnapshot({
    required this.id,
    required this.status,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.scheduledPickupAt,
    required this.bookingMode,
    required this.createdAt,
  });

  static const liveStatuses = {
    'assigned',
    'accepted',
    'driver_found',
    'driver_en_route',
    'driver_arrived',
    'arrived',
    'in_progress',
  };

  bool get isLiveRide {
    if (scheduledPickupAt?.isAfter(DateTime.now()) ?? false) return false;
    return liveStatuses.contains(status);
  }

  bool get isMatching => status == 'pending' || status == 'bidding';
}

/// Fetches the best candidate ride_request for the home banner (near-term only).
final nearTermRideRequestProvider =
    FutureProvider.autoDispose<NearTermRideSnapshot?>((ref) async {
  final identity = await ref.watch(riderIdentityProvider.future);
  if (!identity.hasSession || identity.riderToken == null) return null;

  try {
    final rows = await HeyCabySupabase.client
        .from('ride_requests')
        .select(
          'id, status, pickup_address, destination_address, scheduled_pickup_at, booking_mode, created_at',
        )
        .eq('rider_token', identity.riderToken!)
        .inFilter('status', ['pending', 'bidding'])
        .order('created_at', ascending: false)
        .limit(8);

    final list = rows as List<dynamic>;
    if (list.isEmpty) return null;
    final now = DateTime.now();

    for (final raw in list) {
      final m = Map<String, dynamic>.from(raw as Map);
      final id = m['id'] as String?;
      final status = m['status'] as String?;
      if (id == null || status == null) continue;
      final pickup = (m['pickup_address'] as String?) ?? '';
      final dest = (m['destination_address'] as String?) ?? '';
      final schedRaw = m['scheduled_pickup_at'];
      final scheduled = _parseScheduledPickup(schedRaw);
      final bookingMode = m['booking_mode'] as String?;
      final createdAt = DateTime.tryParse(
            (m['created_at'] ?? '').toString(),
          ) ??
          now;
      if (await _expireStaleInstantRideIfNeeded(
        rideId: id,
        riderToken: identity.riderToken!,
        createdAt: createdAt,
        now: now,
        scheduledPickupAt: scheduled,
      )) {
        continue;
      }

      if (scheduled == null) {
        return NearTermRideSnapshot(
          id: id,
          status: status,
          pickupAddress: pickup,
          destinationAddress: dest,
          scheduledPickupAt: null,
          bookingMode: bookingMode,
          createdAt: createdAt,
        );
      }

      if (scheduled.isBefore(now)) continue;

      final untilPickup = scheduled.difference(now);
      if (untilPickup <= kRiderNearTermScheduledWindow) {
        return NearTermRideSnapshot(
          id: id,
          status: status,
          pickupAddress: pickup,
          destinationAddress: dest,
          scheduledPickupAt: scheduled,
          bookingMode: bookingMode,
          createdAt: createdAt,
        );
      }
    }
    return null;
  } catch (_) {
    return null;
  }
});

/// Scheduled matching rows farther than [kRiderNearTermScheduledWindow] (for Rides tab section).
final farFutureScheduledRideRequestsProvider =
    FutureProvider.autoDispose<List<NearTermRideSnapshot>>((ref) async {
  final identity = await ref.watch(riderIdentityProvider.future);
  if (!identity.hasSession || identity.riderToken == null) return [];

  try {
    final rows = await HeyCabySupabase.client
        .from('ride_requests')
        .select(
          'id, status, pickup_address, destination_address, scheduled_pickup_at, booking_mode, created_at',
        )
        .eq('rider_token', identity.riderToken!)
        .inFilter('status', ['pending', 'bidding'])
        .order('scheduled_pickup_at', ascending: true)
        .limit(40);

    final list = rows as List<dynamic>;
    final now = DateTime.now();
    final out = <NearTermRideSnapshot>[];
    for (final raw in list) {
      final m = Map<String, dynamic>.from(raw as Map);
      final id = m['id'] as String?;
      if (id == null) continue;
      final createdAt =
          DateTime.tryParse((m['created_at'] ?? '').toString()) ?? now;
      final scheduled = _parseScheduledPickup(m['scheduled_pickup_at']);
      if (await _expireStaleInstantRideIfNeeded(
        rideId: id,
        riderToken: identity.riderToken!,
        createdAt: createdAt,
        now: now,
        scheduledPickupAt: scheduled,
      )) {
        continue;
      }
      if (scheduled == null || !scheduled.isAfter(now)) continue;
      if (scheduled.difference(now) <= kRiderNearTermScheduledWindow) continue;
      out.add(
        NearTermRideSnapshot(
          id: id,
          status: m['status'] as String? ?? 'pending',
          pickupAddress: (m['pickup_address'] as String?) ?? '',
          destinationAddress: (m['destination_address'] as String?) ?? '',
          scheduledPickupAt: scheduled,
          bookingMode: m['booking_mode'] as String?,
          createdAt:
              DateTime.tryParse((m['created_at'] ?? '').toString()) ?? now,
        ),
      );
    }
    return out;
  } catch (_) {
    return [];
  }
});

/// All open `ride_requests` for the Rides tab (live trip, matching, scheduled).
/// Order: live trips, future scheduled (soonest first), then matching (newest first).
final ridesTabUpcomingRequestsProvider =
    FutureProvider.autoDispose<List<NearTermRideSnapshot>>((ref) async {
  final identity = await ref.watch(riderIdentityProvider.future);
  if (!identity.hasSession || identity.riderToken == null) return [];

  try {
    final rows = await const RiderMyRidesService().fetchAll(scope: 'upcoming');
    final list = rows
        .where((row) => riderUpcomingRideStatuses.contains(row['status']))
        .toList();
    final now = DateTime.now();
    final snaps = <NearTermRideSnapshot>[];
    for (final raw in list) {
      final m = Map<String, dynamic>.from(raw as Map);
      final id = m['id'] as String?;
      if (id == null) continue;
      final createdAt =
          DateTime.tryParse((m['created_at'] ?? '').toString()) ?? now;
      final scheduled = _parseScheduledPickup(m['scheduled_pickup_at']);
      final status = m['status'] as String? ?? 'pending';
      snaps.add(
        NearTermRideSnapshot(
          id: id,
          status: status,
          pickupAddress: (m['pickup_address'] as String?) ?? '',
          destinationAddress: (m['destination_address'] as String?) ?? '',
          scheduledPickupAt: scheduled,
          bookingMode: m['booking_mode'] as String?,
          createdAt: createdAt,
        ),
      );
    }

    final live = snaps.where((s) => s.isLiveRide).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final futureSched = snaps
        .where(
          (s) =>
              !s.isLiveRide &&
              s.scheduledPickupAt != null &&
              s.scheduledPickupAt!.isAfter(now),
        )
        .toList()
      ..sort(
        (a, b) => a.scheduledPickupAt!.compareTo(b.scheduledPickupAt!),
      );

    final matching = snaps
        .where(
          (s) =>
              !s.isLiveRide &&
              (s.scheduledPickupAt == null ||
                  !s.scheduledPickupAt!.isAfter(now)),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return [...live, ...futureSched, ...matching];
  } catch (_) {
    rethrow;
  }
});
