import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_state_provider.dart';
import '../services/driver_automatic_ping_service.dart';
import '../services/sound_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_opportunity_screen_body.dart';

/// **Opportunity Screen** — accept or decline in &lt; 1 second.
class NewRideRequestScreen extends ConsumerStatefulWidget {
  const NewRideRequestScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<NewRideRequestScreen> createState() =>
      _NewRideRequestScreenState();
}

class _NewRideRequestScreenState extends ConsumerState<NewRideRequestScreen> {
  static const _countdownTotal = 30;

  Map<String, dynamic>? _rideData;
  String? _error;
  int _countdown = _countdownTotal;
  Timer? _countdownTimer;
  bool _isAccepting = false;
  bool _isDeclining = false;

  @override
  void initState() {
    super.initState();
    _loadRide();
    HapticService.heavyTap();
    SoundService().playRideRequest();
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
    SoundService().stopRideRequest();
    super.dispose();
  }

  Future<void> _loadRide() async {
    try {
      final res = await HeyCabySupabase.client
          .from('ride_requests')
          .select()
          .eq('id', widget.rideId)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _rideData = res;
        _error = res == null ? DriverStrings.rideNotFound : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = DriverStrings.rideRequestLoadFailedMessage);
    }
  }

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

  Future<void> _acceptRide() async {
    if (_isAccepting) return;
    setState(() => _isAccepting = true);
    _countdownTimer?.cancel();
    SoundService().stopRideRequest();

    try {
      await ref
          .read(driverApiProvider)
          .acceptRide(rideRequestId: widget.rideId);
      SoundService().playRideAccepted();
      HapticService.success();
      final r = _rideData;
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
    } on DriverAcceptRideException {
      if (!mounted) return;
      setState(() => _isAccepting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(DriverStrings.acceptRideFailedMessage),
        ),
      );
      context.go('/driver');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isAccepting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.acceptRideFailedMessage)),
      );
      context.go('/driver');
    }
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
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded,
            color: themeColors.warning, size: 36),
        title: Text(
          DriverStrings.missedRequestTitle,
          style: typo.titleMedium.copyWith(
            color: themeColors.text,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          DriverStrings.missedRequestBody,
          style: typo.bodyMedium
              .copyWith(color: themeColors.textMid, height: 1.35),
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(DriverStrings.close),
            ),
          ),
        ],
      ),
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
      countdownSeconds: _countdown,
      totalCountdownSeconds: _countdownTotal,
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
