import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_map/heycaby_map.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_utils/heycaby_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_location_provider.dart';
import '../providers/driver_state_provider.dart';
import '../services/driver_incoming_ride_prefetch.dart';
import '../services/location_service.dart';
import '../services/sound_service.dart';
import '../utils/accept_ride_error_message.dart';
import '../utils/driver_missed_opportunity_recorder.dart';
import '../utils/driver_today_rides_refresh.dart';
import '../utils/driver_taxi_thru_refresh.dart';
import '../utils/driver_ride_coord_utils.dart';
import '../utils/driver_rider_cancelled_flow.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_opportunity_screen_body.dart';
import '../widgets/driver_ride_flow_common.dart';

/// **Opportunity Screen** — accept or decline in &lt; 1 second.
class NewRideRequestScreen extends ConsumerStatefulWidget {
  const NewRideRequestScreen({
    super.key,
    required this.rideId,
    this.inviteId,
    this.urgent = true,
    this.prefetch,
  });

  final String rideId;
  final String? inviteId;

  /// When false, no ringtone/countdown alarm (manual browse). Realtime/FCM use true.
  final bool urgent;

  /// Invite metadata prefetched by [DriverIncomingRideCoordinator] for fast paint.
  final DriverIncomingRidePrefetch? prefetch;

  @override
  ConsumerState<NewRideRequestScreen> createState() =>
      _NewRideRequestScreenState();
}

class _NewRideRequestScreenState extends ConsumerState<NewRideRequestScreen> {
  static const _countdownFallback = 30;
  static const _countdownMax = 60;

