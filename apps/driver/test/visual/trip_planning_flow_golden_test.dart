import 'golden_bootstrap.dart' show kDriverGoldenTypographyBootstrapped;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'golden_text_theme.dart';
import 'trip_planning_flow_previews.dart';
import 'visual_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Trip planning — visual baselines (Phase 11)', () {
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

    testWidgets('manual_ride_entry_light', (tester) async {
      await pumpPreview(
        tester,
        DriverManualRideEntryPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverManualRideEntryPreview),
        matchesGoldenFile('goldens/manual_ride_entry_light.png'),
      );
    });

    testWidgets('return_trips_light', (tester) async {
      await pumpPreview(
        tester,
        DriverReturnTripsPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverReturnTripsPreview),
        matchesGoldenFile('goldens/return_trips_light.png'),
      );
    });

    testWidgets('scheduled_rides_light', (tester) async {
      await pumpPreview(
        tester,
        DriverScheduledRidesPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverScheduledRidesPreview),
        matchesGoldenFile('goldens/scheduled_rides_light.png'),
      );
    });
  });
}
