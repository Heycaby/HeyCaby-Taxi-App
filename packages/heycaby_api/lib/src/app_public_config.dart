/// Public website origin (share links, marketing). Override with `--dart-define=APP_PUBLIC_WEB_ORIGIN=...`.
const String kAppPublicWebOrigin = String.fromEnvironment(
  'APP_PUBLIC_WEB_ORIGIN',
  defaultValue: 'https://heycaby.nl',
);

/// Plain homepage for marketing (not used for TAF share — see [riderInviteShareUrl]).
String get kAppPublicSiteRoot => kAppPublicWebOrigin.replaceAll(RegExp(r'/+$'), '');

/// Dev-only override when Supabase links are unavailable (`--dart-define=RIDER_IOS_APP_STORE_URL=...`).
const String kRiderIosAppStoreUrl = String.fromEnvironment(
  'RIDER_IOS_APP_STORE_URL',
  defaultValue: '',
);

/// Dev-only override when Supabase links are unavailable (`--dart-define=DRIVER_IOS_APP_STORE_URL=...`).
const String kDriverIosAppStoreUrl = String.fromEnvironment(
  'DRIVER_IOS_APP_STORE_URL',
  defaultValue: '',
);

/// Legacy QR default (prefer app-specific store URLs in TAF screens).
const String kAppQrMarketingHomeUrl = String.fromEnvironment(
  'APP_QR_MARKETING_URL',
  defaultValue: 'https://www.heycaby.nl/',
);
