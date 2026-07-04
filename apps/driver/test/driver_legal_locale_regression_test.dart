import 'dart:ui';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/l10n/driver_strings.dart';

void main() {
  group('driver legal locale regression', () {
    final termsSource =
        File('lib/screens/driver_terms_screen.dart').readAsStringSync();
    final privacySource =
        File('lib/screens/driver_privacy_screen.dart').readAsStringSync();
    final indemnificationSource =
        File('lib/screens/driver_indemnification_screen.dart')
            .readAsStringSync();
    final trustCommonSource =
        File('lib/widgets/driver_trust_flow_common.dart').readAsStringSync();

    test('legal documents follow the detected driver locale by default', () {
      for (final source in [
        termsSource,
        privacySource,
        indemnificationSource,
      ]) {
        expect(source, contains('driver_locale_provider.dart'));
        expect(source, contains('ref.watch(localeProvider)'));
        expect(
            source, contains("locale == null || locale.languageCode == 'nl'"));
        expect(source, contains('_hasManualLanguageChoice'));
      }
    });

    test('legal copy controls stay localized for Dutch and English docs', () {
      expect(
          trustCommonSource, contains('DriverStrings.legalCopyForTranslation'));
      expect(trustCommonSource, contains('DriverStrings.legalCopyAllText'));

      DriverStrings.useLocale(const Locale('nl'));
      expect(DriverStrings.legalCopyForTranslation, 'Kopieer voor vertaling');
      expect(DriverStrings.legalCopyAllText, 'Alle tekst kopiëren');

      DriverStrings.useLocale(const Locale('en'));
      expect(DriverStrings.legalCopyForTranslation, 'Copy for translation');
      expect(DriverStrings.legalCopyAllText, 'Copy all text');
    });
  });
}
