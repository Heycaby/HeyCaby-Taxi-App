import 'package:flutter/material.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_rider/models/rider_community_growth_models.dart';
import 'package:heycaby_rider/utils/rider_grow_city_l10n.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

/// One-line pitch above the share CTA.
class RiderGrowCityPitch extends StatelessWidget {
  const RiderGrowCityPitch({
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.accentL.withValues(alpha: 0.4),
            colors.card,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.growCityPitchLine,
              style: typo.titleSmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.growCityPitchBenefit,
              style: typo.bodyMedium.copyWith(
                color: colors.textMid,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slim community milestone — bar + one label + optional driver/rider chips.
class RiderGrowCityMilestoneStrip extends StatelessWidget {
  const RiderGrowCityMilestoneStrip({
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.85)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.growCityProgressHeader(
                localizeGrowCityRegion(l10n, stats.regionName),
                formatCommunityCount(stats.monthlyRiderCount),
                formatCommunityCount(stats.nextMilestone),
              ),
              style: typo.labelLarge.copyWith(
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
                color: colors.accent,
              ),
            ),
            if (stats.finalGoalReached) ...[
              const SizedBox(height: 8),
              Text(
                l10n.growCityFinalGoalReached,
                style: typo.bodySmall.copyWith(
                  color: colors.textMid,
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
                  label: l10n.growCityCompactDrivers(
                    formatCommunityCount(stats.driverCount),
                  ),
                  colors: colors,
                  typo: typo,
                ),
                _CompactChip(
                  label: l10n.growCityCompactRiders(
                    formatCommunityCount(stats.riderCount),
                  ),
                  colors: colors,
                  typo: typo,
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
    required this.typo,
  });

  final String label;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

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
        style: typo.labelSmall.copyWith(
          color: colors.textMid,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Single-line personal impact — shown only when the user has invite activity.
class RiderGrowCityImpactCompact extends StatelessWidget {
  const RiderGrowCityImpactCompact({
    super.key,
    required this.impact,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final RiderInviteImpact impact;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withValues(alpha: 0.75)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        child: Row(
          children: [
            Icon(Icons.favorite_rounded, size: 20, color: colors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.growCityImpactTitle,
                style: typo.labelLarge.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              l10n.growCityImpactCompact(
                impact.peopleInvited,
                impact.joined,
              ),
              style: typo.labelMedium.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
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
    if (earned.isEmpty) return const SizedBox.shrink();

    const all = RiderCommunityBadgeTier.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.growCityBadgesTitle,
          style: typo.labelLarge.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
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
          color:
              earned ? colors.accentL.withValues(alpha: 0.35) : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                earned ? colors.accent.withValues(alpha: 0.5) : colors.border,
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

class RiderGrowCityLearnMoreButton extends StatelessWidget {
  const RiderGrowCityLearnMoreButton({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onPressed,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.info_outline_rounded, size: 20, color: colors.accent),
      label: Text(l10n.growCityLearnMore),
      style: TextButton.styleFrom(
        foregroundColor: colors.accent,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      ),
    );
  }
}

class RiderRideBadgesRow extends StatelessWidget {
  const RiderRideBadgesRow({
    super.key,
    required this.totalRides,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final int totalRides;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final earned = RiderRideBadgeTierX.earnedForRides(totalRides);
    if (earned.isEmpty && totalRides == 0) return const SizedBox.shrink();

    const all = RiderRideBadgeTier.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.growCityRideBadgesTitle,
          style: typo.labelLarge.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
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

  static String _emojiFor(RiderRideBadgeTier tier) {
    switch (tier) {
      case RiderRideBadgeTier.firstRide:
        return '🚀';
      case RiderRideBadgeTier.regular:
        return '🌟';
      case RiderRideBadgeTier.dedicated:
        return '🔥';
      case RiderRideBadgeTier.legend:
        return '👑';
    }
  }

  static String _labelFor(RiderRideBadgeTier tier, AppLocalizations l10n) {
    switch (tier) {
      case RiderRideBadgeTier.firstRide:
        return l10n.growCityRideBadgeFirstRide;
      case RiderRideBadgeTier.regular:
        return l10n.growCityRideBadgeRegular;
      case RiderRideBadgeTier.dedicated:
        return l10n.growCityRideBadgeDedicated;
      case RiderRideBadgeTier.legend:
        return l10n.growCityRideBadgeLegend;
    }
  }
}

class RiderStreakChip extends StatelessWidget {
  const RiderStreakChip({
    super.key,
    required this.weekCount,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final int weekCount;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (weekCount <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.accentL.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            l10n.growCityStreakWeeks(weekCount),
            style: typo.labelMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class RiderBadgeProgressBar extends StatelessWidget {
  const RiderBadgeProgressBar({
    super.key,
    required this.current,
    required this.target,
    required this.label,
    required this.colors,
    required this.typo,
  });

  final int current;
  final int target;
  final String label;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    if (target <= 0 || current >= target) return const SizedBox.shrink();

    final progress = (current / target).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: typo.labelSmall.copyWith(
                    color: colors.textMid,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$current / $target',
                style: typo.labelSmall.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: colors.border.withValues(alpha: 0.3),
              color: colors.accent,
            ),
          ),
        ],
      ),
    );
  }
}
