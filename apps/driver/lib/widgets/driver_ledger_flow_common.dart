import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_app_bar.dart';
import '../ui/driver_card.dart';
import '../ui/driver_status_badge.dart';
import 'driver_money_flow_common.dart';

/// Shared scaffold for trip ledger screens.
class DriverLedgerFlowScaffold extends StatelessWidget {
  const DriverLedgerFlowScaffold({
    super.key,
    required this.title,
    required this.colors,
    required this.typography,
    required this.onBack,
    required this.body,
    this.centerTitle = true,
  });

  final String title;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onBack;
  final Widget body;
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: DriverAppBar(
        title: title,
        colors: colors,
        typography: typography,
        centerTitle: centerTitle,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.text),
          onPressed: onBack,
        ),
      ),
      body: body,
    );
  }
}

/// Compact row for Today's Ledger — route + fare + time at a glance.
class DriverLedgerCompactRow extends StatelessWidget {
  const DriverLedgerCompactRow({
    super.key,
    required this.routeLabel,
    required this.fareLabel,
    required this.timeLabel,
    required this.colors,
    required this.typography,
    this.onTap,
  });

  final String routeLabel;
  final String fareLabel;
  final String timeLabel;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: DriverSpacing.lg,
        vertical: DriverSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: DriverSpacing.md),
          Expanded(
            child: Text(
              routeLabel,
              style: typography.bodyMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: DriverSpacing.sm),
          Text(
            fareLabel,
            style: typography.labelLarge.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: DriverSpacing.sm),
          Text(
            timeLabel,
            style: typography.bodySmall.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Display model for history list cards.
class DriverLedgerHistoryItem {
  const DriverLedgerHistoryItem({
    required this.dateLabel,
    required this.pickupLabel,
    required this.dropoffLabel,
    required this.fareLabel,
    required this.statusLabel,
    required this.statusTone,
  });

  final String dateLabel;
  final String pickupLabel;
  final String dropoffLabel;
  final String fareLabel;
  final String statusLabel;
  final DriverStatusTone statusTone;
}

/// Label / value pair for trip receipt.
class DriverLedgerDetailItem {
  const DriverLedgerDetailItem({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;
}

/// Receipt hero — fare headline for trip detail.
class DriverLedgerReceiptHero extends StatelessWidget {
  const DriverLedgerReceiptHero({
    super.key,
    required this.fareLabel,
    required this.subtitle,
    required this.colors,
    required this.typography,
    this.statusLabel,
    this.statusTone = DriverStatusTone.success,
  });

  final String fareLabel;
  final String subtitle;
  final String? statusLabel;
  final DriverStatusTone statusTone;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      padding: const EdgeInsets.all(DriverSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (statusLabel != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: DriverStatusBadge(
                label: statusLabel!,
                colors: colors,
                typography: typography,
                tone: statusTone,
              ),
            ),
            const SizedBox(height: DriverSpacing.md),
          ],
          Text(
            fareLabel,
            style: typography.displaySmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DriverSpacing.xs),
          Text(
            subtitle,
            style: typography.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Detail rows block for trip receipt — reuses money key/value styling.
class DriverLedgerDetailList extends StatelessWidget {
  const DriverLedgerDetailList({
    super.key,
    required this.items,
    required this.colors,
    required this.typography,
  });

  final List<DriverLedgerDetailItem> items;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            DriverMoneyKeyValueRow(
              label: items[i].label,
              value: items[i].value,
              colors: colors,
              typography: typography,
              valueColor: items[i].emphasize ? colors.primary : null,
            ),
            if (i < items.length - 1)
              Divider(
                height: 1,
                color: colors.border.withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }
}
