import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_state_provider.dart';
import '../utils/driver_runtime_refresh.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_reward_screen_body.dart';

/// **Reward Screen** — celebrate completion; record payment; rate rider.
class RideCompleteScreen extends ConsumerStatefulWidget {
  const RideCompleteScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<RideCompleteScreen> createState() =>
      _RideCompleteScreenState();
}

class _RideCompleteScreenState extends ConsumerState<RideCompleteScreen> {
  bool _sendingReceipt = false;
  String? _expectedLabel;
  num? _expectedAmount;
  String _method = 'cash';
  final TextEditingController _paidCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExpectedAmount();
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
      setState(() {
        _expectedAmount = amountValue;
        _expectedLabel = '$prefix${amountValue.toStringAsFixed(2)}';
        _paidCtrl.text = amountValue.toStringAsFixed(2);
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
        SnackBar(content: Text(DriverStrings.receiptSent)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.receiptSendFailed)),
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

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography = DriverTypography.fromTheme(ref.watch(typographyProvider));
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
