import 'golden_bootstrap.dart' show kDriverGoldenTypographyBootstrapped;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'community_overlay_flow_previews.dart';
import 'golden_text_theme.dart';
import 'visual_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Community overlays — visual baselines (Phase 15)', () {
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

    testWidgets('community_notifications_light', (tester) async {
      await pumpPreview(
        tester,
        DriverCommunityNotificationsPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverCommunityNotificationsPreview),
        matchesGoldenFile('goldens/community_notifications_light.png'),
      );
    });

    testWidgets('community_search_light', (tester) async {
      await pumpPreview(
        tester,
        DriverCommunitySearchPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverCommunitySearchPreview),
        matchesGoldenFile('goldens/community_search_light.png'),
      );
    });

    testWidgets('community_disclaimer_light', (tester) async {
      await pumpPreview(
        tester,
        DriverCommunityDisclaimerPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverCommunityDisclaimerPreview),
        matchesGoldenFile('goldens/community_disclaimer_light.png'),
      );
    });

    testWidgets('community_create_post_light', (tester) async {
      await pumpPreview(
        tester,
        DriverCommunityCreatePostPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverCommunityCreatePostPreview),
        matchesGoldenFile('goldens/community_create_post_light.png'),
      );
    });

    testWidgets('staging_surface_light', (tester) async {
      await pumpPreview(
        tester,
        DriverStagingSurfacePreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverStagingSurfacePreview),
        matchesGoldenFile('goldens/staging_surface_light.png'),
      );
    });
  });
}
