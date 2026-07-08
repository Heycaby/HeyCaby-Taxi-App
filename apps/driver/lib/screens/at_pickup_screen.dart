import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_utils/heycaby_utils.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_location_provider.dart';
import '../providers/driver_state_provider.dart';
import '../services/driver_pickup_wait_service.dart';
import '../utils/driver_cancel_ride_flow.dart';
import '../utils/driver_communication_distance.dart';
import '../utils/driver_navigation_launch.dart';
import '../utils/driver_ride_coord_utils.dart';
import '../widgets/driver_ride_communication_sheet.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_ride_bolt_layout.dart';
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
  bool _waivingWaitingFee = false;
  bool _waitingFeeWaived = false;
  bool _statusBusy = false;
  int _waitSeconds = 0;
  int _waitingGraceSeconds = 120;
  double _waitingRatePerMinute = 0;
  String? _farePill;
  Timer? _waitTimer;
  static const int _noShowAfterSeconds = 300;
  static const _pickupWaitService = DriverPickupWaitService();

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrapWaitTimer());
    unawaited(_loadFarePill());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(hydrateDriverRideCoordsIfNeeded(ref, widget.rideId));
    });
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

  Future<void> _bootstrapWaitTimer() async {
    await _loadWaitingContract();
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

  Future<void> _loadWaitingContract() async {
    try {
      final row = await HeyCabySupabase.client
          .from('ride_requests')
          .select(
            'waiting_grace_seconds, waiting_rate_per_minute, waiting_fee_waived',
          )
          .eq('id', widget.rideId)
          .maybeSingle();
      if (!mounted || row == null) return;
      final grace = row['waiting_grace_seconds'];
      final rate = row['waiting_rate_per_minute'];
      setState(() {
        _waitingGraceSeconds = grace is num
            ? grace.toInt().clamp(0, 3600).toInt()
            : _waitingGraceSeconds;
        _waitingRatePerMinute = rate is num
            ? rate.toDouble().clamp(0, 9999).toDouble()
            : _waitingRatePerMinute;
        _waitingFeeWaived = row['waiting_fee_waived'] == true;
      });
    } catch (_) {
      // Staging/prod may not have the migration yet; keep the existing wait UI.
    }
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
      ref
          .read(driverStateProvider.notifier)
          .setStatus(DriverAppState.inProgress);
      if (!mounted) return;
      await _openNavigationApp();
      if (!mounted) return;
      context.go('/driver/ride/progress/${widget.rideId}');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.rideActionFailedMessage)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reportNoShow() async {
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final confirm = await showHeyCabyConfirmSheet(
      context,
      colors: colors,
      typography: typo,
      title: DriverStrings.noShowConfirmTitle,
      message: DriverStrings.noShowConfirmBody,
      dismissLabel: DriverStrings.back,
      confirmLabel: DriverStrings.noShowConfirmAction,
      icon: Icons.person_off_rounded,
      confirmDestructive: true,
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.rideActionFailedMessage)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _waiveWaitingFee() async {
    if (_loading || _waivingWaitingFee || _waitingFeeWaived) return;
    setState(() => _waivingWaitingFee = true);
    try {
      await ref.read(driverApiProvider).waiveWaitingFee(
            rideRequestId: widget.rideId,
            reason: 'driver_discretion',
          );
      if (!mounted) return;
      setState(() => _waitingFeeWaived = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.waitingFeeWaivedNotice)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.rideActionFailedMessage)),
      );
    } finally {
      if (mounted) setState(() => _waivingWaitingFee = false);
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
    final typography =
        DriverTypography.fromTheme(ref.read(typographyProvider));
    unawaited(showDriverRideSafetyToolkitSheet(
      context: context,
      ref: ref,
      colors: colors,
      typography: typography,
      rideRequestId: widget.rideId,
      canShareTrip: true,
    ));
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

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final driver = ref.watch(driverStateProvider);
    final driverPos = ref.watch(driverLocationProvider).valueOrNull;

    return DriverPickupArrivalBody(
      colors: colors,
      typography: typography,
      rideId: widget.rideId,
      pickupAddress: driver.pickupAddress ?? DriverStrings.pickupAddress,
      destinationAddress:
          driver.destinationAddress ?? DriverStrings.destination,
      riderName: driver.riderContactName,
      waitSeconds: _waitSeconds,
      waitingGraceSeconds: _waitingGraceSeconds,
      waitingRatePerMinute: _waitingRatePerMinute,
      waitingFeeWaived: _waitingFeeWaived,
      canReportNoShow: _waitSeconds >= _noShowAfterSeconds,
      loading: _loading || _waivingWaitingFee,
      pickupLat: driver.pickupLat,
      pickupLng: driver.pickupLng,
      destLat: driver.destinationLat,
      destLng: driver.destinationLng,
      driverLat: driverPos?.latitude,
      driverLng: driverPos?.longitude,
      farePill: _farePill,
      onStartRide: _startRide,
      onOpenCommunication: _openCommunication,
      onNavigate: _openNavigationApp,
      onWaiveWaitingFee: _waiveWaitingFee,
      onReportNoShow: _reportNoShow,
      onCancelRide: _cancelRide,
      onToggleRequests: _toggleNewRequests,
      onSafety: _openSafety,
      requestsPaused: driver.appState == DriverAppState.onBreak,
      statusBusy: _statusBusy,
    );
  }
}
