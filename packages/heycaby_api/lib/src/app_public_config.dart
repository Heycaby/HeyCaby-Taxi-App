/// Public website origin (share links, marketing). Override with `--dart-define=APP_PUBLIC_WEB_ORIGIN=...`.
const String kAppPublicWebOrigin = String.fromEnvironment(
  'APP_PUBLIC_WEB_ORIGIN',
  defaultValue: 'https://heycaby.nl',
);

/// Plain homepage for marketing / TAF share & copy: **no** `/invite`, `/i/…`, or query string.
String get kAppPublicSiteRoot => kAppPublicWebOrigin.replaceAll(RegExp(r'/+$'), '');

/// Encoded in the Rider TAF **QR only** (camera opens this URL). Share / copy use [kAppPublicSiteRoot] (plain homepage).
/// Override with `--dart-define=APP_QR_MARKETING_URL=...` (e.g. staging homepage).
const String kAppQrMarketingHomeUrl = String.fromEnvironment(
  'APP_QR_MARKETING_URL',
  defaultValue: 'https://www.heycaby.nl/',
);
