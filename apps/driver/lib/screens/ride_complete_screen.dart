import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_utils/heycaby_utils.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';
import '../providers/driver_taxi_terug_stats_provider.dart';
import '../services/driver_data_service.dart';
import '../services/driver_operational_restore_service.dart';
import '../utils/driver_runtime_refresh.dart';
import '../utils/driver_today_rides_refresh.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_collect_payment_sheet.dart';
import '../widgets/driver_reward_screen_body.dart';
import '../widgets/driver_taxi_terug_wizard_sheet.dart';

/// **Reward Screen** — celebrate completion; collect payment; rate rider.
class RideCompleteScreen extends ConsumerStatefulWidget {
  const RideCompleteScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<RideCompleteScreen> createState() => _RideCompleteScreenState();
}

class _RideCompleteScreenState extends ConsumerState<RideCompleteScreen> {
  bool _returnModePromptShown = false;
  bool _paymentConfirmed = false;
  String? _expectedLabel;
  String? _baseFareLabel;
  String? _waitingFeeLabel;
  bool _waitingFeeWaived = false;
  num? _expectedAmount;
  RidePaymentMethod _initialMethod = RidePaymentMethod.cash;

  @override
  void initState() {
    super.initState();
    _loadExpectedAmount();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      invalidateTodayRideProviders(ref);
      unawaited(_runPostCompleteFlow());
    });
  }

  Future<void> _runPostCompleteFlow() async {
    await _showCollectPaymentSheet();
    if (!mounted || !_paymentConfirmed) return;
    await _maybeShowReturnModePrompt();
  }

  Future<void> _loadExpectedAmount() async {
    try {
      final row = await HeyCabySupabase.client
          .from('ride_requests')
          .select(
            'quoted_fare, offered_fare, estimated_fare, final_fare, marketplace_offered_fare, currency, waiting_fee_cents, waiting_fee_waived, payment_methods, payment_method',
          )
          .eq('id', widget.rideId)
          .maybeSingle();
      if (!mounted || row == null) return;
      final map = Map<String, dynamic>.from(row);
      final amountValue = HeyCabyRideFare.resolveEuroFromRow(map);
      if (amountValue == null) return;
      final waitingFeeWaived = row['waiting_fee_waived'] == true;
      final waitingFeeCents = row['waiting_fee_cents'];
      final waitingAmount = waitingFeeWaived || waitingFeeCents is! num
          ? 0.0
          : waitingFeeCents.toDouble() / 100;
      final totalAmount = amountValue + waitingAmount;
      final currency = (row['currency'] as String?)?.trim().toUpperCase();
      final prefix =
          (currency == null || currency == 'EUR') ? 'EUR ' : '$currency ';
      final methods = row['payment_methods'];
      final methodRaw = row['payment_method']?.toString();
      final bookingMethod = methods is List && methods.isNotEmpty
          ? methods.first.toString()
          : methodRaw;
      setState(() {
        _expectedAmount = totalAmount;
        _baseFareLabel = '$prefix${amountValue.toStringAsFixed(2)}';
        _waitingFeeLabel = '$prefix${waitingAmount.toStringAsFixed(2)}';
        _waitingFeeWaived = waitingFeeWaived;
        _expectedLabel = '$prefix${totalAmount.toStringAsFixed(2)}';
        _initialMethod = RidePaymentMethod.fromId(bookingMethod);
      });
    } catch (_) {}
  }

  Future<void> _showCollectPaymentSheet() async {
    if (!mounted || _paymentConfirmed) return;
    if (_expectedAmount == null) {
      await _loadExpectedAmount();
    }
    if (!mounted || _paymentConfirmed) return;
    final colors = DriverColors.fromTheme(ref.read(colorsProvider));
    final typography = DriverTypography.fromTheme(ref.read(typographyProvider));
    final fareEuro = _expectedAmount?.toDouble() ?? 0;
    final result = await showDriverCollectPaymentSheet(
      context,
      colors: colors,
      typography: typography,
      rideId: widget.rideId,
      fareEuro: fareEuro,
      initialMethod: _initialMethod,
    );
    if (!mounted) return;
    if (result?.confirmed == true) {
      invalidateTodayRideProviders(ref);
      setState(() => _paymentConfirmed = true);
      return;
    }
    // Sheet must be confirmed before leaving — re-prompt if needed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_showCollectPaymentSheet());
    });
  }

  Future<void> _maybeShowReturnModePrompt() async {
    if (_returnModePromptShown) return;
    final status =
        await ref.read(driverDataServiceProvider).getReturnModeStatus();
    if (!mounted || !status.canPrompt || !status.hasDestination) return;
    _returnModePromptShown = true;
    await ref.read(driverDataServiceProvider).recordReturnModePromptShown();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReturnModePromptSheet(
        status: status,
        colors: ref.read(colorsProvider),
        typo: ref.read(typographyProvider),
        onActivate: () async {
          final result =
              await ref.read(driverDataServiceProvider).activateReturnMode(
                    destinationLabel: status.destinationLabel,
                    destinationZoneId: status.destinationZoneId,
                    destinationLat: status.destinationLat,
                    destinationLng: status.destinationLng,
                    pickupRadiusKm: status.pickupRadiusKm,
                    returnDiscountPct: status.returnDiscountPct > 0
                        ? status.returnDiscountPct
                        : 15,
                    intentType: 'home',
                    destinationRadiusKm: status.destinationRadiusKm,
                  );
          ref.invalidate(driverReturnModeProvider);
          ref.invalidate(driverProfileProvider);
          ref.invalidate(driverRateProfilesProvider);
          ref.invalidate(activeRateProfileProvider);
          ref.invalidate(filteredReturnTripsProvider);
          if (ctx.mounted) Navigator.of(ctx).pop();
          if (!mounted || result.ok) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.activationErrorMessage)),
          );
        },
        onDismiss: () async {
          await ref.read(driverDataServiceProvider).dismissReturnModePrompt();
          ref.invalidate(driverReturnModeProvider);
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
        onChange: () async {
          if (ctx.mounted) Navigator.of(ctx).pop();
          if (!mounted) return;
          await showDriverTaxiTerugWizard(
            context,
            ref,
            initialPath: TaxiTerugWizardPath.goingHome,
            skipPathChoice: true,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final driver = ref.watch(driverStateProvider);

    if (!_paymentConfirmed) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: CircularProgressIndicator(color: colors.primary),
        ),
      );
    }

    return DriverRewardScreenBody(
      colors: colors,
      typography: typography,
      destinationAddress:
          driver.destinationAddress ?? DriverStrings.destination,
      expectedLabel: _expectedLabel,
      baseFareLabel: _baseFareLabel,
      waitingFeeLabel: _waitingFeeLabel,
      waitingFeeWaived: _waitingFeeWaived,
      paymentConfirmed: _paymentConfirmed,
      pickupLat: driver.pickupLat,
      pickupLng: driver.pickupLng,
      destLat: driver.destinationLat,
      destLng: driver.destinationLng,
      onRateRider: () => context.push('/driver/ride/rate/${widget.rideId}'),
      onSkip: () async {
        final wasPendingBreak = ref.read(driverStateProvider).pendingBreak;
        ref.read(driverStateProvider.notifier).clearActiveRide();
        if (wasPendingBreak) {
          unawaited(
            ref.read(driverApiProvider).setStatus(status: 'on_break'),
          );
        }
        unawaited(refreshDriverRuntime(ref));
        invalidateTodayRideProviders(ref);
        ref.invalidate(driverTaxiTerugStatsProvider);
        final resumed = await resumeActivatedTaxiTerugRideIfAny(
          ref,
          GoRouter.of(context),
        );
        if (!context.mounted) return;
        if (resumed) return;
        context.go('/driver');
      },
    );
  }
}

