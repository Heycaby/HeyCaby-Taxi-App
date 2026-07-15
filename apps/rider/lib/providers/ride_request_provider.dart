import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_models/heycaby_models.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_utils/heycaby_utils.dart';

import '../constants/rider_search_window.dart';
import '../models/ride_matching_variant.dart';
import '../services/booking_draft_storage.dart';
import '../services/sound_service.dart';
import '../services/heycaby_widget_sync.dart';
import '../services/rider_notify_live_activity.dart';
import '../services/nearby_supply_service.dart';
import '../services/rider_device_permission_snapshot.dart';
import '../services/rider_notification_lifecycle_service.dart';
import '../services/rider_permission_backend_sync.dart';
import '../services/stale_ride_cleanup.dart';
import '../utils/wkt_point.dart';
import 'booking_provider.dart';
import 'favorites_provider.dart';

class RideRequestState {
  final bool isLoading;
  final String? rideRequestId;
  final String? status;
  final String? error;

  /// Server `created_at` for the current ride (used for 30 min search window).
  final DateTime? rideCreatedAt;

  /// Server `booking_mode`: instant | marketplace | scheduled (for matching route + UI).
  final String? bookingMode;

  /// Token stored on the ride row at booking time (may differ from current identity token).
  final String? riderToken;

  const RideRequestState({
    this.isLoading = false,
    this.rideRequestId,
    this.status,
    this.error,
    this.rideCreatedAt,
    this.bookingMode,
    this.riderToken,
  });

  RideRequestState copyWith({
    bool? isLoading,
    String? rideRequestId,
    String? status,
    String? error,
    DateTime? rideCreatedAt,
    String? bookingMode,
    String? riderToken,
  }) =>
      RideRequestState(
        isLoading: isLoading ?? this.isLoading,
        rideRequestId: rideRequestId ?? this.rideRequestId,
        status: status ?? this.status,
        error: error ?? this.error,
        rideCreatedAt: rideCreatedAt ?? this.rideCreatedAt,
        bookingMode: bookingMode ?? this.bookingMode,
        riderToken: riderToken ?? this.riderToken,
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
  String? _pendingCreateRequestId;
  String? _pendingCreatePayloadSignature;

  @override
  RideRequestState build() => const RideRequestState();

  String _generateGuestRiderToken() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // UUID v4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

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
            'id, status, created_at, booking_mode, rider_token, pickup_address, destination_address, '
            'offered_fare, quoted_fare, estimated_fare, marketplace_offered_fare, '
            'pickup_coords, destination_coords',
          )
          .eq('rider_token', identity.riderToken!)
          .inFilter('status', [
            'pending',
            'bidding',
            'assigned',
            'accepted',
            'driver_found',
            'driver_en_route',
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

      if (createdAt != null && (status == 'pending' || status == 'bidding')) {
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
            ((status == 'pending' || status == 'bidding')
                ? DateTime.now()
                : null),
        bookingMode: resolvedBookingMode,
        riderToken: (activeRide['rider_token'] as String?)?.trim() ??
            identity.riderToken,
      );
      _hydrateBookingFromRideRequestRow(Map<String, dynamic>.from(activeRide));
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('tryRestoreActiveRideRequest: $e');
      return false;
    }
  }

  /// Cancels a pending/bidding ride that exceeded the search window, then clears local state.
  Future<bool> cancelStaleOpenRequest() async {
    final id = state.rideRequestId;
    final identity = await ref.read(riderIdentityProvider.future);
    final token = identity.riderToken;
    if (id != null && token != null) {
      final cancelled =
          await cancelExpiredRiderOpenRide(rideId: id, riderToken: token);
      if (!cancelled) return false;
      unawaited(SoundService().playRideCancelled());
    }
    reset();
    return true;
  }

