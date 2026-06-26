import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/services/driver_offline_action_queue.dart';

void main() {
  group('DriverOfflineActionQueue', () {
    test('flush runs enqueued actions in order', () async {
      final queue = DriverOfflineActionQueue.instance;
      queue.clear();
      final log = <int>[];
      queue.enqueue(() async => log.add(1));
      queue.enqueue(() async => log.add(2));
      expect(queue.pendingCount, 2);
      await queue.flush();
      expect(log, [1, 2]);
      expect(queue.pendingCount, 0);
    });

    test('clear drops pending actions', () {
      final queue = DriverOfflineActionQueue.instance;
      queue.clear();
      queue.enqueue(() async {});
      queue.clear();
      expect(queue.pendingCount, 0);
    });
  });
}
