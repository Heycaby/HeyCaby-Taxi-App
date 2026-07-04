import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';
import '../services/driver_data_service.dart';
import '../utils/driver_runtime_refresh.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_reward_screen_body.dart';

/// **Reward Screen** — celebrate completion; record payment; rate rider.
class RideCompleteScreen extends ConsumerStatefulWidget {
  const RideCompleteScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<RideCompleteScreen> createState() => _RideCompleteScreenState();
}

class _RideCompleteScreenState extends ConsumerState<RideCompleteScreen> {
  bool _sendingReceipt = false;
  bool _returnModePromptShown = false;
  String? _expectedLabel;
  num? _expectedAmount;
  String _method = 'cash';
  final TextEditingController _paidCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExpectedAmount();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeShowReturnModePrompt());
    });
  }

  @override
  void dispose() {
    _paidCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExpectedAmount() async {
    try {
      final row = await HeyCabySupabase.client
          .from('ride_requests')
          .select(
            'quoted_fare, offered_fare, estimated_fare, final_fare, currency, waiting_fee_cents, waiting_fee_waived',
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
      final waitingFeeCents = row['waiting_fee_cents'];
      final waitingFeeWaived = row['waiting_fee_waived'] == true;
      final waitingAmount = waitingFeeWaived || waitingFeeCents is! num
          ? 0.0
          : waitingFeeCents.toDouble() / 100;
      final totalAmount = amountValue + waitingAmount;
      final currency = (row['currency'] as String?)?.trim().toUpperCase();
      final prefix =
          (currency == null || currency == 'EUR') ? 'EUR ' : '$currency ';
      setState(() {
        _expectedAmount = totalAmount;
        _expectedLabel = '$prefix${totalAmount.toStringAsFixed(2)}';
        _paidCtrl.text = totalAmount.toStringAsFixed(2);
      });
    } catch (_) {}
  }

  Future<void> _sendReceipt() async {
    final paid = num.tryParse(_paidCtrl.text.replaceAll(',', '.').trim());
    if (paid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(DriverStrings.enterValidPaidAmount)),
      );
      return;
    }
    setState(() => _sendingReceipt = true);
    try {
      await ref.read(driverApiProvider).createReceipt(payload: {
        'ride_request_id': widget.rideId,
        'payer': 'rider',
        'payee': 'driver',
        'expected_amount': _expectedAmount,
        'paid_amount': paid,
        'payment_method': _method,
        'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(DriverStrings.receiptSent)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(DriverStrings.receiptSendFailed)),
      );
    } finally {
      if (mounted) setState(() => _sendingReceipt = false);
    }
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/driver');
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
                    pickupRadiusKm: status.pickupRadiusKm,
                    returnDiscountPct: status.returnDiscountPct > 0
                        ? status.returnDiscountPct
                        : 15,
                  );
          ref.invalidate(driverReturnModeProvider);
          ref.invalidate(driverProfileProvider);
          ref.invalidate(driverRateProfilesProvider);
          ref.invalidate(activeRateProfileProvider);
          ref.invalidate(filteredReturnTripsProvider);
          if (ctx.mounted) Navigator.of(ctx).pop();
          if (!mounted || result.ok) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(DriverStrings.returnModeActivationFailed)),
          );
        },
        onDismiss: () async {
          await ref.read(driverDataServiceProvider).dismissReturnModePrompt();
          ref.invalidate(driverReturnModeProvider);
          if (ctx.mounted) Navigator.of(ctx).pop();
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

    return DriverRewardScreenBody(
      colors: colors,
      typography: typography,
      destinationAddress:
          driver.destinationAddress ?? DriverStrings.destination,
      expectedLabel: _expectedLabel,
      paidController: _paidCtrl,
      noteController: _noteCtrl,
      paymentMethod: _method,
      sendingReceipt: _sendingReceipt,
      onPaymentMethodChanged: (v) => setState(() => _method = v),
      onSendReceipt: _sendReceipt,
      onRateRider: () => context.push('/driver/ride/rate/${widget.rideId}'),
      onSkip: () {
        ref.read(driverStateProvider.notifier).clearActiveRide();
        unawaited(refreshDriverRuntime(ref));
        context.go('/driver');
      },
      onBack: _handleBack,
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
  });

  final DriverReturnModeStatus status;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final Future<void> Function() onActivate;
  final Future<void> Function() onDismiss;

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
                  Icons.keyboard_backspace_rounded,
                  color: colors.success,
                  size: 28,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                DriverStrings.returnModeHeadingHomeTitle,
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
                        discountPct: status.returnDiscountPct > 0
                            ? status.returnDiscountPct
                            : 15,
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
                child: Text(DriverStrings.returnModeActivate),
              ),
              const SizedBox(height: 10),
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
