import 'golden_bootstrap.dart' show kDriverGoldenTypographyBootstrapped;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'golden_text_theme.dart';
import 'ledger_flow_previews.dart';
import 'visual_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ledger flow — visual baselines (Phase 7 · Trip Ledger)', () {
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

    testWidgets('todays_ledger_light', (tester) async {
      await pumpPreview(
        tester,
        DriverTodaysLedgerPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverTodaysLedgerPreview),
        matchesGoldenFile('goldens/todays_ledger_light.png'),
      );
    });

    testWidgets('ride_history_light', (tester) async {
      await pumpPreview(
        tester,
        DriverRideHistoryPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverRideHistoryPreview),
        matchesGoldenFile('goldens/ride_history_light.png'),
      );
    });

    testWidgets('trip_receipt_light', (tester) async {
      await pumpPreview(
        tester,
        DriverTripReceiptPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverTripReceiptPreview),
        matchesGoldenFile('goldens/trip_receipt_light.png'),
      );
    });
  });
}
