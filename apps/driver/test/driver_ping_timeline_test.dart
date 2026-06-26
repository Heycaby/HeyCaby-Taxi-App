import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_driver/models/driver_ping_timeline.dart';

void main() {
  test('groupPingTimelineRows merges sent delivered opened', () {
    final rows = [
      {
        'event': 'driver.ping_on_my_way',
        'occurred_at': '2026-06-19T10:00:00Z',
        'metadata': {'automatic': true, 'delivery_state': 'sent'},
      },
      {
        'event': 'driver.ping_on_my_way.delivered',
        'occurred_at': '2026-06-19T10:00:02Z',
        'metadata': {'delivery_state': 'delivered'},
      },
      {
        'event': 'driver.ping_outside',
        'occurred_at': '2026-06-19T10:05:00Z',
        'metadata': {'delivery_state': 'sent'},
      },
    ];

    final items = groupPingTimelineRows(rows);
    expect(items.length, 2);
    expect(items[0].type, DriverPingType.outside);
    expect(items[1].type, DriverPingType.onMyWay);
    expect(items[1].automatic, isTrue);
    expect(items[1].deliveredAt, isNotNull);
    expect(items[0].deliveredAt, isNull);
  });
}