  Map<String, dynamic>? _rideData;
  String? _error;
  int _countdown = _countdownFallback;
  int _countdownTotal = _countdownFallback;
  Timer? _countdownTimer;
  DateTime? _inviteExpiresAt;
  RealtimeChannel? _cancelChannel;
  bool _isAccepting = false;
  bool _isDeclining = false;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: _syncCountdownToServerClock,
    );
    _subscribeRideCancelled();
    _bootstrapCountdownFromPrefetch();
    _loadRide();
    if (widget.urgent) {
      HapticService.heavyTap();
      unawaited(
        SoundService().playRideRequest(
          duration: const Duration(seconds: _countdownMax),
        ),
      );
    }
  }

  void _bootstrapCountdownFromPrefetch() {
    if (!widget.urgent) return;
    final expiresAt = widget.prefetch?.expiresAt;
    if (expiresAt == null) return;
    final remaining = expiresAt.difference(DateTime.now().toUtc()).inSeconds;
    if (remaining <= 0) {
      _error = DriverStrings.acceptRideErrorMessage('invite_expired');
      return;
    }
    _inviteExpiresAt = expiresAt;
    _countdown = remaining.clamp(1, _countdownMax);
    _countdownTotal = _countdown;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startCountdownIfNeeded();
    });
  }

  void _subscribeRideCancelled() {
    _cancelChannel?.unsubscribe();
    _cancelChannel = HeyCabySupabase.client
        .channel('ride-cancel-incoming-${widget.rideId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ride_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.rideId,
          ),
          callback: (payload) {
            final status = payload.newRecord['status'] as String?;
            if (status != 'cancelled' || !mounted) return;
            _countdownTimer?.cancel();
            handleDriverRiderCancelled(
              ref: ref,
              context: context,
              rideId: widget.rideId,
            );
          },
        )
        .subscribe();
  }

  void _startCountdownIfNeeded() {
    if (!widget.urgent || _countdownTimer != null) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _syncCountdownToServerClock();
    });
  }

  void _syncCountdownToServerClock() {
    if (!mounted || !widget.urgent || _isDeclining || _isAccepting) return;
    final expiresAt = _inviteExpiresAt;
    if (expiresAt == null) return;
    final remaining = expiresAt.difference(DateTime.now().toUtc()).inSeconds;
    if (remaining <= 0) {
      _countdownTimer?.cancel();
      setState(() {
        _countdown = 0;
        _isDeclining = true;
      });
      unawaited(_onExpired());
      return;
    }
    if (_countdown != remaining) {
      setState(() => _countdown = remaining.clamp(1, _countdownMax));
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _lifecycleListener.dispose();
    _cancelChannel?.unsubscribe();
    if (widget.urgent) {
      SoundService().stopRideRequest();
    }
    super.dispose();
  }

  Future<void> _loadRide() async {
    try {
      final driverId = await ref.read(driverIdProvider.future);
      final needsInviteFetch =
          widget.urgent && widget.prefetch?.expiresAt == null;

      final results = await Future.wait<dynamic>([
        HeyCabySupabase.client.from('ride_requests').select('''
            *,
            pickup_lat,
            pickup_lng,
            destination_lat,
            destination_lng,
            pickup_coords,
            destination_coords
          ''').eq('id', widget.rideId).maybeSingle(),
        if (needsInviteFetch)
          _fetchPendingInvite(driverId: driverId)
        else
          Future<Map<String, dynamic>?>.value(null),
      ]);

      final res = results[0] as Map<String, dynamic>?;
      final invite = results[1] as Map<String, dynamic>?;

      if (!mounted) return;
      if (res == null) {
        setState(() => _error = DriverStrings.rideNotFound);
        return;
      }

      if (res['status'] == 'cancelled') {
        _countdownTimer?.cancel();
        stopDriverIncomingRideRinging();
        if (!mounted) return;
        await handleDriverRiderCancelled(
          ref: ref,
          context: context,
          rideId: widget.rideId,
        );
        return;
      }

      final bookingMode = res['booking_mode'] as String?;
      final isScheduled =
          bookingMode == 'scheduled' || res['is_scheduled'] == true;
      if (isScheduled) {
        setState(() {
          _error = DriverStrings.scheduledRideWrongEntryMessage;
        });
        return;
      }

      enrichDriverRideRequestCoords(res);
      _applyPrefetchToRide(res);

      // Earnings are quoted by the backend. Flutter only renders the frozen
      // service-fee contract and never calculates an authoritative split.
      try {
        final quote = await HeyCabySupabase.client.rpc(
          'fn_quote_driver_ride_earnings',
          params: {'p_ride_id': widget.rideId, 'p_driver_id': driverId},
        );
        if (quote is Map && quote['ok'] == true) {
          res.addAll(Map<String, dynamic>.from(quote));
        }
      } catch (_) {
        // Dark-launch/legacy compatibility: accept RPC remains authoritative.
      }

      var seconds = _countdown;

      if (invite != null) {
        final inviteError = _validateAndApplyInvite(res, invite);
        if (inviteError != null) {
          setState(() => _error = inviteError);
          return;
        }
        seconds = _countdown;
      } else if (needsInviteFetch) {
        setState(() =>
            _error = DriverStrings.acceptRideErrorMessage('invite_missing'));
        return;
      } else if (_error != null) {
        setState(() {});
        return;
      }

      if (!mounted) return;
      setState(() {
        _rideData = res;
        if (_error == null) {
          _countdown = seconds;
          _countdownTotal = seconds;
        }
      });
      _startCountdownIfNeeded();

      unawaited(_enrichRideInBackground(Map<String, dynamic>.from(res)));
      if (widget.urgent && widget.prefetch != null) {
        unawaited(_verifyInviteInBackground(driverId));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = DriverStrings.rideRequestLoadFailedMessage);
    }
  }

  void _applyPrefetchToRide(Map<String, dynamic> res) {
    final prefetch = widget.prefetch;
    if (prefetch == null) return;
    final distanceKm = prefetch.distanceKm;
    if (distanceKm != null && distanceKm > 0) {
      res['pickup_distance_km'] = distanceKm;
      res['pickup_eta_min'] ??=
          HeyCabyFormatters.estimateDrivingMinutes(distanceKm).toDouble();
    }
    final etaMinutes = prefetch.etaMinutes;
    if (etaMinutes != null && etaMinutes > 0) {
      res['pickup_eta_min'] = etaMinutes;
    }
  }

  Future<Map<String, dynamic>?> _fetchPendingInvite({
    required String? driverId,
  }) async {
    if (driverId == null || driverId.isEmpty) return null;
    final baseInviteQuery = HeyCabySupabase.client
        .from('ride_request_invites')
        .select('id, expires_at, status, distance_km, eta_minutes')
        .eq('ride_request_id', widget.rideId)
        .eq('driver_id', driverId);
    if (widget.inviteId != null && widget.inviteId!.isNotEmpty) {
      return baseInviteQuery.eq('id', widget.inviteId!).maybeSingle();
    }
    return baseInviteQuery
        .eq('status', 'pending')
        .order('invited_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  String? _validateAndApplyInvite(
    Map<String, dynamic> res,
    Map<String, dynamic> invite,
  ) {
    final inviteStatus = invite['status']?.toString();
    if (widget.urgent && inviteStatus != 'pending') {
      return DriverStrings.acceptRideErrorMessage('invite_not_pending');
    }
    final expiresRaw = invite['expires_at'];
    if (expiresRaw is String) {
      final expiresAt = DateTime.tryParse(expiresRaw)?.toUtc();
      if (expiresAt != null) {
        final remaining =
            expiresAt.difference(DateTime.now().toUtc()).inSeconds;
        if (widget.urgent && remaining <= 0) {
          return DriverStrings.acceptRideErrorMessage('invite_expired');
        }
        _inviteExpiresAt = expiresAt;
        _countdown = remaining.clamp(1, _countdownMax);
        _countdownTotal = _countdown;
      }
    }
    final inviteKm = (invite['distance_km'] as num?)?.toDouble();
    if (inviteKm != null && inviteKm > 0) {
      res['pickup_distance_km'] = inviteKm;
      res['pickup_eta_min'] ??=
          HeyCabyFormatters.estimateDrivingMinutes(inviteKm).toDouble();
    }
    final inviteEta = (invite['eta_minutes'] as num?)?.toDouble();
    if (inviteEta != null && inviteEta > 0) {
      res['pickup_eta_min'] = inviteEta;
    }
    return null;
  }

  Future<void> _verifyInviteInBackground(String? driverId) async {
    if (driverId == null || driverId.isEmpty || !widget.urgent) return;
    try {
      final invite = await _fetchPendingInvite(driverId: driverId);
      if (!mounted) return;
      if (invite == null) {
        setState(() =>
            _error = DriverStrings.acceptRideErrorMessage('invite_missing'));
        return;
      }
      final inviteError = _validateAndApplyInvite(
        _rideData ?? <String, dynamic>{},
        invite,
      );
      if (inviteError != null) {
        setState(() => _error = inviteError);
      }
    } catch (_) {
      // Best-effort revalidation; accept RPC is authoritative.
    }
  }

  Future<void> _enrichRideInBackground(Map<String, dynamic> res) async {
    try {
      final geo = ref.read(geocodingServiceProvider);
      geo.startSession();
      await geocodeDriverRideRequestCoordsIfNeeded(res, geo);

      final driverId = await ref.read(driverIdProvider.future);
      await _enrichFare(res);
      await _enrichPickupMeta(res, driverId: driverId);
      await _enrichOfferContext(res);

      if (!mounted || _rideData == null || _error != null) return;
      setState(() => _rideData = Map<String, dynamic>.from(res));
    } catch (_) {
      // Offer card already visible; enrichment is progressive.
    }
  }

  /// Compute a fallback fare from rider offer, marketplace bid, or driver tariff.
  Future<void> _enrichFare(Map<String, dynamic> res) async {
    final marketplaceFare =
        (res['marketplace_offered_fare'] as num?)?.toDouble();
    if (marketplaceFare != null && marketplaceFare > 0) {
      res['offered_fare'] = marketplaceFare;
      res['fare_source'] = 'rider_offer';
      return;
    }

    final offeredFare = (res['offered_fare'] as num?)?.toDouble();
    final estimatedFare = (res['estimated_fare'] as num?)?.toDouble();
    if (offeredFare != null && offeredFare > 0) {
      res['fare_source'] = 'rider_offer';
      return;
    }
    if (estimatedFare != null && estimatedFare > 0) {
      res['offered_fare'] = estimatedFare;
      res['fare_source'] = 'estimate';
      return;
    }

    final distanceKm = (res['estimated_distance_km'] as num?)?.toDouble() ??
        (res['distance_km'] as num?)?.toDouble();
    final durationMin = (res['estimated_duration_min'] as num?)?.toDouble() ??
        (res['duration_min'] as num?)?.toDouble();
    if (distanceKm == null) return;

    try {
      final profiles = await ref.read(driverRateProfilesProvider.future);
      final active = profiles.where((p) => p.isActive).toList();
      final rate = active.isNotEmpty
          ? active.first
          : (profiles.isNotEmpty ? profiles.first : null);
      if (rate == null) return;

      final fare = (rate.baseFare +
              (distanceKm * rate.perKmRate) +
              ((durationMin ?? 0) * rate.perMinRate))
          .clamp(rate.minimumFare, double.infinity);
      final rounded = (fare * 100).round() / 100.0;
      res['offered_fare'] = rounded;
      res['tariff_estimate_fare'] = rounded;
      res['fare_source'] = 'tariff_estimate';
    } catch (_) {
      // UI falls back to distance-only hint if needed
    }
  }

  /// Compute pickup distance and ETA from driver's current GPS to pickup.
  Future<void> _enrichPickupMeta(
    Map<String, dynamic> res, {
    String? driverId,
  }) async {
    final pickupLat = (res['pickup_lat'] as num?)?.toDouble();
    final pickupLng = (res['pickup_lng'] as num?)?.toDouble();
    if (pickupLat == null || pickupLng == null) return;

    try {
      final pos = await ref.read(driverLocationProvider.future);
      final driverLat = pos.latitude;
      final driverLng = pos.longitude;
      if (!driverMapCoordIsValid(driverLat, driverLng)) return;
      final distanceKm =
          _haversineKm(driverLat, driverLng, pickupLat, pickupLng);
      if (distanceKm > 500) return;
      final etaMin = HeyCabyFormatters.estimateDrivingMinutes(distanceKm);
      res['driver_lat'] = driverLat;
      res['driver_lng'] = driverLng;
      res['pickup_distance_km'] ??= (distanceKm * 10).round() / 10.0;
      res['pickup_eta_min'] ??= etaMin.toDouble();
    } catch (_) {
      // Location not available — skip
    }
  }

  Future<void> _enrichOfferContext(Map<String, dynamic> res) async {
    try {
      final profile = await ref.read(driverProfileProvider.future);
      final maxKm = profile?.pickupDistanceMaxKm;
      if (maxKm != null && maxKm > 0) {
        res['pickup_radius_max_km'] = maxKm;
        final pickupKm = (res['pickup_distance_km'] as num?)?.toDouble();
        if (pickupKm != null && pickupKm > maxKm) {
          res['out_of_radius'] = true;
        }
      }
    } catch (_) {}

    final bookingMode = (res['booking_mode'] as String?)?.toLowerCase();
    if (bookingMode != 'terug') return;

    try {
      final driverId = await ref.read(driverIdProvider.future);
      if (driverId == null || driverId.isEmpty) return;
      final qualify =
          await ref.read(driverDataServiceProvider).qualifyTaxiTerugRide(
                driverId: driverId,
                rideRequestId: widget.rideId,
              );
      res['taxi_terug_qualified'] = qualify.qualified;
      if (qualify.destinationLabel != null &&
          qualify.destinationLabel!.isNotEmpty) {
        res['taxi_terug_destination_label'] = qualify.destinationLabel;
      }
      if (qualify.inTransit) {
        res['taxi_terug_next_ride'] = true;
        if (qualify.estimatedPickupMinutes != null) {
          res['taxi_terug_estimated_pickup_minutes'] =
              qualify.estimatedPickupMinutes;
        }
      }
    } catch (_) {
      res['taxi_terug_qualified'] = false;
    }
  }

  static double _haversineKm(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180.0;

  Future<void> _onExpired() async {
    SoundService().stopRideRequest();
    SoundService().playDriverCancelled();
    try {
      await ref
          .read(driverApiProvider)
          .declineRide(rideRequestId: widget.rideId);
    } catch (_) {}
    await recordDriverMissedOpportunity(
      ref: ref,
      rideRequestId: widget.rideId,
      rideRow: _rideData,
    );
    if (mounted) setState(() => _isDeclining = false);
    if (!mounted) return;
    await _showMissedRequestDialog();
  }

  Future<void> _acceptRide() async {
    if (_isAccepting || _isDeclining) return;
    final expiresAt = _inviteExpiresAt;
    if (widget.urgent &&
        (expiresAt == null || !expiresAt.isAfter(DateTime.now().toUtc()))) {
      await _showAcceptFailure(
        DriverStrings.acceptRideErrorMessage('invite_expired'),
        leaveAfter: true,
      );
      return;
    }
    setState(() => _isAccepting = true);
    _countdownTimer?.cancel();
    SoundService().stopRideRequest();

    try {
      final statusRow = await HeyCabySupabase.client
          .from('ride_requests')
          .select('status, cancelled_by')
          .eq('id', widget.rideId)
          .maybeSingle();
      final status = statusRow?['status'] as String?;
      if (status == 'cancelled') {
        if (!mounted) return;
        await handleDriverRiderCancelled(
          ref: ref,
          context: context,
          rideId: widget.rideId,
        );
        return;
      }

      final driverId = await ref.read(driverIdProvider.future);
      await _logAcceptPreflight(driverId);

      await DriverLocationService().uploadNowForAccept();
      await ref
          .read(driverApiProvider)
          .acceptRide(rideRequestId: widget.rideId);
      SoundService().playRideAccepted();
      HapticService.success();
      final r =
          _rideData == null ? null : Map<String, dynamic>.from(_rideData!);
      if (r != null) {
        enrichDriverRideRequestCoords(r);
      }
      ref.read(driverStateProvider.notifier).setActiveRide(
            rideId: widget.rideId,
            paymentMethod: null,
            pickupAddress: r?['pickup_address'] as String?,
            pickupLat: (r?['pickup_lat'] as num?)?.toDouble(),
            pickupLng: (r?['pickup_lng'] as num?)?.toDouble(),
            destinationAddress: r?['destination_address'] as String?,
            destLat: (r?['destination_lat'] as num?)?.toDouble(),
            destLng: (r?['destination_lng'] as num?)?.toDouble(),
            bookingMode: r?['booking_mode'] as String?,
            riderName: r?['pickup_contact_name'] as String?,
          );
      invalidateTodayRideProviders(ref);
      if ((r?['booking_mode'] as String?) == 'terug') {
        invalidateTaxiThruProviders(ref);
      }
      if (!mounted) return;
      context.go('/driver/ride/active/${widget.rideId}');
    } on DriverAcceptRideException catch (acceptError) {
      if (!mounted) return;
      _logAcceptFailure(acceptError);
      setState(() => _isAccepting = false);
      if (acceptError.code == 'rider_cancelled' ||
          acceptError.reason?.contains('rider_cancelled') == true) {
        await handleDriverRiderCancelled(
          ref: ref,
          context: context,
          rideId: widget.rideId,
        );
        return;
      }
      await _showAcceptFailure(
        acceptRideErrorMessageFor(acceptError),
        leaveAfter: shouldDismissAfterAcceptError(acceptError),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isAccepting = false);
      await _showAcceptFailure(
        DriverStrings.acceptRideUnexpectedError(error.runtimeType.toString()),
        leaveAfter: false,
      );
    }
  }

  Future<void> _showAcceptFailure(
    String message, {
    required bool leaveAfter,
  }) async {
    if (!mounted) return;
    final colors = ref.read(colorsProvider);
    final typography = ref.read(typographyProvider);
    await showHeyCabyAcknowledgeSheet(
      context,
      colors: colors,
      typography: typography,
      title: DriverStrings.acceptRideCouldNotCompleteTitle,
      message: message,
      actionLabel: DriverStrings.close,
      icon: Icons.info_outline_rounded,
      iconColor: colors.warning,
      barrierDismissible: false,
    );
    if (mounted && leaveAfter) context.go('/driver');
  }

  Future<void> _logAcceptPreflight(String? driverId) async {
    if (!kDebugMode) return;
    final supabaseUrl = HeyCabySupabase.supabaseUrl;
    debugPrint(
        '[accept] rideId=${widget.rideId} driverId=$driverId supabase=$supabaseUrl');
    try {
      final ride = await HeyCabySupabase.client
          .from('ride_requests')
          .select('status, driver_id, expires_at')
          .eq('id', widget.rideId)
          .maybeSingle();
      debugPrint('[accept] ride preflight: $ride');
      if (driverId != null) {
        final invite = await HeyCabySupabase.client
            .from('ride_request_invites')
            .select('id, status, expires_at, invited_at')
            .eq('ride_request_id', widget.rideId)
            .eq('driver_id', driverId)
            .order('invited_at', ascending: false)
            .limit(1)
            .maybeSingle();
        debugPrint('[accept] invite preflight: $invite');
      }
    } catch (_) {
      debugPrint('[accept] preflight read failed');
    }
  }

  void _logAcceptFailure(DriverAcceptRideException e) {
    if (!kDebugMode) return;
    debugPrint(
      '[accept] FAILED code=${e.code} reason=${e.reason} message=${e.message} details=${e.details}',
    );
  }

  Future<void> _declineRide() async {
    if (_isDeclining || _isAccepting) return;
    setState(() => _isDeclining = true);
    _countdownTimer?.cancel();
    SoundService().stopRideRequest();
    SoundService().playDriverCancelled();
    try {
      await ref
          .read(driverApiProvider)
          .declineRide(rideRequestId: widget.rideId);
      await recordDriverMissedOpportunity(
        ref: ref,
        rideRequestId: widget.rideId,
        rideRow: _rideData,
      );
    } catch (_) {}
    if (mounted) setState(() => _isDeclining = false);
    if (!mounted) return;
    context.go('/driver');
  }

  Future<void> _showMissedRequestDialog() async {
    final themeColors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    await showHeyCabyAcknowledgeSheet(
      context,
      colors: themeColors,
      typography: typo,
      title: DriverStrings.missedRequestTitle,
      message: DriverStrings.missedRequestBody,
      actionLabel: DriverStrings.close,
      icon: Icons.warning_amber_rounded,
      iconColor: themeColors.warning,
      barrierDismissible: false,
    );
    if (!mounted) return;
    context.go('/driver');
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));

    return DriverOpportunityScreenBody(
      colors: colors,
      typography: typography,
      countdownSeconds: widget.urgent ? _countdown : 0,
      totalCountdownSeconds: widget.urgent ? _countdownTotal : 0,
      showCountdown: widget.urgent,
      isAccepting: _isAccepting,
      isDeclining: _isDeclining,
      onAccept: _acceptRide,
      onDecline: _declineRide,
      onErrorBack: () => context.go('/driver'),
      rideData: _error == null ? _rideData : null,
      errorMessage: _error,
    );
  }
}
