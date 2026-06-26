import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/services/driver_pickup_wait_service.dart';

void main() {
  group('DriverPickupWaitService.elapsedSeconds', () {
    const service = DriverPickupWaitService();

    test('counts seconds since arrival', () {
      final start = DateTime.utc(2026, 5, 19, 10, 0, 0);
      final now = DateTime.utc(2026, 5, 19, 10, 2, 30);
      expect(service.elapsedSeconds(start, now: now), 150);
    });

    test('never returns negative elapsed time', () {
      final start = DateTime.utc(2026, 5, 19, 10, 5, 0);
      final now = DateTime.utc(2026, 5, 19, 10, 4, 0);
      expect(service.elapsedSeconds(start, now: now), 0);
    });
  });

  group('driverPickupWaitFromAuditRow', () {
    test('reads driver_arrived transition timestamp', () {
      final at = driverPickupWaitFromAuditRow({
        'occurred_at': '2026-05-19T10:15:00Z',
        'metadata': {'to_status': 'driver_arrived', 'from_status': 'accepted'},
      });
      expect(at, DateTime.utc(2026, 5, 19, 10, 15));
    });

    test('ignores non-arrival transitions', () {
      expect(
        driverPickupWaitFromAuditRow({
          'occurred_at': '2026-05-19T10:15:00Z',
          'metadata': {'to_status': 'in_progress'},
        }),
        isNull,
      );
    });
  });
}
