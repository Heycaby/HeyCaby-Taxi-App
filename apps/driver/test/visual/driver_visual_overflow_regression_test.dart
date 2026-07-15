import 'golden_bootstrap.dart' show kDriverGoldenTypographyBootstrapped;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'golden_text_theme.dart';
import 'money_flow_previews.dart';
import 'performance_flow_previews.dart';
import 'visual_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Driver visual overflow regressions', () {
    late DriverColors colors;
    late DriverTypography typography;

    setUp(() {
      expect(kDriverGoldenTypographyBootstrapped, isTrue);
      final tokens = getTheme(kDriverGoldenThemeId).colors;
      colors = DriverColors.fromTokens(tokens);
      typography = DriverTypography.fromHeyCaby(buildDriverGoldenTypography());
    });

    Future<void> pumpCompactA11yPreview(
      WidgetTester tester,
      Widget preview,
    ) async {
      const compactPhone = Size(320, 568);

      await tester.binding.setSurfaceSize(compactPhone);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        DriverVisualHarness(
          surfaceSize: compactPhone,
          textScaler: const TextScaler.linear(1.3),
          child: preview,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
    }

    testWidgets('Platform Balance fits compact phones and larger text', (
      tester,
    ) async {
      await pumpCompactA11yPreview(
        tester,
        DriverPlatformBalancePreview(colors: colors, typography: typography),
      );
    });

    testWidgets('Rate Control fits compact phones and larger text', (
      tester,
    ) async {
      await pumpCompactA11yPreview(
        tester,
        DriverRateControlPreview(colors: colors, typography: typography),
      );
    });
  });
}
