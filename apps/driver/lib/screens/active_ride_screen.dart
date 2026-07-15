import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_utils/heycaby_utils.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_location_provider.dart';
import '../providers/driver_ride_proximity_provider.dart';
import '../providers/driver_runtime_providers.dart';
import '../providers/driver_state_provider.dart';
import '../services/driver_automatic_ping_service.dart';
import '../services/driver_pickup_wait_service.dart';
import '../utils/driver_cancel_ride_flow.dart';
import '../utils/driver_communication_distance.dart';
import '../utils/driver_ride_lifecycle_error_message.dart';
import '../utils/driver_ride_proximity_gate.dart';
import '../widgets/driver_ride_communication_sheet.dart';
import '../utils/driver_navigation_launch.dart';
import '../utils/driver_nav_app_helpers.dart';
import '../utils/driver_ride_coord_utils.dart';
import '../utils/driver_rider_ping.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_ride_bolt_layout.dart';
import '../widgets/driver_active_trip_body.dart';

/// **Active Trip** — navigate to pickup; rider + ETA obvious.
class ActiveRideScreen extends ConsumerStatefulWidget {
  const ActiveRideScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends ConsumerState<ActiveRideScreen> {
  bool _loading = false;
  bool _statusBusy = false;
  bool _startingTrip = false;
  bool _enRouteStarted = false;
  String? _farePill;
  Timer? _arrivalVerificationTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFarePill());
    unawaited(_hydrateEnRouteState());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(hydrateDriverRideCoordsIfNeeded(ref, widget.rideId));
    });
  }

  @override
  void dispose() {
    _arrivalVerificationTimer?.cancel();
    super.dispose();
  }

  Future<bool> _requestVerifiedArrival() async {
    var position = ref.read(driverLocationProvider).valueOrNull;
    if (position == null ||
        DateTime.now().difference(position.timestamp).inSeconds > 30) {
      await ref.read(driverLocationProvider.notifier).refresh();
      position = ref.read(driverLocationProvider).valueOrNull;
    }
    if (position == null) {
      throw const RideVerificationException('driver_location_unavailable');
    }
    final result = await const RideVerificationService().requestDriverArrival(
      rideId: widget.rideId,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      speedKmh: position.speed.isFinite ? position.speed * 3.6 : 0,
      recordedAt: position.timestamp,
    );
    if (result['verified'] == true || result['status'] == 'driver_arrived') {
      return true;
    }
    final retrySeconds = (result['retry_after_seconds'] as num?)?.toInt() ?? 10;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Arrival is being verified. Stay near the pickup for $retrySeconds seconds.',
          ),
        ),
      );
    }
    _arrivalVerificationTimer?.cancel();
    _arrivalVerificationTimer = Timer(Duration(seconds: retrySeconds), () {
      if (mounted && !_loading) unawaited(_markArrived());
    });
    return false;
  }

  Future<void> _hydrateEnRouteState() async {
    try {
      final row = await HeyCabySupabase.client
          .from('ride_requests')
          .select('status')
          .eq('id', widget.rideId)
          .maybeSingle();
      if (!mounted || row == null) return;
      final status = row['status'] as String?;
      if (status == 'driver_en_route') {
        setState(() => _enRouteStarted = true);
      }
    } catch (_) {}
  }

  Future<void> _loadFarePill() async {
    try {
      final row = await HeyCabySupabase.client
          .from('ride_requests')
          .select(
            'quoted_fare, offered_fare, estimated_fare, final_fare, marketplace_offered_fare, currency',
          )
          .eq('id', widget.rideId)
          .maybeSingle();
      if (!mounted || row == null) return;
      final fareAmount = HeyCabyRideFare.resolveEuroFromRow(
        Map<String, dynamic>.from(row),
      );
      if (fareAmount == null) return;
      final currency = (row['currency'] as String?)?.trim().toUpperCase();
      final prefix =
          (currency == null || currency == 'EUR') ? 'EUR ' : '$currency ';
      setState(
        () => _farePill = driverRideBoltFarePill(
          '$prefix${fareAmount.toStringAsFixed(2)}',
        ),
      );
    } catch (_) {}
  }

  void _openSafety() {
    final colors = DriverColors.fromTheme(ref.read(colorsProvider));
    final typography = DriverTypography.fromTheme(ref.read(typographyProvider));
    unawaited(showDriverRideSafetyToolkitSheet(
      context: context,
      ref: ref,
      colors: colors,
      typography: typography,
      rideRequestId: widget.rideId,
      canShareTrip: true,
    ));
  }

  Future<void> _markArrived() async {
    setState(() => _loading = true);
    try {
      final allowed = await checkDriverRideProximity(
        context: context,
        ref: ref,
        rideId: widget.rideId,
        action: 'arrive_pickup',
      );
      if (!allowed) return;
      final verificationEnabled = ref
              .read(driverRemoteConfigProvider)
              .valueOrNull
              ?.arrivalVerificationEnabled ==
          true;
      if (verificationEnabled) {
        if (!await _requestVerifiedArrival()) return;
      } else {
        await ref
            .read(driverApiProvider)
            .markArrived(rideRequestId: widget.rideId);
      }
      unawaited(
        const DriverAutomaticPingService().sendIfNeeded(
          rideRequestId: widget.rideId,
          type: DriverPingType.arrived,
        ),
      );
      await const DriverPickupWaitService().recordStarted(widget.rideId);
      ref.read(driverStateProvider.notifier).setStatus(DriverAppState.arrived);
      if (!mounted) return;
      context.go('/driver/ride/pickup/${widget.rideId}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(driverRideLifecycleErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNavigationApp() async {
    final driver = ref.read(driverStateProvider);
    final pickupAddress = driver.pickupAddress ?? DriverStrings.pickupAddress;
    await launchDriverNavigation(
      context: context,
      ref: ref,
      lat: driver.pickupLat,
      lng: driver.pickupLng,
      addressFallback: pickupAddress,
      coordinatesUnavailableMessage: DriverStrings.pickupCoordinatesUnavailable,
    );
  }

  Future<void> _startTripToPickup() async {
    if (_startingTrip) return;
    setState(() => _startingTrip = true);
    var statusOk = _enRouteStarted;
    try {
      if (!_enRouteStarted) {
        try {
          await ref
              .read(driverApiProvider)
              .markEnRoute(rideRequestId: widget.rideId);
          statusOk = true;
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(driverRideLifecycleErrorMessage(e))),
          );
        }

        if (statusOk) {
          if (!mounted) return;
          setState(() => _enRouteStarted = true);
          final navLabel = watchDriverNavAppLabel(ref);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                DriverStrings.startTripRiderNotifiedOpensIn(navLabel),
              ),
            ),
          );
          unawaited(
            sendDriverRiderPing(
              context: context,
              ref: ref,
              rideRequestId: widget.rideId,
              type: DriverPingType.onMyWay,
              silent: true,
            ),
          );
        }
      }
      await _openNavigationApp();
    } finally {
      if (mounted) setState(() => _startingTrip = false);
    }
  }

  Future<void> _toggleNewRequests() async {
    if (_statusBusy) return;
    setState(() => _statusBusy = true);
    final driver = ref.read(driverStateProvider);
    final currentlyOnBreak = driver.appState == DriverAppState.onBreak;
    final nextStatus = currentlyOnBreak ? 'available' : 'on_break';
    final nextAppState = currentlyOnBreak
        ? DriverAppState.onlineAvailable
        : DriverAppState.onBreak;
    try {
      await ref.read(driverApiProvider).setStatus(status: nextStatus);
      ref.read(driverStateProvider.notifier).setStatus(nextAppState);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentlyOnBreak
                ? DriverStrings.requestsResumed
                : DriverStrings.requestsPaused,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(DriverStrings.requestStatusUpdateFailedMessage),
        ),
      );
    } finally {
      if (mounted) setState(() => _statusBusy = false);
    }
  }

  Future<void> _cancelOrder() async {
    await confirmAndCancelDriverRide(
      context: context,
      ref: ref,
      rideId: widget.rideId,
    );
  }

  void _openCommunication() {
    unawaited(showDriverRideCommunicationSheet(
      context: context,
      ref: ref,
      rideRequestId: widget.rideId,
      phase: DriverRideCommunicationPhase.enRouteToPickup,
      distanceToPickupM: readDistanceToPickupM(ref),
      onOpenChat: () => context.push('/driver/chat/${widget.rideId}'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final driver = ref.watch(driverStateProvider);
    final proximity = ref.watch(driverRideProximityProvider);
    final driverPos = ref.watch(driverLocationProvider).valueOrNull;

    return DriverActiveTripBody(
      rideId: widget.rideId,
      colors: colors,
      typography: typography,
      pickupAddress: driver.pickupAddress ?? DriverStrings.pickupAddress,
      destinationAddress:
          driver.destinationAddress ?? DriverStrings.destination,
      riderName: driver.riderContactName,
      requestsPaused: driver.appState == DriverAppState.onBreak,
      statusBusy: _statusBusy,
      arriving: _loading,
      pickupLat: driver.pickupLat,
      pickupLng: driver.pickupLng,
      destLat: driver.destinationLat,
      destLng: driver.destinationLng,
      driverLat: driverPos?.latitude,
      driverLng: driverPos?.longitude,
      farePill: _farePill,
      onArrived: _markArrived,
      onNavigate: _startTripToPickup,
      onOpenCommunication: _openCommunication,
      onCancelOrder: _cancelOrder,
      onToggleRequests: _toggleNewRequests,
      onSafety: _openSafety,
      showNearPickupAssist: proximity == DriverRideProximityAssist.nearPickup,
    );
  }
}
