import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_ride_proximity_provider.dart';
import '../providers/driver_state_provider.dart';
import '../services/sound_service.dart';
import '../utils/driver_cancel_ride_flow.dart';
import '../utils/driver_navigation_launch.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_ride_communication_sheet.dart';
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
  String? _expectedAmountLabel;

  @override
  void initState() {
    super.initState();
    _loadExpectedAmount();
  }

  Future<void> _loadExpectedAmount() async {
    try {
      final row = await HeyCabySupabase.client
          .from('ride_requests')
          .select(
            'quoted_fare, offered_fare, estimated_fare, final_fare, currency',
          )
          .eq('id', widget.rideId)
          .maybeSingle();
      if (!mounted || row == null) return;
      double? amount;
      for (final key in const [
        'final_fare',
        'quoted_fare',
        'offered_fare',
        'estimated_fare',
      ]) {
        final v = row[key];
        if (v is num) {
          amount = v.toDouble();
          break;
        }
      }
      final amountValue = amount;
      if (amountValue == null) return;
      final currency = (row['currency'] as String?)?.trim().toUpperCase();
      final prefix =
          (currency == null || currency == 'EUR') ? 'EUR ' : '$currency ';
      setState(
        () => _expectedAmountLabel = '$prefix${amountValue.toStringAsFixed(2)}',
      );
    } catch (_) {}
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/driver');
  }

  Future<void> _completeRide() async {
    final continueClose = await _confirmCollectionCheckpoint();
    if (continueClose != true) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(driverApiProvider)
          .completeRide(rideRequestId: widget.rideId);
      ref
          .read(driverStateProvider.notifier)
          .setStatus(DriverAppState.completed);
      SoundService().playTripComplete();
      if (!mounted) return;
      context.go('/driver/ride/complete/${widget.rideId}');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.rideActionFailedMessage)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool?> _confirmCollectionCheckpoint() {
    final themeColors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final amountLabel = _expectedAmountLabel;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon:
            Icon(Icons.payments_rounded, color: themeColors.warning, size: 34),
        title: Text(
          DriverStrings.collectPaymentTitle,
          style: typo.titleMedium.copyWith(
            color: themeColors.text,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DriverStrings.collectPaymentBody,
              textAlign: TextAlign.center,
              style: typo.bodyMedium.copyWith(color: themeColors.textMid),
            ),
            if (amountLabel != null) ...[
              const SizedBox(height: 10),
              Text(
                DriverStrings.collectPaymentAmount(amountLabel),
                textAlign: TextAlign.center,
                style: typo.bodyMedium.copyWith(
                  color: themeColors.warning,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(DriverStrings.collectPaymentBack),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(DriverStrings.collectPaymentContinue),
          ),
        ],
      ),
    );
  }

  Future<void> _openNavigationApp() async {
    final driver = ref.read(driverStateProvider);
    await launchDriverNavigation(
      context: context,
      ref: ref,
      lat: driver.destinationLat,
      lng: driver.destinationLng,
      addressFallback: driver.destinationAddress,
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

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final driver = ref.watch(driverStateProvider);
    final proximity = ref.watch(driverRideProximityProvider);

    return DriverNavigationFocusBody(
      colors: colors,
      typography: typography,
      pickupAddress: driver.pickupAddress ?? DriverStrings.pickupAddress,
      destinationAddress:
          driver.destinationAddress ?? DriverStrings.destination,
      riderName: driver.riderContactName,
      expectedAmountLabel: _expectedAmountLabel,
      completing: _loading,
      onBack: _handleBack,
      onNavigate: _openNavigationApp,
      onCompleteRide: _completeRide,
      onOpenCommunication: _openCommunication,
      onCancelRide: _cancelRide,
      showNearDestinationAssist:
          proximity == DriverRideProximityAssist.nearDestination,
    );
  }
}
