import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Driver chat uses the canonical retry-safe backend command', () {
    final source =
        File('lib/screens/driver_chat_screen.dart').readAsStringSync();

    expect(source, contains('HeyCabyRideChatMessages.send('));
    expect(source, contains('_recoverCanonicalMessages'));
    expect(source, contains(".order('id', ascending: true)"));
    expect(source, contains('_retryIdempotencyKey'));
    expect(source, isNot(contains("from('messages').insert")));
  });
}
