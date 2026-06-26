import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_ride_proximity_provider.dart';
import '../providers/driver_state_provider.dart';
import '../services/driver_automatic_ping_service.dart';
import '../services/driver_pickup_wait_service.dart';
import '../utils/driver_cancel_ride_flow.dart';
import '../utils/driver_communication_distance.dart';
import '../widgets/driver_ride_communication_sheet.dart';
import '../widgets/driver_smart_ping_banner.dart';
import '../utils/driver_navigation_launch.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
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

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/driver');
  }

  Future<void> _markArrived() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(driverApiProvider)
          .markArrived(rideRequestId: widget.rideId);
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
        SnackBar(content: Text('${DriverStrings.actionFailedPrefix} $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNavigationApp() async {
    final driver = ref.read(driverStateProvider);
    await launchDriverNavigation(
      context: context,
      ref: ref,
      lat: driver.pickupLat,
      lng: driver.pickupLng,
      coordinatesUnavailableMessage: DriverStrings.pickupCoordinatesUnavailable,
    );
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${DriverStrings.requestStatusUpdateFailed} $e'),
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
    final typography = DriverTypography.fromTheme(ref.watch(typographyProvider));
    final driver = ref.watch(driverStateProvider);
    final proximity = ref.watch(driverRideProximityProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DriverSmartPingBanner(
          rideRequestId: widget.rideId,
          phase: DriverRideCommunicationPhase.enRouteToPickup,
        ),
        Expanded(
          child: DriverActiveTripBody(
      colors: colors,
      typography: typography,
      pickupAddress: driver.pickupAddress ?? DriverStrings.pickupAddress,
      destinationAddress:
          driver.destinationAddress ?? DriverStrings.destination,
      riderName: driver.riderContactName,
      requestsPaused: driver.appState == DriverAppState.onBreak,
      statusBusy: _statusBusy,
      arriving: _loading,
      onBack: _handleBack,
      onArrived: _markArrived,
      onNavigate: _openNavigationApp,
      onOpenCommunication: _openCommunication,
      onCancelOrder: _cancelOrder,
      onToggleRequests: _toggleNewRequests,
      showNearPickupAssist:
          proximity == DriverRideProximityAssist.nearPickup,
          ),
        ),
      ],
    );
  }
}
