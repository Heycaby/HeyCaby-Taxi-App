import 'package:flutter/material.dart';

/// Rider app supported language codes (must match [AppLocalizations] + ARB files).
const Set<String> kRiderSupportedLanguageCodes = {'en', 'nl', 'ar'};

const Locale kRiderFallbackLocale = Locale('en');

/// Maps the device / candidate locale to a supported rider [Locale].
Locale resolveRiderSupportedLocale(
  Locale? candidate, {
  Locale fallback = kRiderFallbackLocale,
}) {
  if (candidate == null) return fallback;
  final code = candidate.languageCode.toLowerCase();
  if (kRiderSupportedLanguageCodes.contains(code)) {
    return Locale(code);
  }
  return fallback;
}

/// Current OS locale mapped to a supported rider locale.
Locale resolveRiderDeviceLocale() {
  return resolveRiderSupportedLocale(
    WidgetsBinding.instance.platformDispatcher.locale,
  );
}

/// BCP-47 tag for Supabase RPCs (`en`, `nl`, `ar`, or `en_US` style).
String riderLocaleTag(Locale locale) {
  final code = locale.languageCode.toLowerCase();
  final country = locale.countryCode;
  if (country != null && country.isNotEmpty) {
    return '${code}_${country.toUpperCase()}';
  }
  return code;
}
