import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kLocaleKey = 'driver_locale';

const supportedLanguageCodes = ['en', 'nl', 'de', 'fr', 'es', 'ar', 'tr'];

/// Auto-detects phone language on first launch. Falls back to 'nl'.
/// If user manually overrides, that preference is persisted.
class LocaleNotifier extends Notifier<Locale?> {
  final _storage = const FlutterSecureStorage();

  @override
  Locale? build() => null;

  Future<void> loadSaved() async {
    final code = await _storage.read(key: _kLocaleKey);
    if (code != null && code.isNotEmpty) {
      state = Locale(code);
      return;
    }
    final deviceLocale = PlatformDispatcher.instance.locale;
    final langCode = deviceLocale.languageCode;
    if (supportedLanguageCodes.contains(langCode)) {
      state = Locale(langCode);
    } else {
      state = const Locale('nl', 'NL');
    }
  }

  Future<void> setLocale(String languageCode) async {
    if (!supportedLanguageCodes.contains(languageCode)) return;
    await _storage.write(key: _kLocaleKey, value: languageCode);
    state = Locale(languageCode);
  }

  Future<void> resetToDevice() async {
    await _storage.delete(key: _kLocaleKey);
    final deviceLocale = PlatformDispatcher.instance.locale;
    final langCode = deviceLocale.languageCode;
    state = supportedLanguageCodes.contains(langCode)
        ? Locale(langCode)
        : const Locale('nl', 'NL');
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);

final languageDisplayName = {
  'en': 'English',
  'nl': 'Nederlands',
  'de': 'Deutsch',
  'fr': 'Français',
  'es': 'Español',
  'ar': 'العربية',
  'tr': 'Türkçe',
};
