import 'package:flutter/material.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../l10n/driver_grow_city_strings.dart';
import '../models/driver_community_growth_models.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';

class DriverGrowCityHero extends StatelessWidget {
  const DriverGrowCityHero({
    super.key,
    required this.regionName,
    required this.colors,
    required this.typography,
    required this.strings,
  });

  final String regionName;
  final DriverColors colors;
  final DriverTypography typography;
  final DriverGrowCityStrings strings;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryLight.withValues(alpha: 0.45),
            colors.card,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.public_rounded, color: colors.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.heroTitle(regionName),
                    style: typography.titleMedium.copyWith(
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
              strings.heroBody1,
              style: typography.bodyMedium.copyWith(
                color: colors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DriverCommunityProgressCard extends StatelessWidget {
  const DriverCommunityProgressCard({
    super.key,
    required this.stats,
    required this.colors,
    required this.typography,
    required this.strings,
  });

  final CommunityGrowthStats stats;
  final DriverColors colors;
  final DriverTypography typography;
  final DriverGrowCityStrings strings;

  @override
  Widget build(BuildContext context) {
    final progress = stats.progressFraction.clamp(0.0, 1.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.85)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.progressCount(
                formatCommunityCount(stats.monthlyRiderCount),
                formatCommunityCount(stats.nextMilestone),
              ),
              style: typography.labelLarge.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: colors.border.withValues(alpha: 0.35),
                color: colors.primary,
              ),
            ),
            if (stats.finalGoalReached) ...[
              const SizedBox(height: 8),
              Text(
                strings.finalGoalReached,
                style: typography.bodySmall.copyWith(
                  color: colors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _CompactChip(
                  label:
                      '${formatCommunityCount(stats.driverCount)} ${strings.driversLabel.toLowerCase()}',
                  colors: colors,
                  typography: typography,
                ),
                _CompactChip(
                  label:
                      '${formatCommunityCount(stats.riderCount)} ${strings.ridersLabel.toLowerCase()}',
                  colors: colors,
                  typography: typography,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactChip extends StatelessWidget {
  const _CompactChip({
    required this.label,
    required this.colors,
    required this.typography,
  });

  final String label;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border.withValues(alpha: 0.75)),
      ),
      child: Text(
        label,
        style: typography.labelSmall.copyWith(
          color: colors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class DriverYourImpactCard extends StatelessWidget {
  const DriverYourImpactCard({
    super.key,
    required this.impact,
    required this.loading,
    required this.colors,
    required this.typography,
    required this.strings,
  });

  final DriverInviteImpact impact;
  final bool loading;
  final DriverColors colors;
  final DriverTypography typography;
  final DriverGrowCityStrings strings;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.75)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (loading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colors.primary,
                  ),
                ),
              )
            else
              Row(
                children: [
                  Icon(Icons.favorite_rounded, size: 20, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      strings.impactTitle,
                      style: typography.labelLarge.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    strings.impactCompact(
                      impact.driversInvited,
                      impact.joined,
                    ),
                    style: typography.labelMedium.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
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

class DriverCommunityBadgesRow extends StatelessWidget {
  const DriverCommunityBadgesRow({
    super.key,
    required this.joined,
    required this.colors,
    required this.typography,
    required this.strings,
  });

  final int joined;
  final DriverColors colors;
  final DriverTypography typography;
  final DriverGrowCityStrings strings;

  @override
  Widget build(BuildContext context) {
    final earned = DriverCommunityBadgeTierX.earnedForJoined(joined);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.badgesTitle,
          style: typography.titleSmall.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tier in DriverCommunityBadgeTier.values)
              _BadgeChip(
                emoji: _emojiFor(tier),
                label: _labelFor(tier, strings),
                earned: earned.contains(tier),
                colors: colors,
                typography: typography,
              ),
          ],
        ),
      ],
    );
  }

  static String _emojiFor(DriverCommunityBadgeTier tier) {
    switch (tier) {
      case DriverCommunityBadgeTier.supporter:
        return '🥉';
      case DriverCommunityBadgeTier.builder:
        return '🥈';
      case DriverCommunityBadgeTier.ambassador:
        return '🥇';
      case DriverCommunityBadgeTier.topPromoter:
        return '🚖';
    }
  }

  static String _labelFor(
    DriverCommunityBadgeTier tier,
    DriverGrowCityStrings strings,
  ) {
    switch (tier) {
      case DriverCommunityBadgeTier.supporter:
        return strings.badgeSupporter;
      case DriverCommunityBadgeTier.builder:
        return strings.badgeBuilder;
      case DriverCommunityBadgeTier.ambassador:
        return strings.badgeAmbassador;
      case DriverCommunityBadgeTier.topPromoter:
        return strings.badgeTopPromoter;
    }
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({
    required this.emoji,
    required this.label,
    required this.earned,
    required this.colors,
    required this.typography,
  });

  final String emoji;
  final String label;
  final bool earned;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: earned ? 1 : 0.38,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: earned
              ? colors.primaryLight.withValues(alpha: 0.35)
              : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                earned ? colors.primary.withValues(alpha: 0.5) : colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: typography.labelSmall.copyWith(
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

class DriverGrowCityWhyHelpCard extends StatelessWidget {
  const DriverGrowCityWhyHelpCard({
    super.key,
    required this.colors,
    required this.typography,
    required this.strings,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverGrowCityStrings strings;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.65)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.whyHelpTitle,
              style: typography.titleSmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final bullet in [
              strings.whyHelpBullet1,
              strings.whyHelpBullet2,
              strings.whyHelpBullet3,
              strings.whyHelpBullet4,
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        bullet,
                        style: typography.bodySmall.copyWith(
                          color: colors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
