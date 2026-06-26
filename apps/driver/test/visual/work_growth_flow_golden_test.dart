import 'golden_bootstrap.dart' show kDriverGoldenTypographyBootstrapped;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'golden_text_theme.dart';
import 'visual_harness.dart';
import 'work_growth_flow_previews.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Work & growth — visual baselines (Phase 12)', () {
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

    testWidgets('ride_swap_light', (tester) async {
      await pumpPreview(
        tester,
        DriverRideSwapPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverRideSwapPreview),
        matchesGoldenFile('goldens/ride_swap_light.png'),
      );
    });

    testWidgets('go_live_light', (tester) async {
      await pumpPreview(
        tester,
        DriverGoLivePreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverGoLivePreview),
        matchesGoldenFile('goldens/go_live_light.png'),
      );
    });

    testWidgets('referral_share_light', (tester) async {
      await pumpPreview(
        tester,
        DriverReferralSharePreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverReferralSharePreview),
        matchesGoldenFile('goldens/referral_share_light.png'),
      );
    });

    testWidgets('app_suggestion_light', (tester) async {
      await pumpPreview(
        tester,
        DriverAppSuggestionPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverAppSuggestionPreview),
        matchesGoldenFile('goldens/app_suggestion_light.png'),
      );
    });
  });
}
