import 'dart:async' show Timer, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_utils/heycaby_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/marketplace_driver_offer.dart';
import '../providers/booking_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/marketplace_pricing_provider.dart';
import '../providers/nearby_category_supply_provider.dart';
import '../providers/ride_request_provider.dart';

/// Ensures a marketplace ride exists before showing the offers screen.
Future<bool> bootstrapMarketplaceRide(WidgetRef ref) async {
  final rideNotifier = ref.read(rideRequestProvider.notifier);
  final restored = await rideNotifier.tryRestoreActiveRideRequest();
  if (restored) {
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId != null) {
      await seedMarketplaceDriverInvites(rideId);
    }
    return true;
  }

  final booking = ref.read(bookingProvider);
  if (booking.pickup == null || booking.destination == null) return false;
  final created = await rideNotifier.createRide(booking);
  if (created) {
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId != null) {
      await seedMarketplaceDriverInvites(rideId);
    }
  }
  return created;
}

/// Raise rider offer while matching and re-notify drivers.
Future<bool> boostMarketplaceOffer({
  required WidgetRef ref,
  required int newEuro,
}) async {
  final rideId = ref.read(rideRequestProvider).rideRequestId;
  if (rideId == null) return false;
  ref.read(bookingProvider.notifier).setMarketplaceBidEuro(newEuro);
  try {
    await HeyCabySupabase.client.from('ride_requests').update({
      'marketplace_offered_fare': newEuro,
      ...HeyCabyRideFare.fareSnapshotForInsert(newEuro.toDouble()),
    }).eq('id', rideId);
    await seedMarketplaceDriverInvites(rideId);
    return true;
  } catch (_) {
    return false;
  }
}

/// Accept a driver offer — Supabase first (Backend Consolidation Phase A).
Future<bool> acceptMarketplaceOffer({
  required WidgetRef ref,
  required MarketplaceDriverOffer offer,
  required String rideRequestId,
}) async {
  try {
    final agreedEuro = offer.bidAmountEuro;
    await HeyCabySupabase.client.from('ride_requests').update({
      'driver_id': offer.driverId,
      'status': 'assigned',
      ...HeyCabyRideFare.fareSnapshotForInsert(agreedEuro),
    }).eq('id', rideRequestId);
    await HeyCabySupabase.client
        .from('ride_bids')
        .update({'status': 'accepted'}).eq('id', offer.id);
    ref.read(bookingProvider.notifier).setMarketplaceBidEuro(agreedEuro.round());
    ref.read(rideRequestProvider.notifier).updateStatus('assigned');
    return true;
  } catch (_) {
    return false;
  }
}

/// Notify nearby drivers (existing matching RPC — same as instant search).
Future<void> seedMarketplaceDriverInvites(String rideRequestId) async {
  try {
    await HeyCabySupabase.client.rpc(
      'fn_seed_ride_matching_batch',
      params: {
        'p_ride_request_id': rideRequestId,
        'p_batch_size': 12,
        'p_window_seconds': 30,
      },
    );
  } catch (_) {}
}

/// Rider declines an offer (best-effort status update; UI hides immediately).
Future<void> declineMarketplaceOffer({
  required MarketplaceDriverOffer offer,
}) async {
  try {
    await HeyCabySupabase.client
        .from('ride_bids')
        .update({'status': 'rejected'}).eq('id', offer.id);
  } catch (_) {
    // Local dismiss still applies if RLS blocks update.
  }
}

class MarketplaceOffersState {
  const MarketplaceOffersState({
    this.offers = const [],
    this.dismissedBidIds = const {},
    this.nearbyDriverCount = 0,
    this.driversNotifiedCount = 0,
    this.isLoading = true,
    this.error,
  });

  final List<MarketplaceDriverOffer> offers;
  final Set<String> dismissedBidIds;
  final int nearbyDriverCount;
  final int driversNotifiedCount;
  final bool isLoading;
  final Object? error;

  List<MarketplaceDriverOffer> visibleOffers(double riderOfferEuro) {
    final visible = offers
        .where((o) => o.isPending && !dismissedBidIds.contains(o.id))
        .toList()
      ..sort(
        (a, b) =>
            b.sortScore(riderOfferEuro).compareTo(a.sortScore(riderOfferEuro)),
      );
    return visible;
  }

