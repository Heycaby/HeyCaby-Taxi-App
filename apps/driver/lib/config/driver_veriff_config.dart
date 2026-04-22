/// Veriff Hosted Verification Page (HVP) — optional static URL from Veriff Station → HVP → Availability.
///
/// ## Non-empty value (default below)
/// [DriverVeriffScreen] **skips** `create-driver-veriff-session` and opens this URL in the
/// **system browser** (`url_launcher`). No per-session `POST /v1/sessions` from the app;
/// rate limits and webhook ↔ driver linking are your responsibility on the Veriff side.
///
/// ## Empty value — standard API session flow
/// Build with:
/// `flutter run --dart-define=DRIVER_VERIFF_HVP_URL=`
/// (nothing after `=`). Then [DriverVeriffScreen] calls Edge Function `create-driver-veriff-session`,
/// which performs Veriff `POST /sessions` and returns `verification.url`. The app opens that
/// URL in the browser — same hosted flow, but **sessions are created via API** with
/// `endUserId` = `drivers.id` (see `VERIFF_FLUTTER.md`).
///
/// **Note:** This project does **not** embed Veriff’s mobile SDK; hosted verification always
/// opens the session URL in an external browser.
///
/// **Trade-offs**
/// - **HVP static link**: Simple; no JWT to Edge Function for session creation.
/// - **API session** (empty define): Preferred for production; requires deployed function + valid Supabase JWT.
const String kDriverVeriffHvpUrl = String.fromEnvironment(
  'DRIVER_VERIFF_HVP_URL',
  defaultValue: 'https://hvp.saas-3.veriff.com/d022312c-dc4b-4adc-8f17-6dcf62b628f5',
);
