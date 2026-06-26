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

/// Billing summary passed from [DriverBillingScreen] — logic stays in screen.
class DriverSubscriptionSummary {
  const DriverSubscriptionSummary({
    required this.isFounding,
    this.foundingNumber,
    required this.weeklyFeeDisplay,
    required this.weeklyFeeUnknown,
    required this.statusLine,
    required this.statusTone,
    this.nextPaymentLabel,
    this.starterBody,
    required this.showSubscriptionControls,
    required this.subscriptionPaused,
    required this.paymentRequired,
    required this.showOptionalCheckout,
    required this.showAppleRestore,
    required this.showPaymentMethods,
  });

  final bool isFounding;
  final int? foundingNumber;
  final String weeklyFeeDisplay;
  final bool weeklyFeeUnknown;
  final String statusLine;
  final DriverStatusTone statusTone;
  final String? nextPaymentLabel;
  final String? starterBody;
  final bool showSubscriptionControls;
  final bool subscriptionPaused;
  final bool paymentRequired;
  final bool showOptionalCheckout;
  final bool showAppleRestore;
  final bool showPaymentMethods;
}

/// **Subscription Gate** — platform fee clear; pay and continue.
class DriverSubscriptionGateBody extends StatelessWidget {
  const DriverSubscriptionGateBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.summary,
    required this.loading,
    required this.errorMessage,
    required this.onBack,
    required this.onViewHistory,
    required this.onPayNow,
    this.onOptionalPay,
    this.onPaymentMethods,
    this.onRestoreApple,
    required this.onPauseSubscription,
    required this.onResumeSubscription,
    required this.onCancelSubscription,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverSubscriptionSummary? summary;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onBack;
  final VoidCallback onViewHistory;
  final VoidCallback onPayNow;
  final VoidCallback? onOptionalPay;
  final VoidCallback? onPaymentMethods;
  final VoidCallback? onRestoreApple;
  final VoidCallback onPauseSubscription;
  final VoidCallback onResumeSubscription;
  final VoidCallback onCancelSubscription;