  MarketplaceOffersState copyWith({
    List<MarketplaceDriverOffer>? offers,
    Set<String>? dismissedBidIds,
    int? nearbyDriverCount,
    int? driversNotifiedCount,
    bool? isLoading,
    Object? error,
  }) {
    return MarketplaceOffersState(
      offers: offers ?? this.offers,
      dismissedBidIds: dismissedBidIds ?? this.dismissedBidIds,
      nearbyDriverCount: nearbyDriverCount ?? this.nearbyDriverCount,
      driversNotifiedCount: driversNotifiedCount ?? this.driversNotifiedCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MarketplaceOffersNotifier extends Notifier<MarketplaceOffersState> {
  RealtimeChannel? _bidsChannel;
  Timer? _pollTimer;
  String? _rideId;

  @override
  MarketplaceOffersState build() {
    ref.onDispose(() {
      _bidsChannel?.unsubscribe();
      _pollTimer?.cancel();
    });
    return const MarketplaceOffersState(isLoading: true);
  }

  Future<void> start(String rideId) async {
    if (_rideId == rideId && _bidsChannel != null) return;
    _rideId = rideId;
    _bidsChannel?.unsubscribe();
    state = state.copyWith(isLoading: true, error: null);
    await _refreshOffers(rideId);
    await _refreshNearbyCount();
    await _refreshDriversNotified(rideId);
    _subscribe(rideId);
    _startPollingFallback(rideId);
  }

  Future<void> _refreshDriversNotified(String rideId) async {
    try {
      final rows = await HeyCabySupabase.client
          .from('ride_request_invites')
          .select('id')
          .eq('ride_request_id', rideId);
      final count = (rows as List).length;
      state = state.copyWith(
        driversNotifiedCount: count > 0 ? count : state.nearbyDriverCount,
      );
    } catch (_) {
      state = state.copyWith(driversNotifiedCount: state.nearbyDriverCount);
    }
  }

  Future<void> _refreshNearbyCount() async {
    final snap = ref.read(nearbyCategorySupplyProvider).valueOrNull;
    if (snap == null) return;
    state = state.copyWith(nearbyDriverCount: sumNearbyDriverCount(snap));
  }

  Future<void> _refreshOffers(String rideId) async {
    final riderOffer =
        ref.read(bookingProvider).marketplaceBidEuro?.toDouble() ?? 0;
    final favoriteIds = ref
            .read(favoritesProvider)
            .valueOrNull
            ?.map((f) => f.driverId)
            .toSet() ??
        {};

    try {
      final rows = await HeyCabySupabase.client.from('ride_bids').select('''
            id,
            driver_id,
            bid_amount,
            eta_minutes,
            message,
            status,
            expires_at,
            created_at,
            driver_snapshot,
            drivers:driver_id (
              full_name,
              rating,
              avg_rating,
              vehicle_make,
              vehicle_model,
              profile_photo_url
            )
          ''').eq('ride_request_id', rideId);

      final list = (rows as List<dynamic>).map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        return MarketplaceDriverOffer.fromJson(
          map,
          riderOfferEuro: riderOffer,
          isMutualFavorite: favoriteIds.contains(map['driver_id'] as String?),
        );
      }).toList();

      state = state.copyWith(offers: list, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  void _subscribe(String rideId) {
    _bidsChannel = HeyCabySupabase.client
        .channel('marketplace_offers:$rideId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ride_bids',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ride_request_id',
            value: rideId,
          ),
          callback: (_) => unawaited(_refreshOffers(rideId)),
        )
        .subscribe();
  }

  void _startPollingFallback(String rideId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_rideId != rideId) return;
      unawaited(_refreshOffers(rideId));
      unawaited(_refreshDriversNotified(rideId));
    });
  }

  void dismissLocally(String bidId) {
    state = state.copyWith(
      dismissedBidIds: {...state.dismissedBidIds, bidId},
    );
  }

  Future<void> refresh() async {
    final rideId = _rideId;
    if (rideId == null) return;
    await _refreshOffers(rideId);
    await _refreshNearbyCount();
  }
}

final marketplaceOffersProvider =
    NotifierProvider<MarketplaceOffersNotifier, MarketplaceOffersState>(
  MarketplaceOffersNotifier.new,
);
