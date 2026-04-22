import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';

class DriverScoreScreen extends ConsumerStatefulWidget {
  const DriverScoreScreen({super.key});

  @override
  ConsumerState<DriverScoreScreen> createState() => _DriverScoreScreenState();
}

class _DriverScoreScreenState extends ConsumerState<DriverScoreScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(driverMyRatingProvider);
      ref.invalidate(driverShiftStatsProvider);
      ref.invalidate(driverCommentsFilteredProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final statsAsync = ref.watch(driverShiftStatsProvider);
    final myRatingAsync = ref.watch(driverMyRatingProvider);
    final commentsAsync = ref.watch(driverCommentsFilteredProvider);

    final stats = statsAsync.valueOrNull;
    final my = myRatingAsync.valueOrNull;

    final publicStars = my?.publicStars ?? stats?.rating ?? 0.0;
    final scorePercent = (publicStars * 20).round().clamp(0, 100);
    final acceptanceRate = stats?.acceptanceRate;

    final hasBreakdown = my != null &&
        [
          my.avgPunctuality,
          my.avgCleanliness,
          my.avgAttitude,
          my.avgDrivingSafety,
          my.avgCommunication,
        ].any((v) => v != null);

    final comments = commentsAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.text),
          onPressed: () => context.pop(),
        ),
        title: Text(
          DriverStrings.driverRating,
          style: typo.headingLarge.copyWith(color: colors.text),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              '${publicStars.toStringAsFixed(1)} ★',
              style: typo.displayLarge.copyWith(
                color: colors.text,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (my?.totalValidRatings != null) ...[
              const SizedBox(height: 6),
              Text(
                '${my!.totalValidRatings} ${DriverStrings.ratingsInScore}',
                style: typo.bodySmall.copyWith(color: colors.textSoft),
              ),
            ],
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: scorePercent / 100,
                minHeight: 8,
                backgroundColor: colors.border,
                valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
              ),
            ),
            if (my?.trustScore != null) ...[
              const SizedBox(height: 20),
              _TrustScoreCard(
                trustScore: my!.trustScore!,
                colors: colors,
                typo: typo,
              ),
            ],
            if (my?.inProtectedWindow == true) ...[
              const SizedBox(height: 12),
              _InfoBanner(
                icon: Icons.shield_outlined,
                title: DriverStrings.newDriverShieldActive,
                body: DriverStrings.newDriverShieldBody,
                colors: colors,
                typo: typo,
                accent: colors.success,
              ),
            ],
            if (my?.flagReviewNeeded == true) ...[
              const SizedBox(height: 12),
              _InfoBanner(
                icon: Icons.flag_outlined,
                title: DriverStrings.reviewFlagTitle,
                body: my?.flagReviewReason?.trim().isNotEmpty == true
                    ? my!.flagReviewReason!.trim()
                    : DriverStrings.reviewFlagBody,
                colors: colors,
                typo: typo,
                accent: colors.warning,
              ),
            ],
            if (_driverHasAnyBadge(my)) ...[
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  DriverStrings.ratingBadges,
                  style: typo.titleMedium.copyWith(color: colors.text),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (my!.badgeConsistency)
                    _BadgeChip(label: 'Consistency', colors: colors, typo: typo),
                  if (my.badgeTopDriver)
                    _BadgeChip(label: 'Top driver', colors: colors, typo: typo),
                  if (my.badgeVeteran)
                    _BadgeChip(label: 'Veteran', colors: colors, typo: typo),
                ],
              ),
            ],
            if (acceptanceRate != null) ...[
              const SizedBox(height: 24),
              Text(
                '${DriverStrings.acceptanceRate}: ${(acceptanceRate * 100).round()}%',
                style: typo.bodyMedium.copyWith(color: colors.text),
              ),
            ],
            if (hasBreakdown) ...[
              const SizedBox(height: 28),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  DriverStrings.ratingBreakdownTitle,
                  style: typo.titleMedium.copyWith(color: colors.text),
                ),
              ),
              const SizedBox(height: 12),
              _SubBar(
                label: DriverStrings.ratingPunctuality,
                value: my.avgPunctuality,
                colors: colors,
                typo: typo,
              ),
              _SubBar(
                label: DriverStrings.ratingCleanliness,
                value: my.avgCleanliness,
                colors: colors,
                typo: typo,
              ),
              _SubBar(
                label: DriverStrings.ratingAttitude,
                value: my.avgAttitude,
                colors: colors,
                typo: typo,
              ),
              _SubBar(
                label: DriverStrings.ratingDrivingSafety,
                value: my.avgDrivingSafety,
                colors: colors,
                typo: typo,
              ),
              _SubBar(
                label: DriverStrings.ratingCommunication,
                value: my.avgCommunication,
                colors: colors,
                typo: typo,
              ),
            ],
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                DriverStrings.whatReducedMyScore,
                style: typo.titleMedium.copyWith(color: colors.textSoft),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DriverStrings.scoreFactorsDesc,
              style: typo.bodyMedium.copyWith(color: colors.text),
            ),
            if (comments.isNotEmpty) ...[
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recent passenger comments',
                  style: typo.titleMedium.copyWith(color: colors.textSoft),
                ),
              ),
              const SizedBox(height: 12),
              ...comments
                  .where((c) => c.riderComment != null && c.riderComment!.isNotEmpty)
                  .map((c) => _CommentCard(
                        comment: c.riderComment!,
                        colors: colors,
                        typo: typo,
                        onReport: () async {
                          final id = await ref.read(driverIdProvider.future);
                          final rid = c.ratingId;
                          if (id == null || rid == null) return;
                          final ok = await ref
                              .read(driverDataServiceProvider)
                              .reportComment(id, rid);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Comment reported'
                                      : 'Could not report comment',
                                ),
                              ),
                            );
                          }
                        },
                        onDismiss: () async {
                          final id = await ref.read(driverIdProvider.future);
                          final rid = c.ratingId;
                          if (id == null || rid == null) return;
                          final ok = await ref
                              .read(driverDataServiceProvider)
                              .dismissComment(id, rid);
                          if (ok && context.mounted) {
                            ref.invalidate(driverHiddenCommentIdsProvider);
                            ref.invalidate(driverCommentsFilteredProvider);
                          }
                        },
                      )),
            ],
          ],
        ),
      ),
    );
  }
}

