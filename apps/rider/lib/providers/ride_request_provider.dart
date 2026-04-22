import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_models/heycaby_models.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../constants/rider_search_window.dart';
import '../models/ride_matching_variant.dart';
import '../services/booking_draft_storage.dart';
import '../services/sound_service.dart';
import '../services/heycaby_widget_sync.dart';
import '../services/nearby_supply_service.dart';
import '../services/stale_ride_cleanup.dart';
import '../utils/wkt_point.dart';
import 'booking_provider.dart';

class RideRequestState {
  final bool isLoading;
  final String? rideRequestId;
  final String? status;
  final String? error;
  /// Server `created_at` for the current ride (used for 30 min search window).
  final DateTime? rideCreatedAt;
  /// Server `booking_mode`: instant | marketplace | scheduled (for matching route + UI).
  final String? bookingMode;

  const RideRequestState({
    this.isLoading = false,
    this.rideRequestId,
    this.status,
    this.error,
    this.rideCreatedAt,
    this.bookingMode,
  });

  RideRequestState copyWith({
    bool? isLoading,
    String? rideRequestId,
    String? status,
    String? error,
    DateTime? rideCreatedAt,
    String? bookingMode,
  }) =>
      RideRequestState(
        isLoading: isLoading ?? this.isLoading,
        rideRequestId: rideRequestId ?? this.rideRequestId,
        status: status ?? this.status,
        error: error ?? this.error,
        rideCreatedAt: rideCreatedAt ?? this.rideCreatedAt,
        bookingMode: bookingMode ?? this.bookingMode,
      );

  /// Pending / bidding rides older than [kRiderDriverSearchWindow] should not block the app.
  bool get isOpenSearchStale {
    if (rideCreatedAt == null || rideRequestId == null) return false;
    final s = status;
    if (s != 'pending' && s != 'bidding') return false;
    return DateTime.now().difference(rideCreatedAt!) > kRiderDriverSearchWindow;
  }
}

DateTime? _parseCreatedAt(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  return DateTime.tryParse(raw.toString());
}

