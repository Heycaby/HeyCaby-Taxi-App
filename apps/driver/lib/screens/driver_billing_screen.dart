import 'dart:async' show unawaited;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_status_badge.dart';
import '../utils/driver_runtime_refresh.dart';
import '../widgets/driver_bank_transfer_sheet.dart';
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
  final paymentPending = status?['payment_pending'] == true;
  final dueAt = _dateFrom(status, 'due_at');
  final graceUntil = _dateFrom(status, 'grace_until_at');
  final now = DateTime.now();

  if (paymentPending) return DriverStrings.platformBalancePaymentPendingBody;
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
  if (status?['payment_pending'] == true) return DriverStatusTone.warning;
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

Future<void> _refreshPlatformBalance(WidgetRef ref) async {
  ref.invalidate(driverBillingStatusProvider);
  ref.invalidate(driverPaymentLedgerProvider);
  await Future.wait([
    ref.read(driverBillingStatusProvider.future),
    ref.read(driverPaymentLedgerProvider.future),
    refreshDriverRuntime(ref),
  ]);
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
    final paymentPending = status?['payment_pending'] == true;
    final canSettle =
        outstanding > 0 && status?['can_settle_outstanding'] == true;

    final summary = DriverPlatformBalanceSummary(
      outstandingDisplay: _money(status, outstanding),
      statusLine: switch (state) {
        _ when paymentPending => DriverStrings.platformBalancePaymentPending,
        'paused' => DriverStrings.platformBalanceRequestsPaused,
        'due' => DriverStrings.platformBalanceOutstanding,
        _ => DriverStrings.platformBalanceCurrent,
      },
      statusTone: _statusTone(status),
      dueLine: _dueLine(status),
      rideRequestsPaused: rideRequestsPaused,
      paymentPending: paymentPending,
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
      onRefresh: () => _refreshPlatformBalance(ref),
    );
  }

  Future<void> _handleSettleBalance(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final api = ref.read(driverApiProvider);
    final status = ref.read(driverBillingStatusProvider).valueOrNull;
    final outstanding = status?['outstanding_cents'] is num
        ? (status!['outstanding_cents'] as num).toInt()
        : 0;
    final bankTransfer = DriverBankTransferDetails.fromBillingStatus(
      status,
      amount: _money(status, outstanding),
    );

    if (bankTransfer != null) {
      await showDriverBankTransferSheet(
        context: context,
        colors: DriverColors.fromTheme(colors),
        typography: DriverTypography.fromTheme(typo),
        details: bankTransfer,
        allowOnlineFallback: false,
      );
      if (context.mounted) _refreshAfterBalanceMutation(ref);
      return;
    }

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
          SnackBar(content: Text(DriverStrings.platformFeeStartError)),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final uri = Uri.tryParse(url);
    final opened = uri != null &&
        uri.scheme == 'https' &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;

    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(DriverStrings.platformBalanceBrowserOpenFailed),
        ),
      );
      return;
    }

    _refreshAfterBalanceMutation(ref);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(DriverStrings.platformBalanceBrowserOpened)),
    );
  }
}
