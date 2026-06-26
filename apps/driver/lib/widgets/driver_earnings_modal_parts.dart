import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_earnings_chip.dart';

/// Legacy wrapper — map overlay uses [DriverEarningsChip].
class DriverEarningsPill extends StatelessWidget {
  const DriverEarningsPill({
    super.key,
    required this.todayEarnings,
    required this.zoneName,
    required this.statusKind,
    required this.colors,
    required this.typo,
    required this.onTap,
    this.statusTime,
  });

  final String todayEarnings;
  final String zoneName;
  final DriverStatusKind statusKind;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;
  final DateTime? statusTime;

  @override
  Widget build(BuildContext context) {
    var statusLabel = zoneName;
    if (statusTime != null &&
        (statusKind == DriverStatusKind.online ||
            statusKind == DriverStatusKind.onBreak)) {
      final hm =
          '${statusTime!.hour.toString().padLeft(2, '0')}:${statusTime!.minute.toString().padLeft(2, '0')}';
      statusLabel = statusKind == DriverStatusKind.online
          ? '${DriverStrings.onlineSince} $hm'
          : '${DriverStrings.onBreakSince} $hm';
    }

    return DriverEarningsChip(
      todayEarnings: todayEarnings,
      statusLabel: statusLabel,
      statusKind: statusKind,
      colors: DriverColors.fromTheme(colors),
      typography: DriverTypography.fromTheme(typo),
      onTap: onTap,
    );
  }
}

/// Status color: green (online), amber (on break), grey (offline).
Color statusColor(DriverStatusKind kind, HeyCabyColorTokens colors) {
  switch (kind) {
    case DriverStatusKind.online:
      return colors.success;
    case DriverStatusKind.onBreak:
      return colors.warning;
    case DriverStatusKind.offline:
      return colors.textSoft;
  }
}

enum DriverStatusKind { online, onBreak, offline }

class DriverBreakBanner extends StatelessWidget {
  const DriverBreakBanner({
    super.key,
    required this.colors,
    required this.typo,
    required this.isRed,
    required this.minutesLeft,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final bool isRed;
  final int minutesLeft;

  @override
  Widget build(BuildContext context) {
    final bg = (isRed ? colors.error : colors.warning).withValues(alpha: 0.15);
    final text = isRed
        ? DriverStrings.breakRequired
        : DriverStrings.breakRecommended.replaceFirst('X', '$minutesLeft');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule,
            size: 18,
            color: isRed ? colors.error : colors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: typo.bodySmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
