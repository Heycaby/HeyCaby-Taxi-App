import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
        expect(source, contains("locale?.languageCode != 'en'"));
        expect(source, contains('_hasManualLanguageChoice'));
      }
    });

    test('legal copy controls stay localized for Dutch and English docs', () {
      expect(trustCommonSource, contains('Kopieer voor vertaling'));
      expect(trustCommonSource, contains('Copy for translation'));
      expect(trustCommonSource, contains('Alle tekst kopiëren'));
      expect(trustCommonSource, contains('Copy all text'));
    });
  });
}
