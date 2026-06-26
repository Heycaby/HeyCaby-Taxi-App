import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/utils/driver_immersive_shell.dart';

void main() {
  group('isDriverImmersiveRoute', () {
    test('hides tab bar on ride flow routes', () {
      expect(isDriverImmersiveRoute('/driver/ride/new/abc'), isTrue);
      expect(isDriverImmersiveRoute('/driver/ride/active/abc'), isTrue);
      expect(isDriverImmersiveRoute('/driver/ride/progress/abc'), isTrue);
      expect(isDriverImmersiveRoute('/driver/ride/rate/abc'), isTrue);
    });

    test('shows tab bar on hub routes', () {
      expect(isDriverImmersiveRoute('/driver'), isFalse);
      expect(isDriverImmersiveRoute('/driver/community'), isFalse);
      expect(isDriverImmersiveRoute('/driver/me'), isFalse);
    });
  });
}
