import 'golden_bootstrap.dart' show kDriverGoldenTypographyBootstrapped;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'active_hub_flow_previews.dart';
import 'golden_text_theme.dart';
import 'visual_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Active hub — visual baselines (Phase 14)', () {
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

    testWidgets('brand_moment_light', (tester) async {
      await pumpPreview(
        tester,
        DriverBrandMomentPreview(typography: typography),
      );

      await expectLater(
        find.byType(DriverBrandMomentPreview),
        matchesGoldenFile('goldens/brand_moment_light.png'),
      );
    });

    testWidgets('shift_command_light', (tester) async {
      await pumpPreview(
        tester,
        DriverShiftCommandPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverShiftCommandPreview),
        matchesGoldenFile('goldens/shift_command_light.png'),
      );
    });

    testWidgets('rider_conversation_light', (tester) async {
      await pumpPreview(
        tester,
        DriverRiderConversationPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverRiderConversationPreview),
        matchesGoldenFile('goldens/rider_conversation_light.png'),
      );
    });

    testWidgets('me_community_light', (tester) async {
      await pumpPreview(
        tester,
        DriverMeCommunityPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverMeCommunityPreview),
        matchesGoldenFile('goldens/me_community_light.png'),
      );
    });
  });
}
