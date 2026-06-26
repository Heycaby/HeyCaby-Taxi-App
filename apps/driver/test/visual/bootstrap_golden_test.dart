import 'golden_bootstrap.dart' show kDriverGoldenTypographyBootstrapped;

import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_ui/src/theme/typography.dart' as typo;

void main() {
  test('golden bootstrap before heycaby_ui barrel', () {
    expect(kDriverGoldenTypographyBootstrapped, isTrue);
    expect(typo.kHeyCabyUseRobotoTypographyForTests, isTrue);
    final font =
        kThemes[kHeyCabyDriverProThemeId]!.typography.displayLarge.fontFamily;
    expect(font, 'Roboto');
  });
}
