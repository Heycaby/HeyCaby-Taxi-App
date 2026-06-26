import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_state_provider.dart';
import '../services/driver_pickup_wait_service.dart';
import '../utils/driver_cancel_ride_flow.dart';
import '../utils/driver_communication_distance.dart';
import '../widgets/driver_ride_communication_sheet.dart';
import '../widgets/driver_smart_ping_banner.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_pickup_arrival_body.dart';

/// **Pickup Arrival** — confirm arrival; start trip friction-free.
class AtPickupScreen extends ConsumerStatefulWidget {
  const AtPickupScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<AtPickupScreen> createState() => _AtPickupScreenState();
}

class _AtPickupScreenState extends ConsumerState<AtPickupScreen> {
  bool _loading = false;
  int _waitSeconds = 0;
  Timer? _waitTimer;
  static const int _noShowAfterSeconds = 300;
  static const _pickupWaitService = DriverPickupWaitService();

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/driver');
  }

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrapWaitTimer());
  }

  Future<void> _bootstrapWaitTimer() async {
    final started = await _pickupWaitService.resolveStartedAt(widget.rideId);
    if (started != null) {
      _waitSeconds = _pickupWaitService.elapsedSeconds(started);
    } else {
      await _pickupWaitService.recordStarted(widget.rideId);
    }
    if (!mounted) return;
    _waitTimer?.cancel();
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _waitSeconds++);
    });
    setState(() {});
  }

  @override
  void dispose() {
    _waitTimer?.cancel();
    super.dispose();
  }

  Future<void> _startRide() async {
    setState(() => _loading = true);
    try {
      await ref.read(driverApiProvider).startRide(rideRequestId: widget.rideId);
      await _pickupWaitService.clear(widget.rideId);
      ref.read(driverStateProvider.notifier).setStatus(DriverAppState.inProgress);
      if (!mounted) return;
      context.go('/driver/ride/progress/${widget.rideId}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${DriverStrings.actionFailedPrefix} $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reportNoShow() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(DriverStrings.noShowConfirmTitle),
        content: const Text(DriverStrings.noShowConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(DriverStrings.back),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(DriverStrings.noShowConfirmAction),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await ref.read(driverApiProvider).reportNoShow(payload: {
        'ride_request_id': widget.rideId,
      });
      await _pickupWaitService.clear(widget.rideId);
      ref.read(driverStateProvider.notifier).clearActiveRide();
      if (!mounted) return;
      context.go('/driver');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(DriverStrings.noShowReported)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${DriverStrings.actionFailedPrefix} $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openCommunication() {
    unawaited(showDriverRideCommunicationSheet(
      context: context,
      ref: ref,
      rideRequestId: widget.rideId,
      phase: DriverRideCommunicationPhase.atPickup,
      distanceToPickupM: readDistanceToPickupM(ref),
      onOpenChat: () => context.push('/driver/chat/${widget.rideId}'),
    ));
  }

  Future<void> _cancelRide() async {
    if (_loading) return;
    setState(() => _loading = true);
    await confirmAndCancelDriverRide(
      context: context,
      ref: ref,
      rideId: widget.rideId,
      afterCancel: () => _pickupWaitService.clear(widget.rideId),
    );
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography = DriverTypography.fromTheme(ref.watch(typographyProvider));
    final driver = ref.watch(driverStateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DriverSmartPingBanner(
          rideRequestId: widget.rideId,
          phase: DriverRideCommunicationPhase.atPickup,
        ),
        Expanded(
          child: DriverPickupArrivalBody(
      colors: colors,
      typography: typography,
      pickupAddress: driver.pickupAddress ?? DriverStrings.pickupAddress,
      destinationAddress:
          driver.destinationAddress ?? DriverStrings.destination,
      riderName: driver.riderContactName,
      waitSeconds: _waitSeconds,
      canReportNoShow: _waitSeconds >= _noShowAfterSeconds,
      loading: _loading,
      onBack: _handleBack,
      onStartRide: _startRide,
      onOpenCommunication: _openCommunication,
      onReportNoShow: _reportNoShow,
      onCancelRide: _cancelRide,
          ),
        ),
      ],
    );
  }
}
