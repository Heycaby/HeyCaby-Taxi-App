import 'golden_bootstrap.dart' show kDriverGoldenTypographyBootstrapped;

import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/screens/login_screen.dart';
import 'package:heycaby_ui/src/theme/typography.dart' as typo;

import 'visual_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Login — visual baseline (Phase 2 · M1 Trust Screen)', () {
    testWidgets('login_email_light', (tester) async {
      expect(kDriverGoldenTypographyBootstrapped, isTrue);
      expect(typo.kHeyCabyUseRobotoTypographyForTests, isTrue);

      await tester.binding.setSurfaceSize(kDriverGoldenSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const DriverVisualHarness(child: LoginScreen()),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile('goldens/login_email_light.png'),
      );
    });
  });
}
