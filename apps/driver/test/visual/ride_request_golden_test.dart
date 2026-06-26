import 'golden_bootstrap.dart' show kDriverGoldenTypographyBootstrapped;

import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'golden_text_theme.dart';
import 'ride_request_preview.dart';
import 'visual_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ride request — visual baseline (Phase 3 · Opportunity Screen)', () {
    testWidgets('ride_request_light', (tester) async {
      expect(kDriverGoldenTypographyBootstrapped, isTrue);

      final tokens = getTheme(kDriverGoldenThemeId).colors;
      final colors = DriverColors.fromTokens(tokens);
      final typography =
          DriverTypography.fromHeyCaby(buildDriverGoldenTypography());

      await tester.binding.setSurfaceSize(kDriverGoldenSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        DriverVisualHarness(
          child: DriverOpportunityPreview(
            colors: colors,
            typography: typography,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await expectLater(
        find.byType(DriverOpportunityPreview),
        matchesGoldenFile('goldens/ride_request_light.png'),
      );
    });
  });
}
