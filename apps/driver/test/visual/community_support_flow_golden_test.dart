import 'golden_bootstrap.dart' show kDriverGoldenTypographyBootstrapped;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'community_support_flow_previews.dart';
import 'golden_text_theme.dart';
import 'visual_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Community & support — visual baselines (Phase 10)', () {
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

    testWidgets('community_hub_light', (tester) async {
      await pumpPreview(
        tester,
        DriverCommunityHubPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverCommunityHubPreview),
        matchesGoldenFile('goldens/community_hub_light.png'),
      );
    });

    testWidgets('community_channel_light', (tester) async {
      await pumpPreview(
        tester,
        DriverCommunityChannelPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverCommunityChannelPreview),
        matchesGoldenFile('goldens/community_channel_light.png'),
      );
    });

    testWidgets('support_conversation_light', (tester) async {
      await pumpPreview(
        tester,
        DriverSupportConversationPreview(
          colors: colors,
          typography: typography,
        ),
      );

      await expectLater(
        find.byType(DriverSupportConversationPreview),
        matchesGoldenFile('goldens/support_conversation_light.png'),
      );
    });

    testWidgets('liability_ack_light', (tester) async {
      await pumpPreview(
        tester,
        DriverLiabilityAckPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverLiabilityAckPreview),
        matchesGoldenFile('goldens/liability_ack_light.png'),
      );
    });
  });
}