  // Ride creation ONLY happens here — triggered from [SearchingScreen] after navigation.
  Future<bool> createRide(BookingState booking) async {
    if (booking.pickup == null || booking.destination == null) {
      if (kDebugMode) {
        debugPrint('CreateRide failed: pickup or destination is null');
      }
      return false;
    }
    final pickupContactName = booking.pickupContactName?.trim() ?? '';
    if (pickupContactName.isEmpty) {
      if (kDebugMode) {
        debugPrint('CreateRide failed: pickupContactName is required');
      }
      return false;
    }
    final requiresNamedPrice =
        booking.effectiveRideMode == BookingMode.marketplace ||
            booking.effectiveRideMode == BookingMode.terug;
    if (requiresNamedPrice &&
        (booking.marketplaceBidEuro == null ||
            booking.marketplaceBidEuro! <= 0)) {
      if (kDebugMode) {
        debugPrint(
            'CreateRide failed: named-price ride requires marketplaceBidEuro');
      }
      return false;
    }
    if (state.isLoading) {
      if (kDebugMode) debugPrint('CreateRide failed: already loading');
      return false;
    }

    if (booking.selectedDriverId == null &&
        (booking.favoritesFirst || booking.favoritesOnly)) {
      try {
        final favorites = await ref.read(favoritesProvider.future);
        if (favorites.isEmpty) {
          state = state.copyWith(error: 'favorite_drivers_required');
          return false;
        }
      } catch (_) {
        state = state.copyWith(error: 'favorite_drivers_unavailable');
        return false;
      }
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final identity = await ref.read(riderIdentityProvider.future);
      final locationServiceEnabled =
          await Geolocator.isLocationServiceEnabled();
      final permissionSnapshot = await RiderDevicePermissionSnapshot.read();
      final locationReady =
          locationServiceEnabled && permissionSnapshot.locationGranted;
      await RiderPermissionBackendSync.push(
        locationGranted: locationReady,
        notificationsGranted: permissionSnapshot.notificationsGranted,
        riderIdentityId: identity.identityId,
      );
      if (!locationReady) {
        state = state.copyWith(
          isLoading: false,
          error: 'location_required',
        );
        return false;
      }

      final supabase = HeyCabySupabase.client;
      final authUserId = supabase.auth.currentUser?.id;
      String? riderToken = identity.riderToken;
      String? verifiedIdentityId = identity.identityId;

      // Guest riders can book without email/login; keep a local token for RLS.
      if (riderToken == null || riderToken.isEmpty) {
        riderToken = _generateGuestRiderToken();
        await ref
            .read(riderIdentityProvider.notifier)
            .saveGuestToken(riderToken);
      }
      await const RiderSessionService().bindToken(riderToken);
      if (verifiedIdentityId != null && verifiedIdentityId.isNotEmpty) {
        try {
          // Look up by id only — the identity may have user_id = null
          // (guest riders created via fn_create_rider_session).
          final row = await supabase
              .from('rider_identities')
              .select('id')
              .eq('id', verifiedIdentityId)
              .maybeSingle();
          if (row == null) {
            verifiedIdentityId = null;
          }
        } catch (_) {
          // If identity lookup fails, do not block booking creation.
          verifiedIdentityId = null;
        }
      } else {
        verifiedIdentityId = null;
      }

      // Fallback: resolve the rider identity that belongs to the current auth user.
      // Try by user_id first, then by email (identities created via
      // fn_create_rider_session have user_id = null but do have email).
      if ((verifiedIdentityId == null || verifiedIdentityId.isEmpty) &&
          authUserId != null &&
          authUserId.isNotEmpty) {
        try {
          final owned = await supabase
              .from('rider_identities')
              .select('id')
              .eq('user_id', authUserId)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          final ownedId = owned?['id'] as String?;
          if (ownedId != null && ownedId.isNotEmpty) {
            verifiedIdentityId = ownedId;
          }
        } catch (_) {
          // Keep null; insert may still work if policy allows rider_token-only path.
        }
      }

      // Fallback 2: try by email when user_id lookup failed (guest identities).
      final email = (identity.email ?? '').trim().toLowerCase();
      if ((verifiedIdentityId == null || verifiedIdentityId.isEmpty) &&
          email.isNotEmpty) {
        try {
          final byEmail = await supabase
              .from('rider_identities')
              .select('id')
              .eq('email', email)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          final emailId = byEmail?['id'] as String?;
          if (emailId != null && emailId.isNotEmpty) {
            verifiedIdentityId = emailId;
          }
        } catch (_) {
          // Keep null; fn_create_rider_session fallback below may still work.
        }
      }

      // Final fallback: re-issue rider session from backend (email-based) so
      // session_token + rider_identity_id are aligned for current auth context.
      if ((verifiedIdentityId == null || verifiedIdentityId.isEmpty) &&
          email.isNotEmpty) {
        try {
          final refreshed = await supabase.rpc(
            'fn_create_rider_session',
            params: {'p_email': email, 'p_display_name': null},
          );
          if (refreshed is Map && refreshed['success'] == true) {
            final refreshedMap = Map<String, dynamic>.from(refreshed);
            final refreshedIdentityId = refreshedMap['identity_id'] as String?;
            final refreshedToken = refreshedMap['session_token'] as String?;
            if (refreshedIdentityId != null && refreshedIdentityId.isNotEmpty) {
              verifiedIdentityId = refreshedIdentityId;
            }
            if (refreshedToken != null && refreshedToken.isNotEmpty) {
              riderToken = refreshedToken;
            }
            if (refreshedToken != null &&
                refreshedToken.isNotEmpty &&
                refreshedIdentityId != null &&
                refreshedIdentityId.isNotEmpty) {
              await ref.read(riderIdentityProvider.notifier).saveSession(
                    token: refreshedToken,
                    identityId: refreshedIdentityId,
                    email: email,
                  );
            }
          }
        } catch (_) {
          // Keep existing values; createRide insert will still attempt best effort.
        }
      }

      // Format coordinates for PostGIS geography type (longitude FIRST)
      final pickupLng = booking.pickup!.lng;
      final pickupLat = booking.pickup!.lat;
      final destLng = booking.destination!.lng;
      final destLat = booking.destination!.lat;

      final tripKm = booking.routeDistanceKm ??
          NearbySupplyService.distanceKm(
            pickupLat,
            pickupLng,
            destLat,
            destLng,
          );
      final durationMin = booking.routeDurationMin ??
          HeyCabyFormatters.estimateDrivingMinutes(tripKm);

      // Keep Supabase flags aligned with marketplace audience picker.
      final favoritesOnly = booking.favoritesOnly;
      final favoritesFirst = favoritesOnly || booking.favoritesFirst;

      final body = <String, dynamic>{
        // The backend command owns PostGIS construction and writes both the
        // geography and scalar coordinate projections atomically.
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'destination_lat': destLat,
        'destination_lng': destLng,

        // Address strings
        'pickup_address': booking.pickup!.fullAddress,
        'destination_address': booking.destination!.fullAddress,

        // Matching (see supabase/migrations/20260329180000_ride_matching_cascade.sql)
        'booking_mode': bookingModeStorageString(booking.effectiveRideMode),
        'vehicle_category': _rideRequestVehicleCategory(
          booking.vehicleCategories.isNotEmpty
              ? booking.vehicleCategories.first
              : booking.vehicleCategory,
        ),
        if (booking.vehicleCategories.isNotEmpty)
          'vehicle_categories': booking.vehicleCategories
              .take(3)
              .map(_rideRequestVehicleCategory)
              .toList(),
        'pet_friendly': booking.petFriendly,
        'estimated_distance_km': tripKm,
        'estimated_duration_min': durationMin,

        // Optional fields
        'pickup_contact_name': pickupContactName,
        if (booking.scheduledAt != null)
          'scheduled_pickup_at': booking.scheduledAt!.toIso8601String(),
        if (riderToken != null && riderToken.isNotEmpty)
          'rider_token': riderToken,
        if (verifiedIdentityId != null) 'rider_identity_id': verifiedIdentityId,
        // Named-price rides: DB constraint requires marketplace_offered_fare.
        if (requiresNamedPrice) ...<String, dynamic>{
          'marketplace_offered_fare': booking.marketplaceBidEuro!,
        },
        if (!requiresNamedPrice &&
            booking.quotedFareEuro != null &&
            booking.quotedFareEuro! > 0)
          'quoted_fare': booking.quotedFareEuro!,

        // Direct dispatch: target a specific driver (1 driver per job enforced by DB)
        if (booking.selectedDriverId != null)
          'preferred_driver_id': booking.selectedDriverId,
        if (booking.paymentMethods.isNotEmpty)
          'payment_methods': booking.paymentMethods,
        'favorites_first': favoritesFirst,
        'favorites_only': favoritesOnly,
      };

      // Save booking name progressively if newly entered
      if (identity.bookingName == null) {
        await ref
            .read(riderIdentityProvider.notifier)
            .saveBookingName(pickupContactName);
      }

      final payloadSignature = jsonEncode(body);
      if (_pendingCreatePayloadSignature != payloadSignature) {
        _pendingCreatePayloadSignature = payloadSignature;
        _pendingCreateRequestId = _generateGuestRiderToken();
      }
      body['request_id'] = _pendingCreateRequestId;

      final rawResponse = await supabase.rpc(
        'fn_rider_create_ride',
        params: {'p_payload': body},
      );
      if (rawResponse is! Map) {
        throw const FormatException('invalid_create_ride_response');
      }
      final response = Map<String, dynamic>.from(rawResponse);
      if (response['ok'] != true) {
        state = state.copyWith(
          isLoading: false,
          error: (response['error'] as String?) ?? 'ride_creation_failed',
        );
        return false;
      }

      state = state.copyWith(
        isLoading: false,
        rideRequestId: response['id'] as String?,
        status: response['status'] as String?,
        rideCreatedAt:
            _parseCreatedAt(response['created_at']) ?? DateTime.now(),
        bookingMode: response['booking_mode'] as String? ??
            bookingModeStorageString(booking.effectiveRideMode),
        riderToken: riderToken,
      );
      _pendingCreateRequestId = null;
      _pendingCreatePayloadSignature = null;

      // Confirm booking with sound + haptic
      SoundService().playBookingCreated();
      HapticService.success();
      unawaited(
        RiderNotificationLifecycleService.trackEvent(
          'booking_created',
          riderIdentityId: identity.identityId,
          payload: <String, dynamic>{
            'booking_mode': bookingModeStorageString(booking.effectiveRideMode),
            if (state.rideRequestId != null)
              'ride_request_id': state.rideRequestId,
          },
        ),
      );
      if (booking.effectiveRideMode == BookingMode.scheduled &&
          booking.scheduledAt != null) {
        unawaited(
          RiderNotificationLifecycleService.trackEvent(
            'scheduled_ride_created',
            riderIdentityId: identity.identityId,
            payload: <String, dynamic>{
              'scheduled_pickup_at':
                  booking.scheduledAt!.toUtc().toIso8601String(),
              if (state.rideRequestId != null)
                'ride_request_id': state.rideRequestId,
            },
          ),
        );
      }
      await BookingDraftStorage.clear();

      return true;
    } catch (e, stackTrace) {
      debugPrint('CreateRide error: $e');
      if (kDebugMode) {
        debugPrint('CreateRide stack trace: $stackTrace');
      }
      final message = e.toString();
      final error = message.contains('rider_location_required') ||
              message.contains('Location permission is required')
          ? 'location_required'
          : 'ride_creation_failed';
      state = state.copyWith(
        isLoading: false,
        error: error,
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
            'scheduled_pickup_at, pickup_coords, destination_coords, marketplace_offered_fare, '
            'offered_fare, quoted_fare, estimated_fare',
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
        riderToken: identity.riderToken,
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
      case 'terug':
        mode = BookingMode.terug;
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
    if (fareRaw is num && fareRaw > 0) {
      marketplaceBid = fareRaw.round();
    }

    final restoredFare = HeyCabyRideFare.resolveEuroFromRow(m);

    ref.read(bookingProvider.notifier).restoreFromDraft(
          BookingState(
            mode: mode,
            pickup: pu,
            destination: de,
            scheduledAt: scheduledAt,
            marketplaceBidEuro: marketplaceBid,
            estimatedFareEuro: restoredFare,
            tripPriceBandMinEuro: restoredFare,
            tripPriceBandMaxEuro: restoredFare,
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
      if (status == 'assigned' ||
          status == 'accepted' ||
          status == 'driver_found') {
        soundService.playDriverFound();
      } else if (status == 'driver_en_route') {
        soundService.playDriverFound();
      } else if (status == 'arrived' || status == 'driver_arrived') {
        soundService.playDriverArrived();
      } else if (status == 'cancelled' ||
          status == 'canceled' ||
          status == 'rejected') {
        soundService.playDriverCancelled();
      } else if (status == 'completed' || status == 'finished') {
        soundService.playPaymentSuccess();
        unawaited(_trackRideCompletedLifecycleEvent());
      }
    }
  }

  Future<void> _trackRideCompletedLifecycleEvent() async {
    final identity = await ref.read(riderIdentityProvider.future);
    if (!identity.hasSession || identity.identityId == null) return;
    await RiderNotificationLifecycleService.trackEvent(
      'ride_completed',
      riderIdentityId: identity.identityId,
      payload: <String, dynamic>{
        if (state.rideRequestId != null) 'ride_request_id': state.rideRequestId,
      },
    );
  }

  void reset() {
    unawaited(HeycabyWidgetSync.clearAll());
    unawaited(RiderNotifyLiveActivity.end());
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
