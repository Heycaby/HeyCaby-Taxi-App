import 'package:flutter/material.dart';

import 'rider_locale_utils.dart';

/// Synced from [riderAppLocaleProvider] for code paths without [BuildContext].
class RiderEffectiveLocaleBridge {
  RiderEffectiveLocaleBridge._();

  static Locale _locale = resolveRiderDeviceLocale();

  static Locale get locale => _locale;

  static String get languageCode => _locale.languageCode.toLowerCase();

  static void update(Locale locale) {
    _locale = resolveRiderSupportedLocale(locale);
  }
}
