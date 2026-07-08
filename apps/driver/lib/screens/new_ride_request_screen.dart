import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_utils/heycaby_utils.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_location_provider.dart';
import '../providers/driver_state_provider.dart';
import '../services/driver_automatic_ping_service.dart';
import '../services/location_service.dart';
import '../services/sound_service.dart';
import '../utils/accept_ride_error_message.dart';
import '../utils/driver_ride_coord_utils.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_opportunity_screen_body.dart';
import '../widgets/driver_ride_flow_common.dart';

/// **Opportunity Screen** — accept or decline in &lt; 1 second.
class NewRideRequestScreen extends ConsumerStatefulWidget {
  const NewRideRequestScreen({
    super.key,
    required this.rideId,
    this.urgent = true,
  });

  final String rideId;

  /// When false, no ringtone/countdown alarm (manual browse). Realtime/FCM use true.
  final bool urgent;

  @override
  ConsumerState<NewRideRequestScreen> createState() =>
      _NewRideRequestScreenState();
}

class _NewRideRequestScreenState extends ConsumerState<NewRideRequestScreen> {
  static const _countdownFallback = 30;
  static const _countdownMin = 5;
  static const _countdownMax = 60;

  Map<String, dynamic>? _rideData;
  String? _error;
  int _countdown = _countdownFallback;
  int _countdownTotal = _countdownFallback;
  Timer? _countdownTimer;
  bool _isAccepting = false;
  bool _isDeclining = false;

  @override
  void initState() {
    super.initState();
    _loadRide();
    if (widget.urgent) {
      HapticService.heavyTap();
    }
  }

  void _startCountdownIfNeeded() {
    if (!widget.urgent || _countdownTimer != null) return;
    SoundService().playRideRequest(
      duration: Duration(seconds: _countdownTotal),
    );
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          _countdownTimer?.cancel();
          _onExpired();
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    if (widget.urgent) {
      SoundService().stopRideRequest();
    }
    super.dispose();
  }

  Future<void> _loadRide() async {
    try {
      // Select with extracted lat/lng from PostGIS coords + explicit lat/lng columns
      final res = await HeyCabySupabase.client
          .from('ride_requests')
          .select('''
            *,
            pickup_lat,
            pickup_lng,
            destination_lat,
            destination_lng
          ''')
          .eq('id', widget.rideId)
          .maybeSingle();
      if (!mounted) return;
      if (res == null) {
        setState(() => _error = DriverStrings.rideNotFound);
        return;
      }

      final bookingMode = res['booking_mode'] as String?;
      final isScheduled = bookingMode == 'scheduled' ||
          res['is_scheduled'] == true;
      if (isScheduled) {
        setState(() {
          _error = DriverStrings.scheduledRideWrongEntryMessage;
        });
        return;
      }

      // Enrich: extract lat/lng from PostGIS if separate columns are null
      enrichDriverRideRequestCoords(res);

      var seconds = _countdownFallback;
      final driverId = await ref.read(driverIdProvider.future);

      // Enrich: compute fallback fare if offered_fare is null
      await _enrichFare(res);

      // Enrich: pickup distance/time from driver GPS + invite row
      await _enrichPickupMeta(res, driverId: driverId);

      // Enrich: product context chips (return mode, radius, driver position)
      await _enrichOfferContext(res);

      if (driverId != null && driverId.isNotEmpty) {
        final invite = await HeyCabySupabase.client
            .from('ride_request_invites')
            .select('expires_at, status, distance_km, eta_minutes')
            .eq('ride_request_id', widget.rideId)
            .eq('driver_id', driverId)
            .inFilter('status', ['pending', 'wave_expired'])
            .order('invited_at', ascending: false)
            .limit(1)
            .maybeSingle();
        final expiresRaw = invite?['expires_at'];
        if (expiresRaw is String) {
          final expiresAt = DateTime.tryParse(expiresRaw)?.toUtc();
          if (expiresAt != null) {
            final remaining =
                expiresAt.difference(DateTime.now().toUtc()).inSeconds;
            seconds = remaining.clamp(_countdownMin, _countdownMax);
          }
        }
        final inviteKm = (invite?['distance_km'] as num?)?.toDouble();
        if (inviteKm != null && inviteKm > 0) {
          res['pickup_distance_km'] = inviteKm;
          res['pickup_eta_min'] ??=
              HeyCabyFormatters.estimateDrivingMinutes(inviteKm).toDouble();
        }
        final inviteEta = (invite?['eta_minutes'] as num?)?.toDouble();
        if (inviteEta != null && inviteEta > 0) {
          res['pickup_eta_min'] = inviteEta;
        }
      }

      if (!mounted) return;
      setState(() {
        _rideData = res;
        _error = null;
        _countdown = seconds;
        _countdownTotal = seconds;
      });
      _startCountdownIfNeeded();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = DriverStrings.rideRequestLoadFailedMessage);
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

    try {
      final returnMode = await ref.read(driverReturnModeProvider.future);
      if (returnMode.enabled) {
        res['return_mode_active'] = true;
        if (returnMode.destinationLabel != null &&
            returnMode.destinationLabel!.isNotEmpty) {
          res['return_destination_label'] = returnMode.destinationLabel;
        }
      }
    } catch (_) {}
  }

