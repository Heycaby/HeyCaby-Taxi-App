import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('driver design system regression', () {
    final appSource = File('lib/app.dart').readAsStringSync();
    final localeSource =
        File('lib/providers/driver_locale_provider.dart').readAsStringSync();
    final preferencesScreenSource =
        File('lib/screens/driver_preferences_screen.dart').readAsStringSync();
    final preferencesBodySource =
        File('lib/widgets/driver_preferences_body.dart').readAsStringSync();
    final splashSource =
        File('lib/widgets/driver_brand_moment_body.dart').readAsStringSync();
    final themeProviderSource = File(
      '../../packages/heycaby_ui/lib/src/theme/theme_provider.dart',
    ).readAsStringSync();

    test('locks driver app to the single green theme', () {
      expect(
        themeProviderSource,
        contains('state = kThemes[kDriverDefaultTheme]!'),
      );
      expect(
        themeProviderSource,
        contains(
            'await storage.write(key: _kThemeKey, value: kDriverDefaultTheme)'),
      );
      expect(preferencesScreenSource, isNot(contains('_showThemePicker')));
      expect(preferencesScreenSource, isNot(contains('kThemes.keys')));
      expect(preferencesBodySource, isNot(contains('onTheme')));
      expect(preferencesBodySource, isNot(contains('themeSubtitle')));
    });

    test('supports only Dutch, English, Spanish, and Arabic for driver app',
        () {
      expect(localeSource, contains("['nl', 'en', 'es', 'ar']"));
      expect(localeSource, isNot(contains("'de'")));
      expect(localeSource, isNot(contains("'fr'")));
      expect(localeSource, isNot(contains("'tr'")));
      expect(appSource, contains("Locale('nl')"));
      expect(appSource, contains("Locale('en')"));
      expect(appSource, contains("Locale('es')"));
      expect(appSource, contains("Locale('ar')"));
      expect(appSource, isNot(contains("Locale('de')")));
      expect(appSource, isNot(contains("Locale('fr')")));
      expect(appSource, isNot(contains("Locale('tr')")));
    });

    test('keeps splash on the green driver palette', () {
      expect(splashSource, contains('Color(0xFF00A651)'));
      expect(splashSource, isNot(contains('Color(0xFFFFD100)')));
      expect(splashSource, contains('letterSpacing: 0'));
    });
  });
}
