import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';

String _formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '${h}:${m.toString().padLeft(2, '0')}';
}

/// Panel when tapping online status. Shift summary, break, end shift.
/// When [fromTop] is true, panel slides down from top with bottom rounded corners.
class DriverOnlinePanel extends StatelessWidget {
  const DriverOnlinePanel({
    super.key,
    required this.isOnBreak,
    required this.colors,
    required this.typo,
    required this.scrollController,
    required this.onTakeBreak,
    required this.onEndShift,
    required this.onResume,
    this.onlineMinutes = 0,
    this.ridesToday = 0,
    this.earnedToday = '€0.00',
    this.breakNotice,
    this.breakNoticeColor,
    this.fromTop = false,
  });

  final bool isOnBreak;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final ScrollController scrollController;
  final bool fromTop;
  final VoidCallback onTakeBreak;
  final VoidCallback onEndShift;
  final VoidCallback onResume;
  final int onlineMinutes;
  final int ridesToday;
  final String earnedToday;
  final String? breakNotice;
  final Color? breakNoticeColor;

  @override
  Widget build(BuildContext context) {
    final borderRadius = fromTop
        ? const BorderRadius.vertical(bottom: Radius.circular(20))
        : const BorderRadius.vertical(top: Radius.circular(20));
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: borderRadius,
      ),
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.only(
          top: fromTop ? 24 : 16,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        children: [
          if (!fromTop)
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          if (!fromTop) const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: DriverStrings.online,
                  value: _formatMinutes(onlineMinutes),
                  colors: colors,
                  typo: typo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: DriverStrings.rides,
                  value: '$ridesToday',
                  colors: colors,
                  typo: typo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: DriverStrings.earnings,
                  value: earnedToday,
                  colors: colors,
                  typo: typo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (isOnBreak)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onResume,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                child: Text(DriverStrings.goOnline),
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onTakeBreak,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: colors.border),
                ),
                child: Text(DriverStrings.takeABreak),
              ),
            ),
            if (breakNotice != null) ...[
              const SizedBox(height: 16),
              Text(
                breakNotice!,
                style: typo.bodySmall.copyWith(
                  color: breakNoticeColor ?? colors.textSoft,
                ),
              ),
            ],
            const SizedBox(height: 24),
            TextButton(
              onPressed: onEndShift,
              child: Text(
                DriverStrings.endShift,
                style: typo.bodyMedium.copyWith(color: colors.textMid),
              ),
            ),
          ],
          if (fromTop) ...[
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: typo.labelSmall.copyWith(color: colors.textSoft),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: typo.headingLarge.copyWith(
              color: colors.text,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