  static double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) * math.cos(_rad(lat2)) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
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
    if (!mounted) return;
    await _showMissedRequestDialog();
  }

  Future<void> _persistAcceptedFareSnapshot() async {
    final r = _rideData;
    if (r == null) return;
    final euro = HeyCabyRideFare.resolveEuroFromRow(r);
    if (euro == null) return;
    try {
      await HeyCabySupabase.client
          .from('ride_requests')
          .update(HeyCabyRideFare.fareSnapshotForInsert(euro))
          .eq('id', widget.rideId);
    } catch (_) {
      // Display still uses enriched local fare; DB sync is best-effort.
    }
  }

  Future<void> _acceptRide() async {
    if (_isAccepting) return;
    setState(() => _isAccepting = true);
    _countdownTimer?.cancel();
    SoundService().stopRideRequest();

    try {
      final driverId = await ref.read(driverIdProvider.future);
      await _logAcceptPreflight(driverId);

      await DriverLocationService().uploadNowForAccept();
      await ref
          .read(driverApiProvider)
          .acceptRide(rideRequestId: widget.rideId);
      await _persistAcceptedFareSnapshot();
      SoundService().playRideAccepted();
      HapticService.success();
      final r = _rideData == null
          ? null
          : Map<String, dynamic>.from(_rideData!);
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
      unawaited(
        const DriverAutomaticPingService().sendIfNeeded(
          rideRequestId: widget.rideId,
          type: DriverPingType.onMyWay,
        ),
      );
      if (!mounted) return;
      context.go('/driver/ride/active/${widget.rideId}');
    } on DriverAcceptRideException catch (e) {
      if (!mounted) return;
      _logAcceptFailure(e);
      setState(() => _isAccepting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(acceptRideErrorMessageFor(e)),
        ),
      );
      if (_shouldLeaveAfterAcceptError(e.code)) {
        context.go('/driver');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isAccepting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.rideActionFailedMessage)),
      );
    }
  }

  Future<void> _logAcceptPreflight(String? driverId) async {
    if (!kDebugMode) return;
    final supabaseUrl = HeyCabySupabase.supabaseUrl;
    debugPrint('[accept] rideId=${widget.rideId} driverId=$driverId supabase=$supabaseUrl');
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
    } catch (e) {
      debugPrint('[accept] preflight read failed: $e');
    }
  }

  void _logAcceptFailure(DriverAcceptRideException e) {
    if (!kDebugMode) return;
    debugPrint(
      '[accept] FAILED code=${e.code} reason=${e.reason} message=${e.message} details=${e.details}',
    );
  }

  bool _shouldLeaveAfterAcceptError(String code) {
    final normalized = code.split(':').first.trim();
    return normalized == 'race_lost' ||
        normalized == 'ride_not_found' ||
        normalized == 'ride_cancelled';
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
