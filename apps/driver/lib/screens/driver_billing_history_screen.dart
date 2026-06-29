import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../models/driver_payment_ledger_item.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_billing_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_payment_history_body.dart';

class DriverBillingHistoryScreen extends ConsumerWidget {
  const DriverBillingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final ledgerAsync = ref.watch(driverPaymentLedgerProvider);
    final billingStatusAsync = ref.watch(driverBillingStatusProvider);

    final loading = ledgerAsync.isLoading || billingStatusAsync.isLoading;
    String? errorMessage;
    List<DriverPaymentHistoryEntry> entries = const [];

    if (ledgerAsync.hasError) {
      errorMessage = DriverStrings.platformFeeStatusError;
    } else if (!loading) {
      final ledger = ledgerAsync.valueOrNull ?? const [];
      final status = billingStatusAsync.valueOrNull;
      entries = _mergeLedgerWithStatus(ledger, status);
    }

    return DriverPaymentHistoryBody(
      colors: colors,
      typography: typography,
      entries: entries,
      loading: loading,
      errorMessage: errorMessage,
      onBack: () => context.pop(),
      onRefresh: () async {
        ref.invalidate(driverPaymentLedgerProvider);
        ref.invalidate(driverBillingStatusProvider);
        await ref.read(driverPaymentLedgerProvider.future);
      },
    );
  }

  List<DriverPaymentHistoryEntry> _mergeLedgerWithStatus(
    List<DriverPaymentLedgerItem> ledger,
    Map<String, dynamic>? status,
  ) {
    if (ledger.isNotEmpty) {
      final rows = ledger
          .map(
            (p) => DriverPaymentHistoryEntry(
              title: p.title,
              subtitle: p.subtitle,
              amountLabel: p.amountLabel,
              statusLabel: p.statusLabel,
            ),
          )
          .toList();
      return rows;
    }

    if (DriverBillingService.isLedgerV1(status)) {
      final outstanding = status?['outstanding_cents'];
      if (outstanding is num) {
        return [
          DriverPaymentHistoryEntry(
            title: DriverStrings.platformBalanceTitle,
            subtitle: outstanding > 0
                ? DriverStrings.platformBalanceOutstanding
                : DriverStrings.platformBalanceCurrent,
            amountLabel: '€${(outstanding / 100).toStringAsFixed(2)}',
          ),
        ];
      }
    }

    final out = <DriverPaymentHistoryEntry>[];
    if (status != null) {
      void addDate(String key, String title) {
        final v = status[key];
        if (v is! String || v.trim().isEmpty) return;
        final dt = DateTime.tryParse(v.trim());
        if (dt == null) return;
        final local = dt.toLocal();
        final sub =
            '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
        out.add(DriverPaymentHistoryEntry(title: title, subtitle: sub));
      }

      addDate('last_payment_at', 'Last payment');
      addDate('due_at', DriverStrings.platformBalanceOutstanding);
      addDate('grace_until_at', DriverStrings.platformBalanceSettleBalance);
    }
    return out;
  }
}