bool _driverHasAnyBadge(DriverMyRating? m) {
  if (m == null) return false;
  return m.badgeConsistency || m.badgeTopDriver || m.badgeVeteran;
}

class _TrustScoreCard extends StatelessWidget {
  final double trustScore;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _TrustScoreCard({
    required this.trustScore,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    final t = trustScore.clamp(0.0, 100.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DriverStrings.trustScoreLabel,
            style: typo.titleMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DriverStrings.trustScoreHint,
            style: typo.bodySmall.copyWith(color: colors.textSoft),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${t.round()}/100',
                style: typo.headingMedium.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: t / 100,
              minHeight: 8,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final Color accent;

  const _InfoBanner({
    required this.icon,
    required this.title,
    required this.body,
    required this.colors,
    required this.typo,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: typo.titleMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: typo.bodySmall.copyWith(color: colors.textMid, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String label;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _BadgeChip({
    required this.label,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.accentL,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: typo.labelSmall.copyWith(
          color: colors.accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// One row for migration 040 sub-averages (1–5 scale), shown as progress vs 5.
class _SubBar extends StatelessWidget {
  final String label;
  final double? value;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _SubBar({
    required this.label,
    required this.value,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox.shrink();
    final v = value!.clamp(0.0, 5.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: typo.bodyMedium.copyWith(color: colors.text),
                ),
              ),
              Text(
                v.toStringAsFixed(1),
                style: typo.labelLarge.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (v / 5.0).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final String comment;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onReport;
  final VoidCallback onDismiss;

  const _CommentCard({
    required this.comment,
    required this.colors,
    required this.typo,
    required this.onReport,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote, color: colors.textSoft, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              comment,
              style: typo.bodyMedium.copyWith(color: colors.text),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colors.textSoft, size: 20),
            padding: EdgeInsets.zero,
            onSelected: (v) {
              if (v == 'report') onReport();
              if (v == 'dismiss') onDismiss();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'report', child: Text('Report')),
              const PopupMenuItem(value: 'dismiss', child: Text('Dismiss')),
            ],
          ),
        ],
      ),
    );
  }
}
