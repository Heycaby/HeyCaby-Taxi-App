import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../theme/driver_spacing.dart';

/// "Saved by Riders" section for Driver Hub.
/// Shows total count, this-week delta, and recent additions (first name only).
class DriverHubSavedByRidersSection extends ConsumerWidget {
  const DriverHubSavedByRidersSection({
    super.key,
    required this.colors,
    required this.typo,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(driverFavoriteSummaryProvider);
    final summary = summaryAsync.valueOrNull;

    if (summary == null || summary.totalSavedByRiders == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  color: colors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DriverStrings.savedByRidersTitle,
                      style: typo.titleMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DriverStrings.savedByRidersSubtitle,
                      style: typo.bodySmall.copyWith(
                        color: colors.textSoft,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              _StatPill(
                label: DriverStrings.savedByRidersTotal(
                    summary.totalSavedByRiders),
                colors: colors,
                typo: typo,
                isPrimary: true,
              ),
              if (summary.addedThisWeek > 0) ...[
                const SizedBox(width: 8),
                _StatPill(
                  label:
                      DriverStrings.savedByRidersThisWeek(summary.addedThisWeek),
                  colors: colors,
                  typo: typo,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Microcopy
          Text(
            DriverStrings.savedByRidersMicrocopy,
            style: typo.bodySmall.copyWith(
              color: colors.textMid,
              fontStyle: FontStyle.italic,
            ),
          ),

          // Recent list
          if (summary.recent.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              DriverStrings.savedByRidersRecent,
              style: typo.labelMedium.copyWith(
                color: colors.textSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...summary.recent.map((r) => _RecentRow(
                  name: r.riderFirstName,
                  rating: r.rating,
                  addedAt: r.addedAt,
                  colors: colors,
                  typo: typo,
                )),
          ],
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final bool isPrimary;

  const _StatPill({
    required this.label,
    required this.colors,
    required this.typo,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isPrimary
            ? colors.accent.withValues(alpha: 0.10)
            : colors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPrimary
              ? colors.accent.withValues(alpha: 0.25)
              : colors.success.withValues(alpha: 0.20),
        ),
      ),
      child: Text(
        label,
        style: typo.bodySmall.copyWith(
          color: isPrimary ? colors.accent : colors.success,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  final String name;
  final int? rating;
  final DateTime addedAt;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _RecentRow({
    required this.name,
    required this.rating,
    required this.addedAt,
    required this.colors,
    required this.typo,
  });

  String _whenLabel() {
    final now = DateTime.now();
    final diff = now.difference(addedAt);
    if (diff.inHours < 24) return DriverStrings.savedByRidersToday;
    if (diff.inDays == 1) return DriverStrings.savedByRidersYesterday;
    return '${diff.inDays} ${DriverStrings.savedByRidersDaysAgo}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_rounded,
              size: 16,
              color: colors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              DriverStrings.savedByRiderEntry(name, _whenLabel()),
              style: typo.bodyMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (rating != null)
            Row(
              children: [
                Icon(Icons.star_rounded, size: 14, color: colors.warning),
                const SizedBox(width: 2),
                Text(
                  '$rating',
                  style: typo.bodySmall.copyWith(
                    color: colors.textMid,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Compact "Saved by Riders" insight card for Driver Home sheet.
/// Only shows if the driver has at least 1 saved-by-rider entry.
class DriverHomeSavedByRidersCard extends ConsumerWidget {
  const DriverHomeSavedByRidersCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final summaryAsync = ref.watch(driverFavoriteSummaryProvider);
    final summary = summaryAsync.valueOrNull;

    if (summary == null || summary.totalSavedByRiders == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: DriverSpacing.lg),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.favorite_rounded,
              color: colors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DriverStrings.savedByRidersTitle,
                  style: typo.titleSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  summary.addedThisWeek > 0
                      ? '${DriverStrings.savedByRidersTotal(summary.totalSavedByRiders)} · ${DriverStrings.savedByRidersThisWeek(summary.addedThisWeek)}'
                      : DriverStrings.savedByRidersTotal(
                          summary.totalSavedByRiders),
                  style: typo.bodySmall.copyWith(
                    color: colors.textMid,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
