import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/rider_locale_utils.dart';
import 'settings_provider.dart';

/// Rebuild when the OS locale list changes (user changes phone language).
final deviceLocaleSignalProvider = Provider<Locale>((ref) {
  return WidgetsBinding.instance.platformDispatcher.locale;
});

/// Effective app locale: explicit account pick, otherwise phone language.
final riderAppLocaleProvider = Provider<Locale>((ref) {
  ref.watch(deviceLocaleSignalProvider);
  final settings = ref.watch(settingsProvider).valueOrNull;
  if (settings != null && !settings.languageFollowsDevice) {
    return resolveRiderSupportedLocale(Locale(settings.language));
  }
  return resolveRiderDeviceLocale();
});

/// BCP-47-ish tag for backend locale filters (banners, supply copy, etc.).
final riderAppLocaleTagProvider = Provider<String>((ref) {
  return riderLocaleTag(ref.watch(riderAppLocaleProvider));
});
