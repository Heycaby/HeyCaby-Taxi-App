import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_api/heycaby_api.dart';

void main() {
  test('chat retry keys are URL-safe 128-bit values', () {
    final keys = {
      for (var i = 0; i < 100; i++) HeyCabyRideChatMessages.newIdempotencyKey(),
    };

    expect(keys, hasLength(100));
    for (final key in keys) {
      expect(key, hasLength(32));
      expect(key, matches(RegExp(r'^[0-9a-f]{32}$')));
    }
  });
}
