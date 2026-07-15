import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_rating_summary_provider.dart';
import '../services/driver_data_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import 'driver_hub_saved_by_riders_section.dart';

Future<void> showDriverRatingSheet({
  required BuildContext context,
  required DriverColors colors,
  required DriverTypography typography,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: colors.text.withValues(alpha: 0.44),
    builder: (_) => _DriverRatingSheet(
      colors: colors,
      typography: typography,
    ),
  );
}

class _DriverRatingSheet extends ConsumerWidget {
  const _DriverRatingSheet({
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  String _compactCount(int count) => count > 99 ? '99+' : '$count';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(driverRatingSummaryProvider);
    final scoreAsync = ref.watch(driverMyRatingProvider);
    final commentsAsync = ref.watch(driverCommentsFilteredProvider);
    final savedByRidersInline = savedByRidersInlineCopy(
      ref.watch(driverFavoriteSummaryProvider).valueOrNull,
    );
    final summary = summaryAsync.valueOrNull;
    final score = scoreAsync.valueOrNull;
    final comments = commentsAsync.valueOrNull ?? const <DriverComment>[];
    final average = score?.publicStars ?? summary?.averageRating ?? 0;
    final total = summary?.totalRatings ?? score?.totalValidRatings ?? 0;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.84,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(22, 16, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DriverStrings.ratingSheetTitle,
                    style: typography.headlineSmall.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: DriverStrings.close,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: colors.text,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border.withValues(alpha: 0.65)),
          Expanded(
            child: summaryAsync.isLoading && scoreAsync.isLoading
                ? Center(
                    child: CircularProgressIndicator(color: colors.primary),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      DriverSpacing.screenEdge,
                      DriverSpacing.xl,
                      DriverSpacing.screenEdge,
                      MediaQuery.paddingOf(context).bottom + DriverSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Icon(Icons.star_rounded,
                                color: colors.warning, size: 42),
                            const SizedBox(width: DriverSpacing.sm),
                            Text(
                              average.toStringAsFixed(2),
                              style: typography.displaySmall.copyWith(
                                color: colors.text,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                                height: 0.95,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: DriverSpacing.md,
                                vertical: DriverSpacing.sm,
                              ),
                              decoration: BoxDecoration(
                                color: colors.warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _compactCount(summary?.fiveStarCount ?? 0),
                                    style: typography.titleMedium.copyWith(
                                      color: colors.text,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.star_rounded,
                                      color: colors.warning, size: 18),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: DriverSpacing.sm),
                        Text(
                          DriverStrings.ratingBasedOn(total),
                          style: typography.bodyMedium.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                        if (savedByRidersInline != null) ...[
                          const SizedBox(height: DriverSpacing.sm),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.favorite_rounded,
                                color: colors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: DriverSpacing.xs),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      savedByRidersInline.countLine,
                                      style: typography.bodyMedium.copyWith(
                                        color: colors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (savedByRidersInline.namesLine !=
                                        null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        savedByRidersInline.namesLine!,
                                        style: typography.bodySmall.copyWith(
                                          color: colors.textMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: DriverSpacing.xxl),
                        Text(
                          DriverStrings.ratingDistributionTitle,
                          style: typography.titleLarge.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: DriverSpacing.md),
                        if (summary != null)
                          for (var star = 5; star >= 1; star--)
                            _DriverStarRow(
                              star: star,
                              count: summary.distribution[star] ?? 0,
                              total: summary.totalRatings,
                              colors: colors,
                              typography: typography,
                            )
                        else
                          Text(
                            DriverStrings.ratingLoadFailed,
                            style: typography.bodyMedium.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        if (score != null) ...[
                          const SizedBox(height: DriverSpacing.xxl),
                          Text(
                            DriverStrings.ratingBreakdownTitle,
                            style: typography.titleLarge.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: DriverSpacing.sm),
                          _QualityRow(
                            label: DriverStrings.ratingPunctuality,
                            value: score.avgPunctuality,
                            colors: colors,
                            typography: typography,
                          ),
                          _QualityRow(
                            label: DriverStrings.ratingCleanliness,
                            value: score.avgCleanliness,
                            colors: colors,
                            typography: typography,
                          ),
                          _QualityRow(
                            label: DriverStrings.ratingCommunication,
                            value: score.avgCommunication,
                            colors: colors,
                            typography: typography,
                          ),
                        ],
                        const SizedBox(height: DriverSpacing.xxl),
                        Text(
                          DriverStrings.recentPassengerComments,
                          style: typography.titleLarge.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: DriverSpacing.sm),
                        if (comments.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              DriverStrings.noPassengerComments,
                              style: typography.bodyMedium.copyWith(
                                color: colors.textMuted,
                              ),
                            ),
                          )
                        else
                          ...comments.map(
                            (comment) => _PassengerCommentRow(
                              comment: comment,
                              colors: colors,
                              typography: typography,
                              onHide: () => _hideComment(ref, comment),
                              onReport: () => _reportComment(ref, comment),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _hideComment(WidgetRef ref, DriverComment comment) async {
    final id = await ref.read(driverIdProvider.future);
    if (id == null || comment.ratingId == null) return;
    final ok = await ref
        .read(driverDataServiceProvider)
        .dismissComment(id, comment.ratingId!);
    if (ok) {
      ref.invalidate(driverHiddenCommentIdsProvider);
      ref.invalidate(driverCommentsFilteredProvider);
    }
  }

  Future<void> _reportComment(WidgetRef ref, DriverComment comment) async {
    final id = await ref.read(driverIdProvider.future);
    if (id == null || comment.ratingId == null) return;
    await ref
        .read(driverDataServiceProvider)
        .reportComment(id, comment.ratingId!);
  }
}

class _DriverStarRow extends StatelessWidget {
  const _DriverStarRow({
    required this.star,
    required this.count,
    required this.total,
    required this.colors,
    required this.typography,
  });

  final int star;
  final int count;
  final int total;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text('$star',
                style: typography.labelLarge
                    .copyWith(color: colors.text, fontWeight: FontWeight.w800)),
          ),
          Icon(Icons.star_rounded, color: colors.warning, size: 16),
          const SizedBox(width: DriverSpacing.sm),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : count / total,
                minHeight: 7,
                backgroundColor: colors.border.withValues(alpha: 0.55),
                valueColor: AlwaysStoppedAnimation(colors.primary),
              ),
            ),
          ),
          const SizedBox(width: DriverSpacing.sm),
          SizedBox(
            width: 30,
            child: Text(
              '$count',
              textAlign: TextAlign.end,
              style: typography.labelLarge.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityRow extends StatelessWidget {
  const _QualityRow({
    required this.label,
    required this.value,
    required this.colors,
    required this.typography,
  });

  final String label;
  final double? value;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DriverSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: typography.bodyMedium.copyWith(color: colors.text)),
          ),
          Text(
            value!.toStringAsFixed(1),
            style: typography.titleSmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PassengerCommentRow extends StatelessWidget {
  const _PassengerCommentRow({
    required this.comment,
    required this.colors,
    required this.typography,
    required this.onHide,
    required this.onReport,
  });

  final DriverComment comment;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onHide;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: DriverSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.border.withValues(alpha: 0.55)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DriverStrings.passengerFeedback,
                  style: typography.labelLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (comment.rating != null)
                Text(
                  '${comment.rating!.toStringAsFixed(0)} ★',
                  style: typography.labelLarge.copyWith(
                    color: colors.warning,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              PopupMenuButton<String>(
                tooltip: DriverStrings.moreActions,
                onSelected: (value) {
                  if (value == 'hide') onHide();
                  if (value == 'report') onReport();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'hide',
                    child: Text(DriverStrings.dismiss),
                  ),
                  PopupMenuItem(
                    value: 'report',
                    child: Text(DriverStrings.report),
                  ),
                ],
              ),
            ],
          ),
          Text(
            '“${comment.riderComment}”',
            style: typography.bodyMedium.copyWith(
              color: colors.textMuted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
