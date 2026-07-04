import 'package:flutter/material.dart';
import 'package:heycaby_driver/l10n/driver_strings.dart';
import 'package:heycaby_driver/models/driver_payment_ledger_item.dart';
import 'package:heycaby_driver/services/driver_data_service.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_driver/ui/driver_status_badge.dart';
import 'package:heycaby_driver/widgets/driver_earnings_hub_body.dart';
import 'package:heycaby_driver/widgets/driver_payment_history_body.dart';
import 'package:heycaby_driver/widgets/driver_platform_balance_body.dart';

/// Golden preview — Earnings Hub with mock metrics.
class DriverEarningsHubPreview extends StatelessWidget {
  const DriverEarningsHubPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  static const _metrics = DriverFinanceMetrics(
    grossEarnings: 1842.75,
    netEarnings: 1624.50,
    totalRides: 47,
    totalKilometers: 312.4,
    platformFees: 218.25,
    tips: 86.00,
    completedRides: 44,
    cancelledRides: 3,
    cancellationFees: 12.00,
  );

  static final _ledger = [
    DriverPaymentLedgerItem(
      id: '1',
      title: 'Ritbetaling',
      subtitle: '2026-05-18 · 14:32',
      sortDate: DateTime(2026, 5, 18, 14, 32),
      amountLabel: '€ 42,50',
    ),
    DriverPaymentLedgerItem(
      id: '2',
      title: 'Ritbetaling',
      subtitle: '2026-05-18 · 09:15',
      sortDate: DateTime(2026, 5, 18, 9, 15),
      amountLabel: '€ 28,00',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DriverEarningsHubBody(
      colors: colors,
      typography: typography,
      selectedFilter: DriverFinanceDateFilter.thisMonth,
      rangeLabel: 'Deze maand',
      metrics: _metrics,
      metricsLoading: false,
      metricsError: false,
      ledgerItems: _ledger,
      ledgerLoading: false,
      accountantEmail: 'boekhouder@example.nl',
      exporting: false,
      onBack: () {},
      onFilterSelected: (_) {},
      onExport: () {},
      onViewAllRides: () {},
      onEditAccountantEmail: () {},
    );
  }
}

/// Golden preview — Platform Balance (current driver).
class DriverPlatformBalancePreview extends StatelessWidget {
  const DriverPlatformBalancePreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  static final _summary = DriverPlatformBalanceSummary(
    outstandingDisplay: '€0.00',
    statusLine: DriverStrings.platformBalanceCurrent,
    statusTone: DriverStatusTone.success,
    dueLine: DriverStrings.platformBalanceCurrentBody,
    rideRequestsPaused: false,
    paymentPending: false,
    canSettle: false,
    isCurrent: true,
  );

  @override
  Widget build(BuildContext context) {
    return DriverPlatformBalanceBody(
      colors: colors,
      typography: typography,
      summary: _summary,
      loading: false,
      errorMessage: null,
      onBack: () {},
      onViewHistory: () {},
      onSettleBalance: null,
    );
  }
}

/// Golden preview — Payment History with sample rows.
class DriverPaymentHistoryPreview extends StatelessWidget {
  const DriverPaymentHistoryPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  static const _entries = [
    DriverPaymentHistoryEntry(
      title: 'Platformtoegang',
      subtitle: '2026-05-12 · 08:00',
      amountLabel: '€ 12,50',
      statusLabel: 'paid',
    ),
    DriverPaymentHistoryEntry(
      title: 'Platformtoegang',
      subtitle: '2026-05-05 · 08:00',
      amountLabel: '€ 12,50',
      statusLabel: 'paid',
    ),
    DriverPaymentHistoryEntry(
      title: 'Platformtoegang',
      subtitle: '2026-04-28 · 08:00',
      amountLabel: '€ 12,50',
      statusLabel: 'paid',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DriverPaymentHistoryBody(
      colors: colors,
      typography: typography,
      entries: _entries,
      loading: false,
      errorMessage: null,
      onBack: () {},
    );
  }
}
