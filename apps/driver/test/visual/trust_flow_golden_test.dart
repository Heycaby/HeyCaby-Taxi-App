import 'golden_bootstrap.dart' show kDriverGoldenTypographyBootstrapped;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'golden_text_theme.dart';
import 'trust_flow_previews.dart';
import 'visual_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Trust flow — visual baselines (Phase 9 · Trust & Feedback)', () {
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

    testWidgets('feedback_loop_light', (tester) async {
      await pumpPreview(
        tester,
        DriverFeedbackLoopPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverFeedbackLoopPreview),
        matchesGoldenFile('goldens/feedback_loop_light.png'),
      );
    });

    testWidgets('legal_trust_light', (tester) async {
      await pumpPreview(
        tester,
        DriverLegalTrustPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverLegalTrustPreview),
        matchesGoldenFile('goldens/legal_trust_light.png'),
      );
    });

    testWidgets('privacy_trust_light', (tester) async {
      await pumpPreview(
        tester,
        DriverPrivacyTrustPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverPrivacyTrustPreview),
        matchesGoldenFile('goldens/privacy_trust_light.png'),
      );
    });

    testWidgets('ai_support_chat_light', (tester) async {
      await pumpPreview(
        tester,
        DriverAiSupportChatPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverAiSupportChatPreview),
        matchesGoldenFile('goldens/ai_support_chat_light.png'),
      );
    });
  });
}
