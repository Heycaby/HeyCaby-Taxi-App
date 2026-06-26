import 'golden_bootstrap.dart' show kDriverGoldenTypographyBootstrapped;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'golden_text_theme.dart';
import 'settings_flow_previews.dart';
import 'visual_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settings flow — visual baselines (Phase 5 · Settings & Profile)', () {
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

    testWidgets('driver_identity_light', (tester) async {
      await pumpPreview(
        tester,
        DriverIdentityPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverIdentityPreview),
        matchesGoldenFile('goldens/driver_identity_light.png'),
      );
    });

    testWidgets('preferences_light', (tester) async {
      await pumpPreview(
        tester,
        DriverPreferencesPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverPreferencesPreview),
        matchesGoldenFile('goldens/preferences_light.png'),
      );
    });

    testWidgets('vehicle_profile_light', (tester) async {
      await pumpPreview(
        tester,
        DriverVehicleProfilePreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverVehicleProfilePreview),
        matchesGoldenFile('goldens/vehicle_profile_light.png'),
      );
    });

    testWidgets('veriff_trust_light', (tester) async {
      await pumpPreview(
        tester,
        DriverVeriffTrustPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverVeriffTrustPreview),
        matchesGoldenFile('goldens/veriff_trust_light.png'),
      );
    });

    testWidgets('compliance_vault_light', (tester) async {
      await pumpPreview(
        tester,
        DriverComplianceVaultPreview(colors: colors, typography: typography),
      );

      await expectLater(
        find.byType(DriverComplianceVaultPreview),
        matchesGoldenFile('goldens/compliance_vault_light.png'),
      );
    });
  });
}
