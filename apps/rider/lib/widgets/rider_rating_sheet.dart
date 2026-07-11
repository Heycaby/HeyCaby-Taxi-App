import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/rider_rating_summary_provider.dart';

Future<void> showRiderRatingSheet({
  required BuildContext context,
  required RiderRatingSummary summary,
  required HeyCabyColorTokens colors,
  required HeyCabyTypography typography,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: colors.text.withValues(alpha: 0.42),
    builder: (context) => _RiderRatingSheet(
      summary: summary,
      colors: colors,
      typography: typography,
    ),
  );
}

class _RiderRatingSheet extends StatelessWidget {
  const _RiderRatingSheet({
    required this.summary,
    required this.colors,
    required this.typography,
  });

  final RiderRatingSummary summary;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typography;

  String _compactCount(int count) => count > 99 ? '99+' : '$count';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final height = MediaQuery.sizeOf(context).height * 0.82;
    return Container(
      height: height,
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
                    l10n.riderRatingDetailsTitle,
                    style: typography.headingSmall.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: colors.text,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border.withValues(alpha: 0.65)),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsetsDirectional.fromSTEB(
                22,
                24,
                22,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (summary.hasRatings) ...[
                    Semantics(
                      label: l10n.riderRatingAccessibility(
                        summary.averageRating.toStringAsFixed(2),
                        summary.totalRatings,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Icon(Icons.star_rounded,
                              color: colors.warning, size: 42),
                          const SizedBox(width: 8),
                          Text(
                            summary.averageRating.toStringAsFixed(2),
                            style: typography.displayLarge.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w900,
                              height: 0.95,
                              letterSpacing: 0,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                12, 8, 12, 8),
                            decoration: BoxDecoration(
                              color: colors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _compactCount(summary.fiveStarCount),
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
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.riderRatingBasedOn(summary.totalRatings),
                      style: typography.bodyMedium.copyWith(
                        color: colors.textMid,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      l10n.riderRatingBreakdownTitle,
                      style: typography.titleLarge.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (var star = 5; star >= 1; star--)
                      _RatingDistributionRow(
                        star: star,
                        count: summary.distribution[star] ?? 0,
                        total: summary.totalRatings,
                        colors: colors,
                        typography: typography,
                      ),
                  ] else ...[
                    _EmptyRatingState(
                      colors: colors,
                      typography: typography,
                      l10n: l10n,
                    ),
                  ],
                  const SizedBox(height: 28),
                  Text(
                    l10n.riderRatingDriverNotesTitle,
                    style: typography.titleLarge.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.riderRatingDriverNotesBody,
                    style: typography.bodySmall.copyWith(
                      color: colors.textMid,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (summary.comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        l10n.riderRatingNoComments,
                        style: typography.bodyMedium.copyWith(
                          color: colors.textMid,
                        ),
                      ),
                    )
                  else
                    ...summary.comments.map(
                      (comment) => _DriverCommentRow(
                        comment: comment,
                        colors: colors,
                        typography: typography,
                        l10n: l10n,
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
}

class _RatingDistributionRow extends StatelessWidget {
  const _RatingDistributionRow({
    required this.star,
    required this.count,
    required this.total,
    required this.colors,
    required this.typography,
  });

  final int star;
  final int count;
  final int total;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typography;

  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '$star',
              style: typography.labelLarge.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Icon(Icons.star_rounded, color: colors.warning, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 7,
                backgroundColor: colors.border.withValues(alpha: 0.52),
                valueColor: AlwaysStoppedAnimation(colors.accent),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 32,
            child: Text(
              '$count',
              textAlign: TextAlign.end,
              style: typography.labelLarge.copyWith(
                color: colors.textMid,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverCommentRow extends StatelessWidget {
  const _DriverCommentRow({
    required this.comment,
    required this.colors,
    required this.typography,
    required this.l10n,
  });

  final RiderRatingComment comment;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typography;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(0, 14, 0, 14),
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
              Text(
                l10n.riderRatingAnonymousDriver,
                style: typography.labelLarge.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              for (var i = 0; i < comment.rating; i++)
                Icon(Icons.star_rounded, color: colors.warning, size: 15),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '“${comment.comment}”',
            style: typography.bodyMedium.copyWith(
              color: colors.textMid,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRatingState extends StatelessWidget {
  const _EmptyRatingState({
    required this.colors,
    required this.typography,
    required this.l10n,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typography;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(Icons.star_outline_rounded, color: colors.border, size: 54),
          const SizedBox(height: 14),
          Text(
            l10n.riderRatingNoRating,
            style: typography.titleLarge.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.riderRatingNoRatingBody,
            textAlign: TextAlign.center,
            style: typography.bodyMedium.copyWith(
              color: colors.textMid,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
