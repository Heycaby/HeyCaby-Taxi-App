import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_card.dart';
import '../ui/driver_empty_state.dart';
import '../ui/driver_skeleton.dart';
import 'driver_money_flow_common.dart';

/// One row in payment history — built by screen merge logic.
class DriverPaymentHistoryEntry {
  const DriverPaymentHistoryEntry({
    required this.title,
    required this.subtitle,
    this.amountLabel,
    this.statusLabel,
  });

  final String title;
  final String subtitle;
  final String? amountLabel;
  final String? statusLabel;
}

/// **Payment History** — past charges transparent.
class DriverPaymentHistoryBody extends StatelessWidget {
  const DriverPaymentHistoryBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.entries,
    required this.loading,
    required this.errorMessage,
    required this.onBack,
    this.onRefresh,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final List<DriverPaymentHistoryEntry> entries;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onBack;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return DriverMoneyFlowScaffold(
      title: DriverStrings.billingHistoryTitle,
      colors: colors,
      typography: typography,
      onBack: onBack,
      body: loading
          ? ListView(
              padding: const EdgeInsets.all(DriverSpacing.screenEdge),
              children: [
                DriverSkeleton(colors: colors, height: 72),
                const SizedBox(height: DriverSpacing.md),
                DriverSkeleton(colors: colors, height: 72),
              ],
            )
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(DriverSpacing.xxl),
                    child: Text(
                      errorMessage!,
                      style: typography.bodyMedium.copyWith(
                        color: colors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : entries.isEmpty
                  ? DriverEmptyState(
                      title: DriverStrings.billingHistoryEmpty,
                      icon: Icons.receipt_long_outlined,
                      colors: colors,
                      typography: typography,
                    )
                  : RefreshIndicator(
                      color: colors.primary,
                      onRefresh: onRefresh ?? () async {},
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          DriverSpacing.screenEdge,
                          DriverSpacing.md,
                          DriverSpacing.screenEdge,
                          DriverSpacing.xxl,
                        ),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: DriverSpacing.md),
                        itemBuilder: (context, index) {
                          final row = entries[index];
                          return _HistoryTile(
                            colors: colors,
                            typography: typography,
                            entry: row,
                            staggerIndex: index.clamp(0, 4),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.colors,
    required this.typography,
    required this.entry,
    required this.staggerIndex,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverPaymentHistoryEntry entry;
  final int staggerIndex;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      padding: const EdgeInsets.all(DriverSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_note_rounded, color: colors.primary, size: 22),
          const SizedBox(width: DriverSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: typography.bodyMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: DriverSpacing.xs),
                Text(
                  entry.subtitle,
                  style: typography.bodySmall.copyWith(
                    color: colors.textMuted,
                  ),
                ),
                if (entry.amountLabel != null || entry.statusLabel != null) ...[
                  const SizedBox(height: DriverSpacing.sm),
                  Wrap(
                    spacing: DriverSpacing.md,
                    runSpacing: DriverSpacing.xs,
                    children: [
                      if (entry.amountLabel != null)
                        Text(
                          entry.amountLabel!,
                          style: typography.labelMedium.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (entry.statusLabel != null)
                        Text(
                          entry.statusLabel!,
                          style: typography.labelSmall.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ).driverFadeSlideIn(staggerIndex: staggerIndex);
  }
}
