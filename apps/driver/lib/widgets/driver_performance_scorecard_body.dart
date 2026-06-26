import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_card.dart';
import '../ui/driver_skeleton.dart';
import 'driver_performance_flow_common.dart';

class DriverScoreBreakdownItem {
  const DriverScoreBreakdownItem({required this.label, required this.value});

  final String label;
  final double value;
}

class DriverScoreCommentItem {
  const DriverScoreCommentItem({
    required this.comment,
    required this.onReport,
    required this.onDismiss,
  });

  final String comment;
  final VoidCallback onReport;
  final VoidCallback onDismiss;
}

/// **Performance Scorecard** — score motivates improvement, not anxiety.
class DriverPerformanceScorecardBody extends StatelessWidget {
  const DriverPerformanceScorecardBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.loading,
    required this.starsLabel,
    required this.scorePercent,
    required this.ratingsCountLabel,
    required this.trustScore,
    required this.showNewDriverShield,
    required this.showReviewFlag,
    required this.reviewFlagBody,
    required this.badges,
    required this.acceptanceRateLabel,
    required this.breakdown,
    required this.comments,
    required this.onBack,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool loading;
  final String starsLabel;
  final int scorePercent;
  final String? ratingsCountLabel;
  final double? trustScore;
  final bool showNewDriverShield;
  final bool showReviewFlag;
  final String reviewFlagBody;
  final List<String> badges;
  final String? acceptanceRateLabel;
  final List<DriverScoreBreakdownItem> breakdown;
  final List<DriverScoreCommentItem> comments;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return DriverPerformanceFlowScaffold(
      title: DriverStrings.driverRating,
      colors: colors,
      typography: typography,
      onBack: onBack,
      body: loading
          ? Center(child: DriverSkeleton(colors: colors, width: 200, height: 24))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(DriverSpacing.screenEdge),
              child: Column(
                children: [
                  Text(
                    starsLabel,
                    style: typography.displaySmall.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ).driverFadeSlideIn(staggerIndex: 0),
                  if (ratingsCountLabel != null) ...[
                    const SizedBox(height: DriverSpacing.sm),
                    Text(
                      ratingsCountLabel!,
                      style: typography.bodySmall.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: DriverSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: scorePercent / 100,
                      minHeight: 8,
                      backgroundColor: colors.border,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(colors.primary),
                    ),
                  ).driverFadeSlideIn(staggerIndex: 1),
                  if (trustScore != null) ...[
                    const SizedBox(height: DriverSpacing.xl),
                    _TrustScoreCard(
                      trustScore: trustScore!,
                      colors: colors,
                      typography: typography,
                    ).driverFadeSlideIn(staggerIndex: 2),
                  ],
                  if (showNewDriverShield) ...[
                    const SizedBox(height: DriverSpacing.md),
                    DriverPerformanceInfoBanner(
                      icon: Icons.shield_outlined,
                      title: DriverStrings.newDriverShieldActive,
                      body: DriverStrings.newDriverShieldBody,
                      colors: colors,
                      typography: typography,
                      accentColor: colors.success,
                    ),
                  ],
                  if (showReviewFlag) ...[
                    const SizedBox(height: DriverSpacing.md),
                    DriverPerformanceInfoBanner(
                      icon: Icons.flag_outlined,
                      title: DriverStrings.reviewFlagTitle,
                      body: reviewFlagBody,
                      colors: colors,
                      typography: typography,
                      accentColor: colors.warning,
                    ),
                  ],
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: DriverSpacing.xl),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        DriverStrings.ratingBadges,
                        style: typography.titleSmall.copyWith(color: colors.text),
                      ),
                    ),
                    const SizedBox(height: DriverSpacing.sm),
                    Wrap(
                      spacing: DriverSpacing.sm,
                      runSpacing: DriverSpacing.sm,
                      children: badges
                          .map(
                            (b) => DriverPerformanceBadgeChip(
                              label: b,
                              colors: colors,
                              typography: typography,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (acceptanceRateLabel != null) ...[
                    const SizedBox(height: DriverSpacing.xl),
                    Text(
                      acceptanceRateLabel!,
                      style: typography.bodyMedium.copyWith(color: colors.text),
                    ),
                  ],
                  if (breakdown.isNotEmpty) ...[
                    const SizedBox(height: DriverSpacing.xxl),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        DriverStrings.ratingBreakdownTitle,
                        style: typography.titleSmall.copyWith(color: colors.text),
                      ),
                    ),
                    const SizedBox(height: DriverSpacing.md),
                    ...breakdown.map(
                      (item) => DriverPerformanceSubScoreRow(
                        label: item.label,
                        value: item.value,
                        colors: colors,
                        typography: typography,
                      ),
                    ),
                  ],
                  const SizedBox(height: DriverSpacing.xxl),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      DriverStrings.whatReducedMyScore,
                      style: typography.titleSmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: DriverSpacing.sm),
                  Text(
                    DriverStrings.scoreFactorsDesc,
                    style: typography.bodyMedium.copyWith(color: colors.text),
                  ),
                  if (comments.isNotEmpty) ...[
                    const SizedBox(height: DriverSpacing.xl),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Recent passenger comments',
                        style: typography.titleSmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: DriverSpacing.md),
                    ...comments.map(
                      (c) => DriverPerformanceCommentCard(
                        comment: c.comment,
                        colors: colors,
                        typography: typography,
                        onReport: c.onReport,
                        onDismiss: c.onDismiss,
                        reportLabel: DriverStrings.report,
                        dismissLabel: DriverStrings.dismiss,
                      ),
                    ),
                  ],
                  SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
                ],
              ),
            ),
    );
  }
}

class _TrustScoreCard extends StatelessWidget {
  const _TrustScoreCard({
    required this.trustScore,
    required this.colors,
    required this.typography,
  });

  final double trustScore;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    final t = trustScore.clamp(0.0, 100.0);
    return DriverCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DriverStrings.trustScoreLabel,
            style: typography.titleSmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DriverStrings.trustScoreHint,
            style: typography.bodySmall.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: DriverSpacing.md),
          Text(
            '${t.round()}/100',
            style: typography.titleLarge.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DriverSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: t / 100,
              minHeight: 8,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
