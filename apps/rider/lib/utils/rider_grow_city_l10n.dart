import 'package:heycaby_rider/l10n/app_localizations.dart';

/// Localizes backend region names for the Grow Your City UI.
String localizeGrowCityRegion(AppLocalizations l10n, String regionName) {
  final normalized = regionName.trim().toLowerCase();
  switch (normalized) {
    case 'netherlands':
    case 'nederland':
    case 'the netherlands':
      return l10n.growCityRegionNetherlands;
    default:
      return regionName;
  }
}
