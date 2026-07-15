import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/utils/driver_hub_goal_progress.dart';

void main() {
  group('DriverHubGoalProgress', () {
    test('maps earned amounts by period', () {
      expect(
        DriverHubGoalProgress.earnedForPeriod(
          period: 'biweekly',
          todayEuros: 1,
          weekEuros: 2,
          biweeklyEuros: 3,
          monthEuros: 4,
        ),
        3,
      );
    });

    test('returns milestone messages from live progress', () {
      final snap = DriverHubGoalProgress.snapshot(
        earned: 35,
        target: 100,
        period: 'weekly',
      );
      expect(snap.progress, closeTo(0.35, 0.001));
      expect(snap.achieved, isFalse);
      expect(snap.message, isNotNull);
    });

    test('marks goal achieved at 100%', () {
      final snap = DriverHubGoalProgress.snapshot(
        earned: 120,
        target: 100,
        period: 'monthly',
      );
      expect(snap.achieved, isTrue);
      expect(snap.progress, greaterThanOrEqualTo(1));
    });

    test('periodShortLabel maps all periods', () {
      expect(DriverHubGoalProgress.periodShortLabel('daily'), isNotEmpty);
      expect(DriverHubGoalProgress.periodShortLabel('biweekly'), isNotEmpty);
    });

    test('tile goal preview uses live earnings and targets', () {
      final preview = DriverHubTileGoalPreview.fromLiveData(
        targets: const {'weekly': 100},
        preferredPeriod: 'weekly',
        todayEuros: 10,
        weekEuros: 45,
        biweeklyEuros: 45,
        monthEuros: 45,
        formatEuros: (v) => '€${v.toStringAsFixed(2)}',
      );
      expect(preview, isNotNull);
      expect(preview!.percentLabel, '45%');
      expect(preview.subtitle, contains('€45.00'));
      expect(preview.subtitle, contains('€100.00'));
    });

    test('tile goal preview falls back to any set period', () {
      final preview = DriverHubTileGoalPreview.fromLiveData(
        targets: const {'monthly': 200},
        preferredPeriod: 'weekly',
        todayEuros: 0,
        weekEuros: 0,
        biweeklyEuros: 0,
        monthEuros: 50,
        formatEuros: (v) => '€${v.toStringAsFixed(0)}',
      );
      expect(preview?.period, 'monthly');
      expect(preview?.percentLabel, '25%');
    });
  });
}
