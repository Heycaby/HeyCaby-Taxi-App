/// Veriff hosted verification — opens Veriff’s **static HVP** in the system browser.
///
/// ## Resolution order ([resolveDriverVeriffHvpUrl])
/// 1. Supabase **`app_config.driver_veriff_hvp_url`** when present (change URL without rebuilding).
/// 2. **`DRIVER_VERIFF_HVP_URL`** dart-define when non-empty (local / CI).
/// 3. **[kDriverVeriffHvpFallbackUrl]** — same URL as the seeded migration; used when DB is
///    unreachable, RLS blocks `app_config`, or the row is missing so drivers still reach Veriff
///    without deploying Edge Functions.
///
/// **Note:** The driver screen uses the hosted URL path only (no hard dependency on
/// `create-driver-veriff-session`). See `VERIFF_FLUTTER.md` for optional Edge session APIs.
library driver_veriff_config;

/// Packaged fallback — matches `supabase/migrations/*_app_config_driver_veriff_hvp_url.sql`.
const String kDriverVeriffHvpFallbackUrl =
    'https://hvp.saas-3.veriff.com/7aca3362-d582-4d4f-b270-67dd3aed3571';

const String kDriverVeriffHvpUrl = String.fromEnvironment(
  'DRIVER_VERIFF_HVP_URL',
  defaultValue: '',
);

/// Non-empty hosted Veriff URL for [DriverVeriffScreen].
String resolveDriverVeriffHvpUrl(String? appConfigValue) {
  final a = appConfigValue?.trim();
  if (a != null && a.isNotEmpty) return a;
  final d = kDriverVeriffHvpUrl.trim();
  if (d.isNotEmpty) return d;
  return kDriverVeriffHvpFallbackUrl;
}
