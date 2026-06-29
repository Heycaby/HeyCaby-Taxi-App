import 'dart:async' show unawaited;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_status_badge.dart';
import '../utils/driver_runtime_refresh.dart';
import '../widgets/driver_mollie_checkout_screen.dart';
import '../widgets/driver_platform_balance_body.dart';

String _money(Map<String, dynamic>? status, int cents) {
  final currency = (status?['currency'] as String?)?.trim().toUpperCase();
  final prefix = currency == null || currency == 'EUR' ? '€' : '$currency ';
  return '$prefix${(cents / 100).toStringAsFixed(2)}';
}

DateTime? _dateFrom(Map<String, dynamic>? status, String key) {
  final raw = status?[key];
  if (raw is! String || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw.trim())?.toLocal();
}

String? _dueLine(Map<String, dynamic>? status) {
  final state = (status?['balance_state'] as String?)?.trim();
  final dueAt = _dateFrom(status, 'due_at');
  final graceUntil = _dateFrom(status, 'grace_until_at');
  final now = DateTime.now();

  if (state == 'current') return DriverStrings.platformBalanceCurrentBody;
  if (state == 'paused') return DriverStrings.platformBalancePausedBody;

  final target = graceUntil ?? dueAt;
  if (target == null) return DriverStrings.platformBalanceDueBody;
  final days = target.difference(DateTime(now.year, now.month, now.day)).inDays;
  if (days <= 0) return DriverStrings.platformBalanceDueToday;
  if (days == 1) return DriverStrings.platformBalanceDueTomorrow;
  return DriverStrings.platformBalanceDueInDays(days);
}

DriverStatusTone _statusTone(Map<String, dynamic>? status) {
  final state = (status?['balance_state'] as String?)?.trim();
  if (state == 'paused') return DriverStatusTone.error;
  if (state == 'due') return DriverStatusTone.warning;
  return DriverStatusTone.success;
}

void _refreshAfterBalanceMutation(WidgetRef ref) {
  ref.invalidate(driverBillingStatusProvider);
  ref.invalidate(driverProfileProvider);
  ref.invalidate(driverPaymentLedgerProvider);
  unawaited(refreshDriverRuntime(ref));
}

class DriverBillingScreen extends ConsumerWidget {
  const DriverBillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(colorsProvider);
    final colors = DriverColors.fromTheme(tokens);
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final billingStatusAsync = ref.watch(driverBillingStatusProvider);

    if (billingStatusAsync.isLoading) {
      return DriverPlatformBalanceBody(
        colors: colors,
        typography: typography,
        summary: null,
        loading: true,
        errorMessage: null,
        onBack: () => context.pop(),
        onViewHistory: () {},
        onSettleBalance: null,
      );
    }

    if (billingStatusAsync.hasError) {
      return DriverPlatformBalanceBody(
        colors: colors,
        typography: typography,
        summary: null,
        loading: false,
        errorMessage: DriverStrings.platformFeeStatusError,
        onBack: () => context.pop(),
        onViewHistory: () {},
        onSettleBalance: null,
      );
    }

    final status = billingStatusAsync.valueOrNull;
    final outstanding = status?['outstanding_cents'] is num
        ? (status!['outstanding_cents'] as num).toInt()
        : 0;
    final state = (status?['balance_state'] as String?)?.trim() ?? 'current';
    final rideRequestsPaused = status?['ride_requests_paused'] == true;
    final canSettle =
        outstanding > 0 && status?['can_settle_outstanding'] == true;

    final summary = DriverPlatformBalanceSummary(
      outstandingDisplay: _money(status, outstanding),
      statusLine: switch (state) {
        'paused' => DriverStrings.platformBalanceRequestsPaused,
        'due' => DriverStrings.platformBalanceOutstanding,
        _ => DriverStrings.platformBalanceCurrent,
      },
      statusTone: _statusTone(status),
      dueLine: _dueLine(status),
      rideRequestsPaused: rideRequestsPaused,
      canSettle: canSettle,
      isCurrent: outstanding <= 0,
    );

    return DriverPlatformBalanceBody(
      colors: colors,
      typography: typography,
      summary: summary,
      loading: false,
      errorMessage: null,
      onBack: () => context.pop(),
      onViewHistory: () => context.push('/driver/billing/history'),
      onSettleBalance:
          canSettle ? () => _handleSettleBalance(context, ref) : null,
    );
  }

  Future<void> _handleSettleBalance(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final api = ref.read(driverApiProvider);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                DriverStrings.platformBalancePreparingSettlement,
                style: typo.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );

    Map<String, dynamic> created;
    try {
      created = await api.createDriverPlatformPayment();
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        final msg = e is DioException && e.response?.data is Map
            ? (e.response!.data['error']?.toString() ??
                DriverStrings.platformFeeStartError)
            : DriverStrings.platformFeeStartError;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
      return;
    }

    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

    final url = created['checkoutUrl'] as String?;
    if (url == null || url.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(DriverStrings.platformFeeStartError)),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final success = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DriverMollieCheckoutScreen(
          checkoutUrl: url,
          colors: colors,
          typo: typo,
          appBarTitle: DriverStrings.platformBalanceSettleBalance,
        ),
      ),
    );

    if (success == true && context.mounted) {
      final paymentId = created['mollie_payment_id']?.toString();
      if (paymentId != null && paymentId.isNotEmpty) {
        await api.syncDriverBillingPayment(paymentId);
      }
      _refreshAfterBalanceMutation(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DriverStrings.platformBalanceVerifyPayment)),
        );
      }
    }
  }
}
