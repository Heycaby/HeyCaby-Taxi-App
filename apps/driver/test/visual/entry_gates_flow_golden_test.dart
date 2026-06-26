import 'golden_bootstrap.dart' show kDriverGoldenTypographyBootstrapped;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'entry_gates_flow_previews.dart';
import 'golden_text_theme.dart';
import 'visual_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Entry & gates — visual baselines (Phase 13)', () {
    late DriverColors colors;
    late DriverTypography typography;
    late HeyCabyColorTokens themeColors;
    late HeyCabyTypography themeTypo;

    setUp(() {
      expect(kDriverGoldenTypographyBootstrapped, isTrue);
      themeColors = getTheme(kDriverGoldenThemeId).colors;
      themeTypo = buildDriverGoldenTypography();
      colors = DriverColors.fromTokens(themeColors);
      typography = DriverTypography.fromHeyCaby(themeTypo);
    });

    Future<void> pumpPreview(WidgetTester tester, Widget preview) async {
      await tester.binding.setSurfaceSize(kDriverGoldenSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(DriverVisualHarness(child: preview));
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('onboarding_gate_light', (tester) async {
      await pumpPreview(
        tester,
        DriverOnboardingGatePreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverOnboardingGatePreview),
        matchesGoldenFile('goldens/onboarding_gate_light.png'),
      );
    });

    testWidgets('knowledge_base_light', (tester) async {
      await pumpPreview(
        tester,
        DriverKnowledgeBasePreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverKnowledgeBasePreview),
        matchesGoldenFile('goldens/knowledge_base_light.png'),
      );
    });

    testWidgets('readiness_gate_light', (tester) async {
      await pumpPreview(
        tester,
        DriverReadinessGatePreview(
          colors: colors,
          typography: typography,
          themeColors: themeColors,
          themeTypo: themeTypo,
        ),
      );

      await expectLater(
        find.byType(DriverReadinessGatePreview),
        matchesGoldenFile('goldens/readiness_gate_light.png'),
      );
    });

    testWidgets('update_gate_light', (tester) async {
      await pumpPreview(
        tester,
        DriverUpdateGatePreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverUpdateGatePreview),
        matchesGoldenFile('goldens/update_gate_light.png'),
      );
    });
  });
}
