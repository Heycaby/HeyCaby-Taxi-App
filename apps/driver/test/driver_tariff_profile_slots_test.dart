import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/services/driver_data_service.dart';
import 'package:heycaby_driver/utils/driver_tariff_profile_slots.dart';

void main() {
  group('driver_tariff_profile_slots', () {
    test('slotForProfileName maps weekend', () {
      expect(
        slotForProfileName('Weekend'),
        DriverTariffProfileSlot.weekend,
      );
      expect(
        slotForProfileName('Weekendtarief'),
        DriverTariffProfileSlot.weekend,
      );
    });

    test('sortTariffProfiles orders standard before weekend before night', () {
      final profiles = [
        const DriverRateProfile(
          id: 'night',
          driverId: 'd',
          profileName: 'Late Night',
          sortOrder: 30,
        ),
        const DriverRateProfile(
          id: 'weekend',
          driverId: 'd',
          profileName: 'Weekend',
          sortOrder: 25,
        ),
        const DriverRateProfile(
          id: 'std',
          driverId: 'd',
          profileName: 'Standaard',
          sortOrder: 0,
          isActive: true,
        ),
      ];

      final sorted = sortTariffProfiles(profiles);
      expect(sorted.map((p) => p.id).toList(), ['std', 'weekend', 'night']);
    });

    test('tariffPresetsIncomplete requires weekend', () {
      final withoutWeekend = [
        const DriverRateProfile(id: '1', driverId: 'd', profileName: 'Morning'),
        const DriverRateProfile(id: '2', driverId: 'd', profileName: 'Evening'),
        const DriverRateProfile(id: '3', driverId: 'd', profileName: 'Late Night'),
      ];
      expect(tariffPresetsIncomplete(withoutWeekend), isTrue);

      final complete = [
        ...withoutWeekend,
        const DriverRateProfile(id: '4', driverId: 'd', profileName: 'Weekend'),
      ];
      expect(tariffPresetsIncomplete(complete), isFalse);
    });
  });
}
