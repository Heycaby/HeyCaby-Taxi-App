import 'golden_bootstrap.dart' show kDriverGoldenTypographyBootstrapped;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'golden_text_theme.dart';
import 'support_flow_previews.dart';
import 'visual_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Support flow — visual baselines (Phase 6 · Support & Help)', () {
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

    testWidgets('help_hub_light', (tester) async {
      await pumpPreview(
        tester,
        DriverHelpHubPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverHelpHubPreview),
        matchesGoldenFile('goldens/help_hub_light.png'),
      );
    });

    testWidgets('quick_answers_light', (tester) async {
      await pumpPreview(
        tester,
        DriverQuickAnswersPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverQuickAnswersPreview),
        matchesGoldenFile('goldens/quick_answers_light.png'),
      );
    });

    testWidgets('support_inbox_light', (tester) async {
      await pumpPreview(
        tester,
        DriverSupportInboxPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverSupportInboxPreview),
        matchesGoldenFile('goldens/support_inbox_light.png'),
      );
    });

    testWidgets('raise_issue_light', (tester) async {
      await pumpPreview(
        tester,
        DriverRaiseIssuePreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverRaiseIssuePreview),
        matchesGoldenFile('goldens/raise_issue_light.png'),
      );
    });
  });
}
