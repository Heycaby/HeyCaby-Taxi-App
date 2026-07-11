import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_rider/models/taxi_terug_hot_destination.dart';

void main() {
  test('default NL cities include four hot markets', () {
    expect(kTaxiTerugNlHotCities.map((c) => c.city), [
      'Amsterdam',
      'Rotterdam',
      'Utrecht',
      'Den Haag',
    ]);
  });

  test('hot destination converts to booking address', () {
    const dest = TaxiTerugHotDestination(
      city: 'Rotterdam',
      lat: 51.9244,
      lng: 4.4777,
      driverCount: 3,
    );
    expect(dest.toAddressResult().displayName, 'Rotterdam');
    expect(dest.toAddressResult().city, 'Rotterdam');
  });
}
