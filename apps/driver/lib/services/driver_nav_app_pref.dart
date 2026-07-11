import '../l10n/driver_strings.dart';

/// Preferred external navigation app (Program 3D / L1-5).
enum DriverNavApp {
  waze,
  google;

  static const prefKey = 'nav_app_pref';

  static DriverNavApp fromStored(String? value) {
    switch (value) {
      case 'google':
        return DriverNavApp.google;
      case 'waze':
      default:
        return DriverNavApp.waze;
    }
  }

  String get storageValue => name;

  String get label => switch (this) {
        DriverNavApp.waze => DriverStrings.hotspotsWaze,
        DriverNavApp.google => DriverStrings.hotspotsGoogleMaps,
      };
}