class _ReturnModePromptSheet extends StatelessWidget {
  const _ReturnModePromptSheet({
    required this.status,
    required this.colors,
    required this.typo,
    required this.onActivate,
    required this.onDismiss,
    required this.onChange,
  });

  final DriverReturnModeStatus status;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final Future<void> Function() onActivate;
  final Future<void> Function() onDismiss;
  final Future<void> Function() onChange;

  @override
  Widget build(BuildContext context) {
    final destination = status.destinationDisplay;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 28,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.home_rounded,
                  color: colors.success,
                  size: 28,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                DriverStrings.taxiTerugWizardHeadHome,
                style: typo.headingSmall.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DriverStrings.returnModeHeadingHomeBody(destination),
                style: typo.bodyMedium.copyWith(
                  color: colors.textMid,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (status.kmFromHome != null) ...[
                const SizedBox(height: 6),
                Text(
                  DriverStrings.returnModeKmFromHome(status.kmFromHome!),
                  style: typo.labelMedium.copyWith(
                    color: colors.success,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.success.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DriverStrings.returnModeHeadingTo(destination),
                      style: typo.titleSmall.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DriverStrings.returnModeActiveBody(
                        pickupRadiusKm: status.pickupRadiusKm,
                      ),
                      style: typo.bodySmall.copyWith(
                        color: colors.textMid,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: onActivate,
                child: Text(DriverStrings.taxiTerugWizardOneTapActivate),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: onChange,
                child: Text(DriverStrings.taxiTerugWizardChangeSettings),
              ),
              TextButton(
                onPressed: onDismiss,
                child: Text(DriverStrings.notNow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