  @override
  Widget build(BuildContext context) {
    return DriverMoneyFlowScaffold(
      title: DriverStrings.billingTitle,
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
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    DriverSpacing.screenEdge,
                    DriverSpacing.md,
                    DriverSpacing.screenEdge,
                    DriverSpacing.xxl,
                  ),
                  children: [
                    _PlanCard(
                      colors: colors,
                      typography: typography,
                      summary: summary!,
                    ).driverFadeSlideIn(staggerIndex: 0),
                    if (summary!.starterBody != null) ...[
                      const SizedBox(height: DriverSpacing.xl),
                      _StarterCard(
                        colors: colors,
                        typography: typography,
                        body: summary!.starterBody!,
                      ).driverFadeSlideIn(staggerIndex: 1),
                    ],
                    if (summary!.showSubscriptionControls) ...[
                      const SizedBox(height: DriverSpacing.xl),
                      _SubscriptionControlsCard(
                        colors: colors,
                        typography: typography,
                        paused: summary!.subscriptionPaused,
                        onPause: onPauseSubscription,
                        onResume: onResumeSubscription,
                        onCancel: onCancelSubscription,
                      ).driverFadeSlideIn(staggerIndex: 2),
                    ],
                    const SizedBox(height: DriverSpacing.xl),
                    _ActionsSection(
                      colors: colors,
                      typography: typography,
                      summary: summary!,
                      onViewHistory: onViewHistory,
                      onPayNow: onPayNow,
                      onOptionalPay: onOptionalPay,
                      onPaymentMethods: onPaymentMethods,
                      onRestoreApple: onRestoreApple,
                    ).driverFadeSlideIn(staggerIndex: 3),
                  ],
                ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.colors,
    required this.typography,
    required this.summary,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverSubscriptionSummary summary;

  @override
  Widget build(BuildContext context) {
    final memberLabel = summary.isFounding
        ? (summary.foundingNumber != null
            ? '${DriverStrings.billingFoundingMember} #${summary.foundingNumber}'
            : DriverStrings.billingFoundingMember)
        : DriverStrings.billingRegularMember;

    return DriverCard(
      colors: colors,
      padding: const EdgeInsets.all(DriverSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: colors.primary, size: 24),
              const SizedBox(width: DriverSpacing.md),
              Text(
                DriverStrings.billingCurrentPlan,
                style: typography.labelLarge.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: DriverSpacing.lg),
          DriverStatusBadge(
            label: memberLabel,
            colors: colors,
            typography: typography,
            tone: summary.isFounding
                ? DriverStatusTone.success
                : DriverStatusTone.neutral,
            icon: summary.isFounding
                ? Icons.workspace_premium_rounded
                : Icons.person_outline_rounded,
          ),
          const SizedBox(height: DriverSpacing.xl),
          Text(
            summary.weeklyFeeDisplay,
            style: typography.displaySmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: DriverSpacing.xs),
          Text(
            DriverStrings.billingWeeklyFee,
            style: typography.bodyMedium.copyWith(color: colors.textSecondary),
          ),
          if (summary.weeklyFeeUnknown) ...[
            const SizedBox(height: DriverSpacing.sm),
            Text(
              DriverStrings.billingWeeklyFeeUnknown,
              style: typography.bodySmall.copyWith(color: colors.textMuted),
            ),
          ],
          const SizedBox(height: DriverSpacing.lg),
          DriverStatusBadge(
            label: summary.statusLine,
            colors: colors,
            typography: typography,
            tone: summary.statusTone,
            icon: Icons.verified_outlined,
          ),
          if (summary.nextPaymentLabel != null) ...[
            const SizedBox(height: DriverSpacing.md),
            Text(
              summary.nextPaymentLabel!,
              style: typography.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _StarterCard extends StatelessWidget {
  const _StarterCard({
    required this.colors,
    required this.typography,
    required this.body,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String body;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: colors.primary, size: 20),
              const SizedBox(width: DriverSpacing.sm),
              Text(
                DriverStrings.billingStatusFromServer,
                style: typography.labelMedium.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: DriverSpacing.sm),
          Text(
            body,
            style: typography.bodySmall.copyWith(
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionControlsCard extends StatelessWidget {
  const _SubscriptionControlsCard({
    required this.colors,
    required this.typography,
    required this.paused,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool paused;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            DriverStrings.billingSubscriptionTitle,
            style: typography.titleSmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DriverSpacing.lg),
          if (!paused)
            DriverButton(
              label: DriverStrings.billingSubscriptionPause,
              onPressed: onPause,
              variant: DriverButtonVariant.outline,
              colors: colors,
              typography: typography,
            ),
          if (paused)
            DriverButton(
              label: DriverStrings.billingSubscriptionResume,
              onPressed: onResume,
              colors: colors,
              typography: typography,
            ),
          const SizedBox(height: DriverSpacing.sm),
          DriverButton(
            label: DriverStrings.billingSubscriptionCancel,
            onPressed: onCancel,
            variant: DriverButtonVariant.destructive,
            colors: colors,
            typography: typography,
          ),
        ],
      ),
    );
  }
}

class _ActionsSection extends StatelessWidget {
  const _ActionsSection({
    required this.colors,
    required this.typography,
    required this.summary,
    required this.onViewHistory,
    required this.onPayNow,
    this.onOptionalPay,
    this.onPaymentMethods,
    this.onRestoreApple,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverSubscriptionSummary summary;
  final VoidCallback onViewHistory;
  final VoidCallback onPayNow;
  final VoidCallback? onOptionalPay;
  final VoidCallback? onPaymentMethods;
  final VoidCallback? onRestoreApple;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DriverButton(
          label: DriverStrings.billingViewHistory,
          icon: Icons.history_rounded,
          onPressed: onViewHistory,
          size: DriverButtonSize.lg,
          colors: colors,
          typography: typography,
        ),
        if (onRestoreApple != null) ...[
          const SizedBox(height: DriverSpacing.sm),
          DriverMoneyOutlineAction(
            label: DriverStrings.billingRestoreApplePurchases,
            icon: Icons.restore_rounded,
            colors: colors,
            typography: typography,
            onPressed: onRestoreApple!,
          ),
        ],
        if (onPaymentMethods != null) ...[
          const SizedBox(height: DriverSpacing.sm),
          DriverMoneyOutlineAction(
            label: DriverStrings.billingPaymentMethods,
            icon: Icons.credit_card_rounded,
            colors: colors,
            typography: typography,
            onPressed: onPaymentMethods!,
          ),
        ],
        if (summary.showOptionalCheckout && onOptionalPay != null) ...[
          const SizedBox(height: DriverSpacing.sm),
          DriverMoneyOutlineAction(
            label: DriverStrings.billingPayNow,
            icon: Icons.payment_rounded,
            colors: colors,
            typography: typography,
            onPressed: onOptionalPay!,
          ),
        ],
        if (summary.paymentRequired) ...[
          const SizedBox(height: DriverSpacing.sm),
          DriverButton(
            label: DriverStrings.billingPayNow,
            icon: Icons.payment_rounded,
            onPressed: onPayNow,
            size: DriverButtonSize.lg,
            variant: DriverButtonVariant.destructive,
            colors: colors,
            typography: typography,
          ),
        ],
      ],
    );
  }
}