String _normalizeAddressForMatch(String? s) {
  if (s == null) return '';
  return s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// Maps rider `vehicleCategory` keys to `drivers.vehicle_category` / `ride_requests` values.
String _rideRequestVehicleCategory(String? riderKey) {
  switch (riderKey) {
    case 'comfort':
      return 'comfort';
    case 'taxibus':
      return 'taxibus';
    case 'wheelchair':
      return 'wheelchair';
    case 'standard':
    default:
      return 'standard';
  }
}

class RideRequestNotifier extends Notifier<RideRequestState> {
  @override
  RideRequestState build() => const RideRequestState();

  /// When opening [SearchingScreen], restore an in-progress ride from Supabase
  /// so cold start / deep link does not create a duplicate request.
  /// Stale open searches (pending/bidding beyond [kRiderDriverSearchWindow]) are cancelled and ignored.
  Future<bool> tryRestoreActiveRideRequest() async {
    if (state.rideRequestId != null) return true;
    final identity = await ref.read(riderIdentityProvider.future);
    if (!identity.hasSession || identity.riderToken == null) return false;
    try {
      final activeRide = await HeyCabySupabase.client
          .from('ride_requests')
          .select(
            'id, status, created_at, booking_mode, pickup_address, destination_address',
          )
          .eq('rider_token', identity.riderToken!)
          .inFilter('status', [
            'pending',
            'bidding',
            'accepted',
            'driver_arrived',
            'in_progress',
          ])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (activeRide == null) return false;

      final id = activeRide['id'] as String?;
      final status = activeRide['status'] as String?;
      final createdAt = _parseCreatedAt(activeRide['created_at']);
      final bookingMode = activeRide['booking_mode'] as String?;
      final pickupAddrDb = activeRide['pickup_address'] as String?;
      final destAddrDb = activeRide['destination_address'] as String?;

      if (id == null || status == null) return false;

      final booking = ref.read(bookingProvider);
      if (status == 'pending' || status == 'bidding') {
        if (pickupAddrDb != null &&
            destAddrDb != null &&
            booking.pickup != null &&
            booking.destination != null) {
          final puMatch = _normalizeAddressForMatch(pickupAddrDb) ==
              _normalizeAddressForMatch(booking.pickup!.fullAddress);
          final deMatch = _normalizeAddressForMatch(destAddrDb) ==
              _normalizeAddressForMatch(booking.destination!.fullAddress);
          if (!puMatch || !deMatch) {
            await cancelExpiredRiderOpenRide(
              rideId: id,
              riderToken: identity.riderToken!,
              cancellationReason: 'new_booking_started',
            );
            return false;
          }
        }
        // Only compare booking_mode when local draft has addresses — otherwise we
        // would cancel the server ride when opening matching from Rides tab (empty booking).
        if (booking.pickup != null && booking.destination != null) {
          final dbMode = (bookingMode ?? '').trim();
          if (dbMode.isNotEmpty &&
              dbMode != bookingModeStorageString(booking.effectiveRideMode)) {
            await cancelExpiredRiderOpenRide(
              rideId: id,
              riderToken: identity.riderToken!,
              cancellationReason: 'new_booking_started',
            );
            return false;
          }
        }
      }

      if (createdAt != null &&
          (status == 'pending' || status == 'bidding')) {
        if (DateTime.now().difference(createdAt) > kRiderDriverSearchWindow) {
          await cancelExpiredRiderOpenRide(
            rideId: id,
            riderToken: identity.riderToken!,
          );
          return false;
        }
      }

      final resolvedBookingMode =
          (bookingMode != null && bookingMode.trim().isNotEmpty)
              ? bookingMode.trim()
              : bookingModeStorageString(booking.effectiveRideMode);

      state = state.copyWith(
        rideRequestId: id,
        status: status,
        rideCreatedAt: createdAt ??
            ((status == 'pending' || status == 'bidding') ? DateTime.now() : null),
        bookingMode: resolvedBookingMode,
      );
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('tryRestoreActiveRideRequest: $e');
      return false;
    }
  }

  /// Cancels a pending/bidding ride that exceeded the search window, then clears local state.
  Future<void> cancelStaleOpenRequest() async {
    final id = state.rideRequestId;
    final identity = await ref.read(riderIdentityProvider.future);
    final token = identity.riderToken;
    if (id != null && token != null) {
      await cancelExpiredRiderOpenRide(rideId: id, riderToken: token);
    }
    reset();
  }

  // Ride creation ONLY happens here — triggered from [SearchingScreen] after navigation.
  Future<bool> createRide(BookingState booking) async {
    if (booking.pickup == null || booking.destination == null) {
      if (kDebugMode) debugPrint('CreateRide failed: pickup or destination is null');
      return false;
    }
    if (booking.effectiveRideMode == BookingMode.marketplace &&
        (booking.marketplaceBidEuro == null || booking.marketplaceBidEuro! <= 0)) {
      if (kDebugMode) {
        debugPrint('CreateRide failed: marketplace requires marketplaceBidEuro');
      }
      return false;
    }
    if (state.isLoading) {
      if (kDebugMode) debugPrint('CreateRide failed: already loading');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final identity = await ref.read(riderIdentityProvider.future);

      final supabase = HeyCabySupabase.client;

      // Format coordinates for PostGIS geography type (longitude FIRST)
      final pickupLng = booking.pickup!.lng;
      final pickupLat = booking.pickup!.lat;
      final destLng = booking.destination!.lng;
      final destLat = booking.destination!.lat;

      final tripKm = NearbySupplyService.distanceKm(
        pickupLat,
        pickupLng,
        destLat,
        destLng,
      );
      final durationMin = (tripKm / 0.5).ceil().clamp(1, 480);

      final body = <String, dynamic>{
        // PostGIS geography coordinates - POINT(lng lat)
        'pickup_coords': 'POINT($pickupLng $pickupLat)',
        'destination_coords': 'POINT($destLng $destLat)',

        // Address strings
        'pickup_address': booking.pickup!.fullAddress,
        'destination_address': booking.destination!.fullAddress,

        // Status must be a valid enum value
        'status': 'pending',

        // Matching (see supabase/migrations/20260329180000_ride_matching_cascade.sql)
        'booking_mode': bookingModeStorageString(booking.effectiveRideMode),
        'vehicle_category': _rideRequestVehicleCategory(
          booking.vehicleCategories.isNotEmpty
              ? booking.vehicleCategories.first
              : booking.vehicleCategory,
        ),
        if (booking.vehicleCategories.isNotEmpty)
          'vehicle_categories': booking.vehicleCategories
              .map(_rideRequestVehicleCategory)
              .toList(),
        'pet_friendly': booking.petFriendly,
        'estimated_distance_km': tripKm,
        'estimated_duration_min': durationMin,

        // Optional fields
        if (booking.pickupContactName != null &&
            booking.pickupContactName!.isNotEmpty)
          'pickup_contact_name': booking.pickupContactName,
        if (booking.scheduledAt != null)
          'scheduled_pickup_at': booking.scheduledAt!.toIso8601String(),
        if (identity.riderToken != null) 'rider_token': identity.riderToken,
        if (identity.identityId != null)
          'rider_identity_id': identity.identityId,
        // Marketplace: DB chk_marketplace_requires_fare → marketplace_offered_fare NOT NULL
        if (booking.effectiveRideMode == BookingMode.marketplace)
          ...<String, dynamic>{
            'marketplace_offered_fare': booking.marketplaceBidEuro!,
            'offered_fare': booking.marketplaceBidEuro,
          },
        if (booking.effectiveRideMode != BookingMode.marketplace &&
            booking.estimatedFareEuro != null)
          'offered_fare': booking.estimatedFareEuro,

        // Direct dispatch: target a specific driver (1 driver per job enforced by DB)
        if (booking.selectedDriverId != null)
          'preferred_driver_id': booking.selectedDriverId,
        if (booking.paymentMethods.isNotEmpty)
          'payment_methods': booking.paymentMethods,
        'favorites_first': booking.favoritesFirst,
      };

      // Save booking name progressively if newly entered
      if (booking.pickupContactName != null &&
          booking.pickupContactName!.isNotEmpty &&
          identity.bookingName == null) {
        await ref
            .read(riderIdentityProvider.notifier)
            .saveBookingName(booking.pickupContactName!);
      }

      final response = await supabase
          .from('ride_requests')
          .insert(body)
          .select('id, status, created_at, booking_mode')
          .single();

      state = state.copyWith(
        isLoading: false,
        rideRequestId: response['id'] as String?,
        status: response['status'] as String?,
        rideCreatedAt: _parseCreatedAt(response['created_at']) ?? DateTime.now(),
        bookingMode: response['booking_mode'] as String? ??
            bookingModeStorageString(booking.effectiveRideMode),
      );

      // Confirm booking with sound + haptic
      SoundService().playBookingCreated();
      HapticService.success();
      await BookingDraftStorage.clear();

      return true;
    } catch (e, stackTrace) {
      debugPrint('CreateRide error: $e');
      if (kDebugMode) {
        debugPrint('CreateRide stack trace: $stackTrace');
      }
      state = state.copyWith(
        isLoading: false,
        error: 'ride_creation_failed',
      );
      return false;
    }
  }

  /// Loads a specific `ride_requests` row for the matching UIs (from Rides → trip details).
  /// Clears prior ride state, then hydrates [bookingProvider] from server addresses/coords.
  Future<bool> attachRideRequestForMatchingFlow(String rideRequestId) async {
    final identity = await ref.read(riderIdentityProvider.future);
    if (!identity.hasSession || identity.riderToken == null) return false;
    reset();
    try {
      final row = await HeyCabySupabase.client
          .from('ride_requests')
          .select(
            'id, status, created_at, booking_mode, pickup_address, destination_address, '
            'scheduled_pickup_at, pickup_coords, destination_coords, marketplace_offered_fare',
          )
          .eq('id', rideRequestId)
          .eq('rider_token', identity.riderToken!)
          .maybeSingle();
      if (row == null) return false;
      final m = Map<String, dynamic>.from(row as Map);
      final id = m['id'] as String?;
      final status = m['status'] as String?;
      if (id == null || status == null) return false;

      state = state.copyWith(
        rideRequestId: id,
        status: status,
        bookingMode: (m['booking_mode'] as String?)?.trim(),
        rideCreatedAt: _parseCreatedAt(m['created_at']) ??
            ((status == 'pending' || status == 'bidding')
                ? DateTime.now()
                : null),
      );
      _hydrateBookingFromRideRequestRow(m);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('attachRideRequestForMatchingFlow: $e');
      return false;
    }
  }

  void _hydrateBookingFromRideRequestRow(Map<String, dynamic> m) {
    final puAddr = (m['pickup_address'] as String?) ?? '';
    final deAddr = (m['destination_address'] as String?) ?? '';
    final puCoord = parseWktPoint(m['pickup_coords']);
    final deCoord = parseWktPoint(m['destination_coords']);

    String firstLine(String a) {
      final t = a.trim();
      if (t.isEmpty) return '—';
      final i = t.indexOf('\n');
      return i < 0 ? t : t.substring(0, i).trim();
    }

    final pu = AddressResult(
      displayName: firstLine(puAddr),
      fullAddress: puAddr,
      lat: puCoord.$2 ?? 0,
      lng: puCoord.$1 ?? 0,
    );
    final de = AddressResult(
      displayName: firstLine(deAddr),
      fullAddress: deAddr,
      lat: deCoord.$2 ?? 0,
      lng: deCoord.$1 ?? 0,
    );

    final modeStr = (m['booking_mode'] as String?) ?? 'instant';
    BookingMode mode;
    switch (modeStr) {
      case 'marketplace':
        mode = BookingMode.marketplace;
        break;
      case 'scheduled':
        mode = BookingMode.scheduled;
        break;
      default:
        mode = BookingMode.instant;
    }

    DateTime? scheduledAt;
    final schedRaw = m['scheduled_pickup_at'];
    if (schedRaw != null) {
      scheduledAt = DateTime.tryParse(schedRaw.toString())?.toLocal();
    }

    final fareRaw = m['marketplace_offered_fare'];
    int? marketplaceBid;
    if (fareRaw is num) {
      marketplaceBid = fareRaw.round();
    }

    ref.read(bookingProvider.notifier).restoreFromDraft(
          BookingState(
            mode: mode,
            pickup: pu,
            destination: de,
            scheduledAt: scheduledAt,
            marketplaceBidEuro: marketplaceBid,
          ),
        );
  }

  void updateStatus(String status) {
    final previousStatus = state.status;
    state = state.copyWith(status: status);

    const terminal = {'completed', 'cancelled', 'canceled', 'rejected'};
    if (terminal.contains(status)) {
      unawaited(HeycabyWidgetSync.clearAll());
    }

    // Play sounds based on status transitions
    final soundService = SoundService();
    if (previousStatus != status) {
      if (status == 'assigned' || status == 'accepted' || status == 'driver_found') {
        soundService.playDriverFound();
      } else if (status == 'arrived' || status == 'driver_arrived') {
        soundService.playDriverArrived();
      } else if (status == 'completed' || status == 'finished') {
        soundService.playTripComplete();
      }
    }
  }

  void reset() {
    unawaited(HeycabyWidgetSync.clearAll());
    state = const RideRequestState();
  }

  /// Pre-ride driver confirmation flow (scheduled rides).
  /// Uses token-scoped RPC so reads work even when direct `ride_requests` SELECT is restricted.
  Future<Map<String, dynamic>?> fetchPrerideFields(String rideRequestId) async {
    final identity = await ref.read(riderIdentityProvider.future);
    final token = identity.riderToken;
    if (token == null || token.isEmpty) return null;
    try {
      final res = await HeyCabySupabase.client.rpc(
        'fn_rider_get_preride_snapshot',
        params: {
          'p_ride_request_id': rideRequestId,
          'p_rider_token': token,
        },
      );
      if (res is! Map) return null;
      final m = Map<String, dynamic>.from(res);
      if (m['ok'] != true) return null;
      return {
        'rider_preride_request_sent_at': m['rider_preride_request_sent_at'],
        'rider_preride_deadline': m['rider_preride_deadline'],
        'rider_preride_confirmed': m['rider_preride_confirmed'],
        'preride_commitment_fee_euros': m['preride_commitment_fee_euros'],
        'commitment_fee_tikkie_url': m['commitment_fee_tikkie_url'],
      };
    } catch (_) {
      return null;
    }
  }

  Future<bool> confirmPrerideServer(String rideRequestId) async {
    final identity = await ref.read(riderIdentityProvider.future);
    final token = identity.riderToken;
    if (token == null || token.isEmpty) return false;
    try {
      final res = await HeyCabySupabase.client.rpc(
        'fn_rider_confirm_preride',
        params: {
          'p_ride_request_id': rideRequestId,
          'p_rider_token': token,
        },
      );
      return res is Map && res['ok'] == true;
    } catch (_) {
      return false;
    }
  }
}

final rideRequestProvider =
    NotifierProvider<RideRequestNotifier, RideRequestState>(
  RideRequestNotifier.new,
);
