import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/services/driver_nav_app_pref.dart';
import 'package:heycaby_driver/services/driver_navigation_launcher.dart';

void main() {
  group('DriverNavApp', () {
    test('defaults to waze for unknown stored value', () {
      expect(DriverNavApp.fromStored(null), DriverNavApp.waze);
      expect(DriverNavApp.fromStored(''), DriverNavApp.waze);
      expect(DriverNavApp.fromStored('waze'), DriverNavApp.waze);
      expect(DriverNavApp.fromStored('google'), DriverNavApp.google);
    });
  });

  group('DriverNavigationLauncher URIs', () {
    test('builds Waze and Google deep links with lat/lng', () {
      expect(
        DriverNavigationLauncher.wazeNativeUri(52.37, 4.89).toString(),
        'waze://?ll=52.37,4.89&navigate=yes',
      );
      expect(
        DriverNavigationLauncher.googleNativeUri(52.37, 4.89).toString(),
        'comgooglemaps://?daddr=52.37,4.89&directionsmode=driving',
      );
      expect(
        DriverNavigationLauncher.googleWebUri(52.37, 4.89).toString(),
        contains('destination=52.37,4.89'),
      );
    });

    test('builds address fallback web links', () {
      final googleFallback = DriverNavigationLauncher.googleWebSearchUri(
        'H.B.S. Laan 8, Oud-Beijerland',
      );
      expect(
        googleFallback.queryParameters['destination'],
        'H.B.S. Laan 8, Oud-Beijerland',
      );
      expect(googleFallback.queryParameters['travelmode'], 'driving');

      expect(
        DriverNavigationLauncher.wazeWebSearchUri(
          'Stationplein 17A, Rotterdam',
        ).toString(),
        contains('q=Stationplein%2017A%2C%20Rotterdam'),
      );
    });
  });
}
