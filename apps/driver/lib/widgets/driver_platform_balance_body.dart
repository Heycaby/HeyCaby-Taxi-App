import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import '../ui/driver_card.dart';
import '../ui/driver_status_badge.dart';
import 'driver_money_flow_common.dart';

class DriverPlatformBalanceSummary {
  const DriverPlatformBalanceSummary({
    required this.outstandingDisplay,
    required this.statusLine,
    required this.statusTone,
    required this.rideRequestsPaused,
    required this.paymentPending,
    required this.canSettle,
    required this.isCurrent,
    this.dueLine,
    this.warningDisplay,
    this.limitDisplay,
    this.directPaymentRidesPaused = false,
  });

  final String outstandingDisplay;
  final String statusLine;
  final DriverStatusTone statusTone;
  final String? dueLine;
  final bool rideRequestsPaused;
  final bool paymentPending;
  final bool canSettle;
  final bool isCurrent;
  final String? warningDisplay;
  final String? limitDisplay;
  final bool directPaymentRidesPaused;
}

class DriverPlatformBalanceBody extends StatelessWidget {
  const DriverPlatformBalanceBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.summary,
    required this.loading,
    required this.errorMessage,
    required this.onBack,
    required this.onViewHistory,
    required this.onSettleBalance,
    this.onRefresh,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverPlatformBalanceSummary? summary;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onBack;
  final VoidCallback onViewHistory;
  final VoidCallback? onSettleBalance;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return DriverMoneyFlowScaffold(
      title: DriverStrings.platformBalanceTitle,
      colors: colors,
      typography: typography,
      onBack: onBack,
      body: loading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
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
              : RefreshIndicator(
                  onRefresh: onRefresh ?? () async {},
                  color: colors.primary,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      DriverSpacing.screenEdge,
                      DriverSpacing.md,
                      DriverSpacing.screenEdge,
                      DriverSpacing.xxl,
                    ),
                    children: [
                      _BalanceCard(
                        colors: colors,
                        typography: typography,
                        summary: summary!,
                      ).driverFadeSlideIn(staggerIndex: 0),
                      const SizedBox(height: DriverSpacing.xl),
                      _InfoCard(
                        colors: colors,
                        typography: typography,
                        summary: summary!,
                      ).driverFadeSlideIn(staggerIndex: 1),
                      const SizedBox(height: DriverSpacing.xl),
                      _ActionsSection(
                        colors: colors,
                        typography: typography,
                        canSettle: summary!.canSettle,
                        onViewHistory: onViewHistory,
                        onSettleBalance: onSettleBalance,
                      ).driverFadeSlideIn(staggerIndex: 2),
                    ],
                  ),
                ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.colors,
    required this.typography,
    required this.summary,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverPlatformBalanceSummary summary;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      padding: const EdgeInsets.all(DriverSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                color: colors.primary,
                size: 24,
              ),
              const SizedBox(width: DriverSpacing.md),
              Expanded(
                child: Text(
                  DriverStrings.platformBalanceTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.labelLarge.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DriverSpacing.xl),
          Text(
            summary.isCurrent
                ? DriverStrings.platformBalanceNoOutstanding
                : DriverStrings.platformBalanceOutstanding,
            style: typography.bodyMedium.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: DriverSpacing.xs),
          Text(
            summary.outstandingDisplay,
            style: typography.displaySmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: DriverSpacing.md),
          if (!summary.isCurrent) ...[
            Text(
              DriverStrings.platformBalanceBankTransferSubtitle,
              style: typography.bodySmall.copyWith(
                color: colors.textSecondary,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: DriverSpacing.md),
          ],
          if (summary.warningDisplay != null ||
              summary.limitDisplay != null) ...[
            const SizedBox(height: DriverSpacing.md),
            Divider(color: colors.border),
            const SizedBox(height: DriverSpacing.sm),
            if (summary.warningDisplay != null)
              _BalanceRuleRow(
                colors: colors,
                typography: typography,
                label: DriverStrings.platformBalanceWarningLevel,
                value: summary.warningDisplay!,
              ),
            if (summary.limitDisplay != null) ...[
              const SizedBox(height: DriverSpacing.xs),
              _BalanceRuleRow(
                colors: colors,
                typography: typography,
                label: DriverStrings.platformBalanceDirectRideLimit,
                value: summary.limitDisplay!,
              ),
            ],
          ],
          DriverStatusBadge(
            label: summary.statusLine,
            colors: colors,
            typography: typography,
            tone: summary.statusTone,
            icon: summary.paymentPending
                ? Icons.hourglass_top_rounded
                : summary.rideRequestsPaused
                    ? Icons.pause_circle_outline_rounded
                    : Icons.verified_outlined,
          ),
          if (summary.dueLine != null) ...[
            const SizedBox(height: DriverSpacing.md),
            Text(
              summary.dueLine!,
              style: typography.bodySmall.copyWith(
                color: colors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.colors,
    required this.typography,
    required this.summary,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverPlatformBalanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final toneColor = summary.paymentPending || summary.rideRequestsPaused
        ? colors.warning
        : colors.primary;
    return DriverCard(
      colors: colors,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: toneColor, size: 22),
          const SizedBox(width: DriverSpacing.md),
          Expanded(
            child: Text(
              summary.paymentPending
                  ? DriverStrings.platformBalancePaymentPendingBody
                  : summary.directPaymentRidesPaused
                      ? DriverStrings.platformBalancePausedExplainer
                      : DriverStrings.platformBalanceExplainer,
              style: typography.bodySmall.copyWith(
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceRuleRow extends StatelessWidget {
  const _BalanceRuleRow(
      {required this.colors,
      required this.typography,
      required this.label,
      required this.value});
  final DriverColors colors;
  final DriverTypography typography;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(label,
                style: typography.bodySmall
                    .copyWith(color: colors.textSecondary))),
        Text(value,
            style: typography.bodySmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()]))
      ]);
}

class _ActionsSection extends StatelessWidget {
  const _ActionsSection({
    required this.colors,
    required this.typography,
    required this.canSettle,
    required this.onViewHistory,
    required this.onSettleBalance,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool canSettle;
  final VoidCallback onViewHistory;
  final VoidCallback? onSettleBalance;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canSettle && onSettleBalance != null) ...[
          DriverButton(
            label: DriverStrings.platformBalanceViewSettlementDetails,
            icon: Icons.account_balance_outlined,
            onPressed: onSettleBalance!,
            size: DriverButtonSize.lg,
            colors: colors,
            typography: typography,
          ),
          const SizedBox(height: DriverSpacing.sm),
        ],
        DriverMoneyOutlineAction(
          label: DriverStrings.platformBalanceViewHistory,
          icon: Icons.history_rounded,
          colors: colors,
          typography: typography,
          onPressed: onViewHistory,
        ),
      ],
    );
  }
}
