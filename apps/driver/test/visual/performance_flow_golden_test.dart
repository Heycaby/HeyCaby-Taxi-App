import 'golden_bootstrap.dart' show kDriverGoldenTypographyBootstrapped;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'golden_text_theme.dart';
import 'performance_flow_previews.dart';
import 'visual_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Performance flow — visual baselines (Phase 8 · Demand & Performance)', () {
    late DriverColors colors;
    late DriverTypography typography;

    setUp(() {
      expect(kDriverGoldenTypographyBootstrapped, isTrue);
      final tokens = getTheme(kDriverGoldenThemeId).colors;
      colors = DriverColors.fromTokens(tokens);
      typography = DriverTypography.fromHeyCaby(buildDriverGoldenTypography());
    });

    Future<void> pumpPreview(WidgetTester tester, Widget preview) async {
      await tester.binding.setSurfaceSize(kDriverGoldenSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(DriverVisualHarness(child: preview));
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('performance_scorecard_light', (tester) async {
      await pumpPreview(
        tester,
        DriverPerformanceScorecardPreview(
          colors: colors,
          typography: typography,
        ),
      );

      await expectLater(
        find.byType(DriverPerformanceScorecardPreview),
        matchesGoldenFile('goldens/performance_scorecard_light.png'),
      );
    });

    testWidgets('rate_control_light', (tester) async {
      await pumpPreview(
        tester,
        DriverRateControlPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverRateControlPreview),
        matchesGoldenFile('goldens/rate_control_light.png'),
      );
    });

    testWidgets('demand_radar_light', (tester) async {
      await pumpPreview(
        tester,
        DriverDemandRadarPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverDemandRadarPreview),
        matchesGoldenFile('goldens/demand_radar_light.png'),
      );
    });
  });
}
