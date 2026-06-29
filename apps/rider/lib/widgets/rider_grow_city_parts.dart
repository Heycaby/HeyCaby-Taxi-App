import 'package:flutter/material.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_rider/models/rider_community_growth_models.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

class RiderGrowCityHero extends StatelessWidget {
  const RiderGrowCityHero({
    super.key,
    required this.regionName,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final String regionName;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.accentL.withValues(alpha: 0.45),
            colors.card,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.public_rounded, color: colors.accent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.growCityHeroTitle(regionName),
                    style: typo.titleMedium.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.growCityHeroBody1,
              style: typo.bodyMedium.copyWith(
                color: colors.textMid,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.growCityHeroBody2,
              style: typo.bodyMedium.copyWith(
                color: colors.textMid,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.growCityHeroMission,
              style: typo.bodySmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RiderCommunityProgressCard extends StatelessWidget {
  const RiderCommunityProgressCard({
    super.key,
    required this.stats,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final CommunityGrowthStats stats;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final progress = stats.progressFraction.clamp(0.0, 1.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.growCityCommunityTitle(stats.regionName),
              style: typo.titleSmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            _StatRow(
              emoji: '🚖',
              label: l10n.growCityDriversLabel,
              value:
                  '${formatCommunityCount(stats.driverCount)} / ${formatCommunityCount(stats.driverCap)}',
              colors: colors,
              typo: typo,
            ),
            const SizedBox(height: 8),
            _StatRow(
              emoji: '🚶',
              label: l10n.growCityRidersLabel,
              value: formatCommunityCount(stats.riderCount),
              colors: colors,
              typo: typo,
            ),
            const SizedBox(height: 8),
            _StatRow(
              emoji: '📅',
              label: l10n.growCityMonthlyRidersLabel,
              value: formatCommunityCount(stats.monthlyRiderCount),
              colors: colors,
              typo: typo,
            ),
            const SizedBox(height: 8),
            _StatRow(
              emoji: '🛞',
              label: l10n.growCityMonthlyDriversLabel,
              value: formatCommunityCount(stats.monthlyDriverCount),
              colors: colors,
              typo: typo,
            ),
            const SizedBox(height: 8),
            _StatRow(
              emoji: '🎯',
              label: l10n.growCityMilestoneLabel,
              value: formatCommunityCount(stats.nextMilestone),
              colors: colors,
              typo: typo,
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: colors.border.withValues(alpha: 0.35),
                color: colors.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.growCityProgressCount(
                formatCommunityCount(stats.monthlyRiderCount),
                formatCommunityCount(stats.nextMilestone),
              ),
              style: typo.labelMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (stats.finalGoalReached) ...[
              const SizedBox(height: 6),
              Text(
                l10n.growCityFinalGoalReached,
                style: typo.bodySmall.copyWith(
                  color: colors.textMid,
                  height: 1.35,
                ),
              ),
            ] else if (stats.remainingToMilestone > 0) ...[
              const SizedBox(height: 6),
              Text(
                l10n.growCityMilestoneHint(
                  formatCommunityCount(stats.remainingToMilestone),
                  formatCommunityCount(stats.nextMilestone),
                ),
                style: typo.bodySmall.copyWith(
                  color: colors.textMid,
                  height: 1.35,
                ),
              ),
            ],
            if (stats.achievedMilestones.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: stats.achievedMilestones
                    .map(
                      (m) => Chip(
                        label: Text(formatCommunityCount(m)),
                        visualDensity: VisualDensity.compact,
                        backgroundColor:
                            colors.accentL.withValues(alpha: 0.35),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.emoji,
    required this.label,
    required this.value,
    required this.colors,
    required this.typo,
  });

  final String emoji;
  final String label;
  final String value;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: typo.bodyMedium.copyWith(color: colors.textMid),
          ),
        ),
        Text(
          value,
          style: typo.titleSmall.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class RiderYourImpactCard extends StatelessWidget {
  const RiderYourImpactCard({
    super.key,
    required this.impact,
    required this.loading,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final RiderInviteImpact impact;
  final bool loading;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.75)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.growCityImpactTitle,
              style: typo.titleSmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (loading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colors.accent,
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _ImpactStat(
                      label: l10n.growCityPeopleInvited,
                      value: '${impact.peopleInvited}',
                      colors: colors,
                      typo: typo,
                    ),
                  ),
                  Expanded(
                    child: _ImpactStat(
                      label: l10n.growCityJoined,
                      value: '${impact.joined}',
                      colors: colors,
                      typo: typo,
                    ),
                  ),
                  Expanded(
                    child: _ImpactStat(
                      label: l10n.growCityCompletedRides,
                      value: '${impact.completedRides}',
                      colors: colors,
                      typo: typo,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ImpactStat extends StatelessWidget {
  const _ImpactStat({
    required this.label,
    required this.value,
    required this.colors,
    required this.typo,
  });

  final String label;
  final String value;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: typo.headingSmall.copyWith(
            color: colors.accent,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: typo.labelSmall.copyWith(
            color: colors.textMid,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class RiderCommunityBadgesRow extends StatelessWidget {
  const RiderCommunityBadgesRow({
    super.key,
    required this.joined,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final int joined;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final earned = RiderCommunityBadgeTierX.earnedForJoined(joined);
    final all = RiderCommunityBadgeTier.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.growCityBadgesTitle,
          style: typo.titleSmall.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tier in all)
              _BadgeChip(
                emoji: _emojiFor(tier),
                label: _labelFor(tier, l10n),
                earned: earned.contains(tier),
                colors: colors,
                typo: typo,
              ),
          ],
        ),
      ],
    );
  }

  static String _emojiFor(RiderCommunityBadgeTier tier) {
    switch (tier) {
      case RiderCommunityBadgeTier.supporter:
        return '🥉';
      case RiderCommunityBadgeTier.builder:
        return '🥈';
      case RiderCommunityBadgeTier.ambassador:
        return '🥇';
      case RiderCommunityBadgeTier.topPromoter:
        return '🚖';
    }
  }

  static String _labelFor(
    RiderCommunityBadgeTier tier,
    AppLocalizations l10n,
  ) {
    switch (tier) {
      case RiderCommunityBadgeTier.supporter:
        return l10n.growCityBadgeSupporter;
      case RiderCommunityBadgeTier.builder:
        return l10n.growCityBadgeBuilder;
      case RiderCommunityBadgeTier.ambassador:
        return l10n.growCityBadgeAmbassador;
      case RiderCommunityBadgeTier.topPromoter:
        return l10n.growCityBadgeTopPromoter;
    }
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({
    required this.emoji,
    required this.label,
    required this.earned,
    required this.colors,
    required this.typo,
  });

  final String emoji;
  final String label;
  final bool earned;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: earned ? 1 : 0.38,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: earned
              ? colors.accentL.withValues(alpha: 0.35)
              : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: earned ? colors.accent.withValues(alpha: 0.5) : colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: typo.labelSmall.copyWith(
                color: colors.text,
                fontWeight: earned ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RiderGrowCityWhyHelpCard extends StatelessWidget {
  const RiderGrowCityWhyHelpCard({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.65)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.growCityWhyHelpTitle,
              style: typo.titleSmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final bullet in [
              l10n.growCityWhyHelpBullet1,
              l10n.growCityWhyHelpBullet2,
              l10n.growCityWhyHelpBullet3,
              l10n.growCityWhyHelpBullet4,
            ])
              _WhyRow(text: bullet, colors: colors, typo: typo),
          ],
        ),
      ),
    );
  }
}

class _WhyRow extends StatelessWidget {
  const _WhyRow({
    required this.text,
    required this.colors,
    required this.typo,
  });

  final String text;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 3),
            child: Icon(Icons.check_rounded, size: 18, color: colors.accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: typo.bodySmall.copyWith(
                color: colors.textMid,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
