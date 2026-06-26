import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_performance_scorecard_body.dart';

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

  bool _hasAnyBadge(DriverMyRating? m) {
    if (m == null) return false;
    return m.badgeConsistency || m.badgeTopDriver || m.badgeVeteran;
  }

  List<String> _badges(DriverMyRating? my) {
    if (my == null) return const [];
    return [
      if (my.badgeConsistency) 'Consistency',
      if (my.badgeTopDriver) 'Top driver',
      if (my.badgeVeteran) 'Veteran',
    ];
  }

  List<DriverScoreBreakdownItem> _breakdown(DriverMyRating? my) {
    if (my == null) return const [];
    final items = <DriverScoreBreakdownItem>[];
    void add(String label, double? value) {
      if (value != null) {
        items.add(DriverScoreBreakdownItem(label: label, value: value));
      }
    }

    add(DriverStrings.ratingPunctuality, my.avgPunctuality);
    add(DriverStrings.ratingCleanliness, my.avgCleanliness);
    add(DriverStrings.ratingAttitude, my.avgAttitude);
    add(DriverStrings.ratingDrivingSafety, my.avgDrivingSafety);
    add(DriverStrings.ratingCommunication, my.avgCommunication);
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final statsAsync = ref.watch(driverShiftStatsProvider);
    final myRatingAsync = ref.watch(driverMyRatingProvider);
    final commentsAsync = ref.watch(driverCommentsFilteredProvider);

    final loading = statsAsync.isLoading || myRatingAsync.isLoading;

    final stats = statsAsync.valueOrNull;
    final my = myRatingAsync.valueOrNull;
    final publicStars = my?.publicStars ?? stats?.rating ?? 0.0;
    final scorePercent = (publicStars * 20).round().clamp(0, 100);
    final acceptanceRate = stats?.acceptanceRate;
    final comments = commentsAsync.valueOrNull ?? [];

    return DriverPerformanceScorecardBody(
      colors: colors,
      typography: typography,
      loading: loading,
      starsLabel: '${publicStars.toStringAsFixed(1)} ★',
      scorePercent: scorePercent,
      ratingsCountLabel: my?.totalValidRatings != null
          ? '${my!.totalValidRatings} ${DriverStrings.ratingsInScore}'
          : null,
      trustScore: my?.trustScore,
      showNewDriverShield: my?.inProtectedWindow == true,
      showReviewFlag: my?.flagReviewNeeded == true,
      reviewFlagBody: my?.flagReviewReason?.trim().isNotEmpty == true
          ? my!.flagReviewReason!.trim()
          : DriverStrings.reviewFlagBody,
      badges: _hasAnyBadge(my) ? _badges(my) : const [],
      acceptanceRateLabel: acceptanceRate != null
          ? '${DriverStrings.acceptanceRate}: ${(acceptanceRate * 100).round()}%'
          : null,
      breakdown: _breakdown(my),
      comments: comments
          .where((c) => c.riderComment != null && c.riderComment!.isNotEmpty)
          .map(
            (c) => DriverScoreCommentItem(
              comment: c.riderComment!,
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
                            : DriverStrings.couldNotReportComment,
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
            ),
          )
          .toList(),
      onBack: () => context.pop(),
    );
  }
}
