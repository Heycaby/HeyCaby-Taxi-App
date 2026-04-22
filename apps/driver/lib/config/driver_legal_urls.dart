/// Canonical URLs for driver legal content (matches `heycaby-tos/chauffeur/voorwaarden/` when deployed).
///
/// Override at build time:
/// `flutter run --dart-define=DRIVER_TERMS_URL=https://staging.example/voorwaarden`
const String kDriverTermsUrl = String.fromEnvironment(
  'DRIVER_TERMS_URL',
  defaultValue: 'https://www.heycaby.nl/chauffeur/voorwaarden',
);

/// Deep link to §3 Identiteitsverificatie (Veriff) in the chauffeur terms.
const String kDriverTermsVeriffSectionUrl = String.fromEnvironment(
  'DRIVER_TERMS_VERIFF_URL',
  defaultValue: 'https://www.heycaby.nl/chauffeur/voorwaarden#a3',
);
