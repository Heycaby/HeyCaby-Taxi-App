import 'golden_bootstrap.dart' show kDriverGoldenTypographyBootstrapped;

import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_ui/src/theme/typography.dart' as typo;

import 'component_gallery.dart';
import 'golden_text_theme.dart';
import 'visual_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Component gallery — visual baseline (Phase 1.9)', () {
    testWidgets('components_light', (tester) async {
      expect(kDriverGoldenTypographyBootstrapped, isTrue);
      expect(typo.kHeyCabyUseRobotoTypographyForTests, isTrue);
      expect(
        kThemes[kHeyCabyDriverProThemeId]!.typography.displayLarge.fontFamily,
        'Roboto',
      );

      final tokens = getTheme(kDriverGoldenThemeId).colors;
      final colors = DriverColors.fromTokens(tokens);
      final typography =
          DriverTypography.fromHeyCaby(buildDriverGoldenTypography());

      await tester.binding.setSurfaceSize(kDriverGoldenSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        DriverVisualHarness(
          child: DriverComponentGallery(
            colors: colors,
            typography: typography,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DriverComponentGallery),
        matchesGoldenFile('goldens/components_light.png'),
      );
    });
  });
}
