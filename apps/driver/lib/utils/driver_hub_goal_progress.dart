import '../l10n/driver_strings.dart';

/// Live goal progress copy from earned vs target (Supabase-backed amounts only).
abstract final class DriverHubGoalProgress {
  static const periods = ['daily', 'weekly', 'biweekly', 'monthly'];

  static double earnedForPeriod({
    required String period,
    required double todayEuros,
    required double weekEuros,
    required double biweeklyEuros,
    required double monthEuros,
  }) {
    return switch (period) {
      'daily' => todayEuros,
      'weekly' => weekEuros,
      'biweekly' => biweeklyEuros,
      'monthly' => monthEuros,
      _ => weekEuros,
    };
  }

  static String periodLabel(String period) => switch (period) {
        'daily' => DriverStrings.hubGoalPeriodDaily,
        'weekly' => DriverStrings.hubGoalPeriodWeekly,
        'biweekly' => DriverStrings.hubGoalPeriodBiweekly,
        'monthly' => DriverStrings.hubGoalPeriodMonthly,
        _ => DriverStrings.hubGoalPeriodWeekly,
      };

  static String periodShortLabel(String period) =>
      DriverHubTileGoalPreview.periodShortLabel(period);

  static DriverHubGoalSnapshot snapshot({
    required double earned,
    required double target,
    required String period,
  }) {
    if (target <= 0) {
      return const DriverHubGoalSnapshot(
        progress: 0,
        achieved: false,
        message: null,
      );
    }
    final progress = (earned / target).clamp(0.0, double.infinity);
    final percentDone = (progress * 100).round().clamp(0, 999);
    final remainingPct =
        ((1 - progress.clamp(0.0, 1.0)) * 100).round().clamp(0, 100);

    if (progress >= 1.0) {
      return DriverHubGoalSnapshot(
        progress: 1,
        achieved: true,
        message: DriverStrings.hubGoalAchieved(periodLabel(period)),
      );
    }
    if (progress >= 0.9) {
      return DriverHubGoalSnapshot(
        progress: progress,
        achieved: false,
        message: DriverStrings.hubGoalAlmostThere(remainingPct),
      );
    }
    if (progress >= 0.7) {
      return DriverHubGoalSnapshot(
        progress: progress,
        achieved: false,
        message: DriverStrings.hubGoalKeepMoving(remainingPct),
      );
    }
    if (progress >= 0.3) {
      return DriverHubGoalSnapshot(
        progress: progress,
        achieved: false,
        message: DriverStrings.hubGoalProgressMilestone(percentDone),
      );
    }
    return DriverHubGoalSnapshot(
      progress: progress,
      achieved: false,
      message: DriverStrings.hubGoalStarted(percentDone),
    );
  }
}

class DriverHubGoalSnapshot {
  const DriverHubGoalSnapshot({
    required this.progress,
    required this.achieved,
    required this.message,
  });

  final double progress;
  final bool achieved;
  final String? message;
}

/// Compact goal preview for Hub Money tile (live Supabase earnings + targets).
class DriverHubTileGoalPreview {
  const DriverHubTileGoalPreview({
    required this.period,
    required this.progress,
    required this.achieved,
    required this.subtitle,
    required this.percentLabel,
  });

  final String period;
  final double progress;
  final bool achieved;
  final String subtitle;
  final String percentLabel;

  static String? resolveActivePeriod(
    Map<String, double> targets,
    String preferredPeriod,
  ) {
    if ((targets[preferredPeriod] ?? 0) > 0) return preferredPeriod;
    for (final period in DriverHubGoalProgress.periods) {
      if ((targets[period] ?? 0) > 0) return period;
    }
    return null;
  }

  static DriverHubTileGoalPreview? fromLiveData({
    required Map<String, double> targets,
    required String preferredPeriod,
    required double todayEuros,
    required double weekEuros,
    required double biweeklyEuros,
    required double monthEuros,
    required String Function(double amount) formatEuros,
  }) {
    final period = resolveActivePeriod(targets, preferredPeriod);
    if (period == null) return null;
    final target = targets[period] ?? 0;
    if (target <= 0) return null;

    final earned = DriverHubGoalProgress.earnedForPeriod(
      period: period,
      todayEuros: todayEuros,
      weekEuros: weekEuros,
      biweeklyEuros: biweeklyEuros,
      monthEuros: monthEuros,
    );
    final snap = DriverHubGoalProgress.snapshot(
      earned: earned,
      target: target,
      period: period,
    );
    final percent = (snap.progress * 100).round().clamp(0, 999);

    return DriverHubTileGoalPreview(
      period: period,
      progress: snap.achieved ? 1 : snap.progress.clamp(0.0, 1.0),
      achieved: snap.achieved,
      subtitle:
          '${formatEuros(earned)} / ${formatEuros(target)} · ${periodShortLabel(period)}',
      percentLabel: snap.achieved ? '100%' : '$percent%',
    );
  }

  static String periodShortLabel(String period) => switch (period) {
        'daily' => DriverStrings.hubGoalPeriodDailyShort,
        'weekly' => DriverStrings.hubGoalPeriodWeeklyShort,
        'biweekly' => DriverStrings.hubGoalPeriodBiweeklyShort,
        'monthly' => DriverStrings.hubGoalPeriodMonthlyShort,
        _ => DriverStrings.hubGoalPeriodWeeklyShort,
      };
}
