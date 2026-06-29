import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kLocaleKey = 'driver_locale';
const _kLocaleFollowsDeviceKey = 'driver_locale_follows_device';

const supportedLanguageCodes = ['nl', 'en', 'es', 'ar'];
const driverFallbackLocale = Locale('en');

Locale resolveDriverSupportedLocale(Locale? candidate) {
  if (candidate == null) return driverFallbackLocale;
  final code = candidate.languageCode.toLowerCase();
  if (supportedLanguageCodes.contains(code)) return Locale(code);
  return driverFallbackLocale;
}

Locale resolveDriverDeviceLocale() {
  return resolveDriverSupportedLocale(PlatformDispatcher.instance.locale);
}

/// Auto-detects phone language on first launch. Falls back to English.
/// If user manually overrides, that preference is persisted.
class LocaleNotifier extends Notifier<Locale?> {
  final _storage = const FlutterSecureStorage();
  bool _languageFollowsDevice = true;

  bool get languageFollowsDevice => _languageFollowsDevice;

  @override
  Locale? build() => null;

  Future<void> loadSaved() async {
    final followsRaw = await _storage.read(key: _kLocaleFollowsDeviceKey);
    final code = await _storage.read(key: _kLocaleKey);
    if (followsRaw != null) {
      _languageFollowsDevice = followsRaw != 'false';
    } else if (code != null && code.trim().isNotEmpty) {
      // Existing installs: keep explicit language until user picks device.
      _languageFollowsDevice = false;
    } else {
      _languageFollowsDevice = true;
    }

    if (_languageFollowsDevice) {
      state = resolveDriverDeviceLocale();
      return;
    }

    state = resolveDriverSupportedLocale(
      code == null || code.trim().isEmpty ? null : Locale(code.trim()),
    );
  }

  Future<void> setLocale(String languageCode) async {
    if (!supportedLanguageCodes.contains(languageCode)) return;
    await _storage.write(key: _kLocaleKey, value: languageCode);
    await _storage.write(key: _kLocaleFollowsDeviceKey, value: 'false');
    _languageFollowsDevice = false;
    state = Locale(languageCode);
  }

  Future<void> resetToDevice() async {
    await _storage.write(key: _kLocaleFollowsDeviceKey, value: 'true');
    _languageFollowsDevice = true;
    state = resolveDriverDeviceLocale();
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);
