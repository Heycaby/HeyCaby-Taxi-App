import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider chat and pings use one backend command authority', () {
    final provider =
        File('lib/providers/chat_provider.dart').readAsStringSync();
    final activeRide =
        File('lib/screens/active_ride_screen.dart').readAsStringSync();
    final unread =
        File('lib/providers/rider_ride_unread_messages_provider.dart')
            .readAsStringSync();

    expect(provider, contains('HeyCabyRideChatMessages.send('));
    expect(provider, contains('_recoverCanonicalMessages'));
    expect(provider, contains(".order('id', ascending: true)"));
    expect(provider, isNot(contains("from('messages').insert")));
    expect(unread, contains('ref.watch(chatProvider)'));
    expect(unread, isNot(contains(".channel('rider-unread-messages:")));
    expect(activeRide, contains("messageType: 'ping'"));
    expect(activeRide, contains('HeyCabyRideChatMessages.send('));
    expect(activeRide, isNot(contains("from('messages').insert")));
  });
}
