import 'golden_bootstrap.dart' show kDriverGoldenTypographyBootstrapped;

import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'golden_text_theme.dart';
import 'home_dashboard_preview.dart';
import 'visual_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home — visual baseline (Phase 2 · M2 Money Dashboard)', () {
    testWidgets('home_light', (tester) async {
      expect(kDriverGoldenTypographyBootstrapped, isTrue);

      final tokens = getTheme(kDriverGoldenThemeId).colors;
      final colors = DriverColors.fromTokens(tokens);
      final typography =
          DriverTypography.fromHeyCaby(buildDriverGoldenTypography());

      await tester.binding.setSurfaceSize(kDriverGoldenSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        DriverVisualHarness(
          child: DriverMoneyDashboardPreview(
            colors: colors,
            typography: typography,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DriverMoneyDashboardPreview),
        matchesGoldenFile('goldens/home_light.png'),
      );
    });
  });
}
