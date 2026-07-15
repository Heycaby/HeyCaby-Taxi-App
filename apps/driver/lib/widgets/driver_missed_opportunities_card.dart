import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_ride_line_provider.dart';
import '../theme/app_icons.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';

/// Home card: missed ride opportunities (FOMO) — tap for full list.
class DriverMissedOpportunitiesCard extends ConsumerWidget {
  const DriverMissedOpportunitiesCard({
    super.key,
    required this.colors,
    required this.typo,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(driverMissedSummaryProvider);
    final driverColors = DriverColors.fromTheme(colors);
    final driverTypo = DriverTypography.fromTheme(typo);

    return summaryAsync.when(
      data: (summary) {
        if (!summary.hasMissed) return const SizedBox.shrink();
        final total =
            '€${summary.fareTotalToday.toStringAsFixed(2)}';
        return Padding(
          padding: const EdgeInsets.only(top: DriverSpacing.md),
          child: Material(
            color: colors.card,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () {
                HapticService.selectionClick();
                context.push('/driver/missed-opportunities');
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(DriverSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.warning.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.history_toggle_off_rounded,
                        color: colors.warning,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: DriverSpacing.sm + 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DriverStrings.missedOpportunitiesTitle,
                            style: driverTypo.titleSmall.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DriverStrings.missedOpportunitiesSummary(
                              summary.countToday,
                              total,
                            ),
                            style: typo.bodySmall.copyWith(
                              color: colors.textMid,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            DriverStrings.missedOpportunitiesTapHint,
                            style: typo.labelSmall.copyWith(
                              color: colors.textSoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      AppIcons.chevronRight,
                      color: driverColors.primary.withValues(alpha: 0.55),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
