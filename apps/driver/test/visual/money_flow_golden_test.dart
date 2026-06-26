import 'golden_bootstrap.dart' show kDriverGoldenTypographyBootstrapped;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'golden_text_theme.dart';
import 'money_flow_previews.dart';
import 'visual_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Money flow — visual baselines (Phase 4 · Money & Earnings)', () {
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

    testWidgets('earnings_hub_light', (tester) async {
      await pumpPreview(
        tester,
        DriverEarningsHubPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverEarningsHubPreview),
        matchesGoldenFile('goldens/earnings_hub_light.png'),
      );
    });

    testWidgets('subscription_gate_light', (tester) async {
      await pumpPreview(
        tester,
        DriverSubscriptionGatePreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverSubscriptionGatePreview),
        matchesGoldenFile('goldens/subscription_gate_light.png'),
      );
    });

    testWidgets('payment_history_light', (tester) async {
      await pumpPreview(
        tester,
        DriverPaymentHistoryPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverPaymentHistoryPreview),
        matchesGoldenFile('goldens/payment_history_light.png'),
      );
    });
  });
}
