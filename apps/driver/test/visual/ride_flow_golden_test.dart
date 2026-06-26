import 'golden_bootstrap.dart' show kDriverGoldenTypographyBootstrapped;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'golden_text_theme.dart';
import 'ride_flow_previews.dart';
import 'visual_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ride flow — visual baselines (Phase 3 · Core Ride Flow)', () {
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

      await tester.pumpWidget(
        DriverVisualHarness(child: preview),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('active_trip_light', (tester) async {
      await pumpPreview(
        tester,
        DriverActiveTripPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverActiveTripPreview),
        matchesGoldenFile('goldens/active_trip_light.png'),
      );
    });

    testWidgets('pickup_arrival_light', (tester) async {
      await pumpPreview(
        tester,
        DriverPickupArrivalPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverPickupArrivalPreview),
        matchesGoldenFile('goldens/pickup_arrival_light.png'),
      );
    });

    testWidgets('navigation_focus_light', (tester) async {
      await pumpPreview(
        tester,
        DriverNavigationFocusPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverNavigationFocusPreview),
        matchesGoldenFile('goldens/navigation_focus_light.png'),
      );
    });

    testWidgets('reward_screen_light', (tester) async {
      await pumpPreview(
        tester,
        DriverRewardPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverRewardPreview),
        matchesGoldenFile('goldens/reward_screen_light.png'),
      );
    });
  });
}
