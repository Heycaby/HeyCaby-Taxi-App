import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/utils/taxi_terug_wizard_contract.dart';

void main() {
  group('TaxiTerugWizardContract', () {
    test('clamps pickup radius to 1–50 km', () {
      expect(TaxiTerugWizardContract.clampPickupRadiusKm(0), 1);
      expect(TaxiTerugWizardContract.clampPickupRadiusKm(75), 50);
      expect(TaxiTerugWizardContract.clampPickupRadiusKm(25), 25);
    });

    test('snaps drop distance to wizard cards up to 30 km', () {
      expect(TaxiTerugWizardContract.snapDropDistanceKm(7), 5);
      expect(TaxiTerugWizardContract.snapDropDistanceKm(22), 20);
      expect(TaxiTerugWizardContract.snapDropDistanceKm(40), 30);
    });

    test('clamps discount and departure hours', () {
      expect(TaxiTerugWizardContract.clampDiscountPct(60), 50);
      expect(TaxiTerugWizardContract.clampDepartureHours(12), 10);
    });
  });
}
