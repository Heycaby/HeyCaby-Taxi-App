import 'dart:async' show unawaited, Timer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_utils/heycaby_utils.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_location_provider.dart';
import '../providers/driver_ride_proximity_provider.dart';
import '../providers/driver_state_provider.dart';
import '../providers/driver_taxi_terug_queued_provider.dart';
import '../services/sound_service.dart';
import '../utils/driver_cancel_ride_flow.dart';
import '../utils/driver_navigation_launch.dart';
import '../utils/driver_ride_coord_utils.dart';
import '../utils/driver_ride_lifecycle_error_message.dart';
import '../utils/driver_ride_proximity_gate.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_ride_communication_sheet.dart';
import '../widgets/driver_ride_bolt_layout.dart';
import '../widgets/driver_navigation_focus_body.dart';

/// **Navigation Focus** — driving-first; minimal distraction.
class RideInProgressScreen extends ConsumerStatefulWidget {
  const RideInProgressScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<RideInProgressScreen> createState() =>
      _RideInProgressScreenState();
}

class _RideInProgressScreenState extends ConsumerState<RideInProgressScreen> {
  bool _loading = false;
  bool _statusBusy = false;
  String? _expectedAmountLabel;
  Timer? _fareRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadExpectedAmount();
    _fareRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _loadExpectedAmount();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(hydrateDriverRideCoordsIfNeeded(ref, widget.rideId));
      ref.invalidate(driverTaxiTerugQueuedProvider);
    });
  }

  @override
  void dispose() {
    _fareRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadExpectedAmount() async {
    try {
      final row = await HeyCabySupabase.client
          .from('ride_requests')
          .select(
            'quoted_fare, offered_fare, estimated_fare, final_fare, marketplace_offered_fare, currency, waiting_fee_cents, waiting_fee_waived',
          )
          .eq('id', widget.rideId)
          .maybeSingle();
      if (!mounted || row == null) return;
      final totalEuro = HeyCabyRideFare.resolveTotalEuroFromRow(
        Map<String, dynamic>.from(row),
      );
      if (totalEuro == null) return;
      final currency = (row['currency'] as String?)?.trim().toUpperCase();
      final prefix =
          (currency == null || currency == 'EUR') ? 'EUR ' : '$currency ';
      setState(
        () => _expectedAmountLabel = '$prefix${totalEuro.toStringAsFixed(2)}',
      );
    } catch (_) {}
  }

  Future<void> _completeRide() async {
    setState(() => _loading = true);
    try {
      final allowed = await checkDriverRideProximity(
        context: context,
        ref: ref,
        rideId: widget.rideId,
        action: 'complete_dropoff',
        onExitRide: () async {
          if (mounted) setState(() => _loading = false);
          await _cancelRide();
        },
      );
      if (!allowed) return;
      await ref
          .read(driverApiProvider)
          .completeRide(rideRequestId: widget.rideId);
      ref
          .read(driverStateProvider.notifier)
          .setStatus(DriverAppState.completed);
      SoundService().playTripComplete();
      if (!mounted) return;
      context.go('/driver/ride/complete/${widget.rideId}');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(driverRideLifecycleErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNavigationApp() async {
    final driver = ref.read(driverStateProvider);
    final destinationAddress =
        driver.destinationAddress ?? DriverStrings.destination;
    await launchDriverNavigation(
      context: context,
      ref: ref,
      lat: driver.destinationLat,
      lng: driver.destinationLng,
      addressFallback: destinationAddress,
      coordinatesUnavailableMessage:
          DriverStrings.destinationCoordinatesUnavailable,
    );
  }

  Future<void> _cancelRide() async {
    if (_loading) return;
    setState(() => _loading = true);
    await confirmAndCancelDriverRide(
      context: context,
      ref: ref,
      rideId: widget.rideId,
      rideInProgress: true,
    );
    if (mounted) setState(() => _loading = false);
  }

  void _openCommunication() {
    unawaited(showDriverRideCommunicationSheet(
      context: context,
      ref: ref,
      rideRequestId: widget.rideId,
      phase: DriverRideCommunicationPhase.inProgress,
      distanceToPickupM: null,
      onOpenChat: () => context.push('/driver/chat/${widget.rideId}'),
    ));
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

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final driver = ref.watch(driverStateProvider);
    final proximity = ref.watch(driverRideProximityProvider);
    final driverPos = ref.watch(driverLocationProvider).valueOrNull;

    return DriverNavigationFocusBody(
      colors: colors,
      typography: typography,
      pickupAddress: driver.pickupAddress ?? DriverStrings.pickupAddress,
      destinationAddress:
          driver.destinationAddress ?? DriverStrings.destination,
      riderName: driver.riderContactName,
      expectedAmountLabel: _expectedAmountLabel,
      completing: _loading,
      pickupLat: driver.pickupLat,
      pickupLng: driver.pickupLng,
      destLat: driver.destinationLat,
      destLng: driver.destinationLng,
      driverLat: driverPos?.latitude,
      driverLng: driverPos?.longitude,
      onNavigate: _openNavigationApp,
      onCompleteRide: _completeRide,
      onOpenCommunication: _openCommunication,
      onCancelRide: _cancelRide,
      onToggleRequests: _toggleNewRequests,
      onSafety: _openSafety,
      requestsPaused: driver.appState == DriverAppState.onBreak,
      statusBusy: _statusBusy,
      showNearDestinationAssist:
          proximity == DriverRideProximityAssist.nearDestination,
      currentRideId: widget.rideId,
    );
  }
}
