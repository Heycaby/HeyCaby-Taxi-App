import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../constants/rider_near_term_window.dart';

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
      final scheduled = schedRaw == null
          ? null
          : DateTime.tryParse(schedRaw.toString())?.toLocal();
      final bookingMode = m['booking_mode'] as String?;
      final createdAt = DateTime.tryParse(
            (m['created_at'] ?? '').toString(),
          ) ??
          now;

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
      final scheduled = DateTime.tryParse(
        (m['scheduled_pickup_at'] ?? '').toString(),
      )?.toLocal();
      if (scheduled == null || !scheduled.isAfter(now)) continue;
      if (scheduled.difference(now) <= kRiderNearTermScheduledWindow) continue;
      final id = m['id'] as String?;
      if (id == null) continue;
      out.add(
        NearTermRideSnapshot(
          id: id,
          status: m['status'] as String? ?? 'pending',
          pickupAddress: (m['pickup_address'] as String?) ?? '',
          destinationAddress: (m['destination_address'] as String?) ?? '',
          scheduledPickupAt: scheduled,
          bookingMode: m['booking_mode'] as String?,
          createdAt: DateTime.tryParse((m['created_at'] ?? '').toString()) ?? now,
        ),
      );
    }
    return out;
  } catch (_) {
    return [];
  }
});

/// All open `ride_requests` for the Rides tab (scheduled + live matching).
/// Order: future scheduled pickups (soonest first), then live pending rows (newest first).
final ridesTabUpcomingRequestsProvider =
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
        .order('created_at', ascending: false)
        .limit(40);

    final list = rows as List<dynamic>;
    final now = DateTime.now();
    final snaps = <NearTermRideSnapshot>[];
    for (final raw in list) {
      final m = Map<String, dynamic>.from(raw as Map);
      final id = m['id'] as String?;
      if (id == null) continue;
      final schedRaw = m['scheduled_pickup_at'];
      final scheduled = schedRaw == null
          ? null
          : DateTime.tryParse(schedRaw.toString())?.toLocal();
      snaps.add(
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

    final futureSched = snaps
        .where(
          (s) =>
              s.scheduledPickupAt != null && s.scheduledPickupAt!.isAfter(now),
        )
        .toList()
      ..sort(
        (a, b) => a.scheduledPickupAt!.compareTo(b.scheduledPickupAt!),
      );

    final live = snaps
        .where(
          (s) =>
              s.scheduledPickupAt == null || !s.scheduledPickupAt!.isAfter(now),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return [...futureSched, ...live];
  } catch (_) {
    return [];
  }
});
