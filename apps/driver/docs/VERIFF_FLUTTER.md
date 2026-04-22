# Driver app — Veriff (v2) integration

This doc matches the **Supabase Edge Functions** contract for Veriff: HMAC-signed server calls, per-integration `VERIFF_BASE_URL`, and rich decision webhooks on the backend.

## Flutter: `DRIVER_VERIFF_HVP_URL` (static HVP vs API session)

| Build | Behaviour |
|-------|-----------|
| **`DRIVER_VERIFF_HVP_URL` has a value** (see `lib/config/driver_veriff_config.dart`) | [DriverVeriffScreen] opens that **static HVP URL** in the browser and **does not** call `create-driver-veriff-session`. |
| **`DRIVER_VERIFF_HVP_URL` empty** | **Standard flow:** `create-driver-veriff-session` → Veriff `POST /sessions` → response `verification.url` → open in browser (`DriverDataService.startVeriffVerificationAndPersist`). Sessions include `endUserId` = `drivers.id`. |

**Use API session flow (recommended for production):**

```bash
flutter run --dart-define=DRIVER_VERIFF_HVP_URL=
```

There must be **nothing** after `=` so the compile-time string is empty.

The app does **not** use Veriff’s native mobile SDK; it launches the **hosted** session URL in the **external browser** (`url_launcher`), whether that URL came from the static HVP or from the API.

### Two different auth layers (don’t mix them up)

| Layer | Who talks to whom | What auth is used |
|-------|-------------------|-------------------|
| **A. Flutter → Supabase** | App calls Edge Function `create-driver-veriff-session` | **`Authorization: Bearer <Supabase user JWT>`** + **`apikey: <Supabase anon key>`**. The app does **not** send `X-AUTH-CLIENT` to Veriff. |
| **B. Edge Function → Veriff** | Your deployed function calls Veriff `POST /v1/sessions` | **`X-AUTH-CLIENT`** = Veriff API key (secret `VERIFF_API_KEY`), **`Content-Type: application/json`**, HMAC per Veriff docs. Happens **only on the server**. |

A **`401 Invalid JWT` on `functions.invoke`** is **layer A** — the **Supabase API gateway** is rejecting the **logged-in user’s JWT** (or the request isn’t carrying it). Fix: same Supabase project URL + anon key as the user’s session, `functions.setAuth(accessToken)`, sign out/in, or check Edge Function **JWT verification** settings.

**Veriff’s** notes about **`X-AUTH-CLIENT`** and **`sessionToken`** apply to **layer B** (server → Veriff). If layer B failed, you’d typically get a **non-200 from the Edge Function body** after the gateway already accepted the Flutter request — not the same as gateway `401` before the function runs.

---

## Supabase secrets (Edge Functions)

Set in **Dashboard → Project Settings → Edge Functions → Secrets**:

| Secret | Source |
|--------|--------|
| `VERIFF_API_KEY` | Veriff Customer Portal → Integrations → Auth methods → API key |
| `VERIFF_SHARED_SECRET` | Same → Shared secret key (used for **outgoing** `x-hmac-signature` and webhook verification) |
| `VERIFF_BASE_URL` | Integrations → API keys → **BaseURL** (per integration, e.g. `https://stationapi.veriff.com`) |
| `APP_URL` | Public app origin, e.g. `https://heycaby.nl` |

### How to set secrets (Supabase)

1. **Dashboard (recommended)**  
   **Supabase** → your project → **Project Settings** → **Edge Functions** → **Secrets** → **Add new secret**.  
   Add each name/value pair from the table above (`VERIFF_API_KEY`, `VERIFF_SHARED_SECRET`, `VERIFF_BASE_URL`, `APP_URL`).  
   Redeploy Edge Functions after changing secrets if your project caches env at deploy time.

2. **CLI** (from a machine with the Supabase CLI logged in):

   ```bash
   supabase secrets set VERIFF_API_KEY='your-api-key' \
     VERIFF_SHARED_SECRET='your-master-signature-key' \
     VERIFF_BASE_URL='https://stationapi.veriff.com' \
     APP_URL='https://heycaby.nl' \
     --project-ref fvrprxguoternoxnyhoj
   ```

   Use your real `--project-ref` from **Project Settings → General**.

**Never** put `VERIFF_API_KEY` or `VERIFF_SHARED_SECRET` in the Flutter app or in a public repo — only in Supabase (or your backend) secrets.

---

## Exact API formats

There are **three** HTTP surfaces: (A) app → your Edge Function, (B) your Edge Function → Veriff, (C) Veriff → your webhook.

### A) Flutter → `create-driver-veriff-session` (Supabase Functions)

The driver app calls this with the **logged-in user’s JWT** (handled by `supabase_flutter`; you don’t paste keys in the client).

```http
POST https://<project-ref>.supabase.co/functions/v1/create-driver-veriff-session
Authorization: Bearer <supabase_user_jwt>
Content-Type: application/json
```

**Body (optional):**

```json
{
  "endUserId": "550e8400-e29b-41d4-a716-446655440000"
}
```

Use the driver row UUID (`drivers.id`) when available — Veriff stores this as `verification.endUserId` for audit.

**Success body (shape may vary; app accepts several aliases):**

```json
{
  "sessionId": "…",
  "url": "https://…veriff…",
  "verification": {
    "id": "…",
    "url": "https://…veriff…"
  }
}
```

The app opens `url` (or `verification.url`) in the **external browser**.

---

### B) Your backend → Veriff Station API — `POST /v1/sessions`

This is what the **`create-driver-veriff-session`** Edge Function should implement server-side (not called from Flutter with the API key).

Official reference: [Create session — `/v1/sessions`](https://devdocs.veriff.com/apidocs/v1sessions).

```http
POST https://stationapi.veriff.com/v1/sessions
Content-Type: application/json
X-AUTH-CLIENT: <VERIFF_API_KEY>
```

**Minimum JSON body:**

```json
{
  "verification": {}
}
```

**Typical expanded body** (callback is often set in Veriff Portal instead of here):

```json
{
  "verification": {
    "callback": "https://heycaby.nl/driver/veriff/callback",
    "endUserId": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

**Response (simplified):**

```json
{
  "verification": {
    "id": "<session_id>",
    "url": "<hosted_flow_url>",
    "sessionToken": "…"
  }
}
```

**HMAC:** Outgoing requests may require `X-HMAC-SIGNATURE` per [HMAC authentication](https://devdocs.veriff.com/docs/hmac-authentication-and-endpoint-security) (sign the **raw request body** with `VERIFF_SHARED_SECRET`; exact rules match Veriff’s doc). Your Edge Function must mirror whatever Veriff expects for your integration.

---

### C) Veriff → `veriff-webhook` (incoming)

```http
POST https://<project-ref>.supabase.co/functions/v1/veriff-webhook
Content-Type: application/json
```

Veriff attaches signature headers; **`veriff-webhook`** must verify them with **`VERIFF_SHARED_SECRET`** before trusting the body. Payload shapes differ by webhook type — see [Webhooks guide](https://devdocs.veriff.com/docs/webhooks-guide), [Decision webhook](https://devdocs.veriff.com/v1/docs/decision-webhook), [Event webhook](https://devdocs.veriff.com/v1/docs/event-webhook).

---

## Portal URLs (Veriff Station → Integration → Settings)

Replace `<project-ref>` with your Supabase project ref (see **Project Settings → General → Reference ID**). Production example: `fvrprxguoternoxnyhoj`.

| Field in Veriff UI | Value |
|--------------------|--------|
| **Callback URL** (where the user lands after finishing the Veriff flow) | `https://heycaby.nl/driver/veriff/callback` — use **`www`** if that is what your PWA route is (`https://www.heycaby.nl/driver/veriff/callback`). Must match the route implemented in **HeyCaby web**. |
| **Webhook events URL** (session started, submitted, etc.) | `https://<project-ref>.supabase.co/functions/v1/veriff-webhook` |
| **Webhook decisions URL** (approved / declined / resubmission) | `https://<project-ref>.supabase.co/functions/v1/veriff-webhook` |
| **Webhook PEP & Sanctions URL** | Same as above **unless** you deploy a separate Edge Function for PEP-only payloads; one handler can process all webhook types. |

**TLS:** Supabase Edge Function URLs use a public CA certificate — leave **“Do not allow self signed certificates”** enabled.

**Do not** use Veriff’s demo redirect (`https://www.veriff.com/get-verified?...`) as your production **Callback URL**; that is only an example in their UI.

**Flutter note:** The **Callback URL** is for the browser return path; the native app mainly relies on **Realtime** on `drivers` + **app resume** refresh unless you add deep links to the same route.

## Terms gate (before Veriff)

Drivers must **read and agree** to the chauffeur terms (with links to the published HTML) before `launchUrl` opens the Veriff session. Implemented in `veriff_terms_consent_sheet.dart`; URLs in `lib/config/driver_legal_urls.dart` (`DRIVER_TERMS_URL`, `DRIVER_TERMS_VERIFF_URL`).

## Flutter client contract

1. **`create-driver-veriff-session`**  
   - Invoked with optional body: `{ "endUserId": "<drivers.id UUID>" }` for Veriff’s audit trail.  
   - Response: `{ "sessionId", "url", "verification"?: { "id", "url" } }` (shape may vary slightly; the app parses top-level and nested `verification`).

2. **Open session**  
   - Launch `url` in the **external** browser (`url_launcher`).

3. **Status**  
   - Webhook updates the `drivers` row (`veriff_status`, expiry, name, etc.).  
   - The **Documents** screen subscribes to **Realtime** `UPDATE` on `public.drivers` for the current driver `id`, and refreshes compliance on **app resume** while a watch is active.

## Licence category data (NL)

Exact per-category expiry (`driversLicenseCategoryUntil`, e.g. category **B**) may require a **feature flag** from your Veriff Solutions Engineer — not enabled by default. Backend should prefer that data when present; the app only reflects DB fields exposed to the client.

## Hosted Verification Page (HVP) static URL

Veriff Station can expose a **public static link** (e.g. `https://hvp.saas-3.veriff.com/<uuid>`) under **HVP → Availability**. Anyone with the link can start a session; **rate limits** apply in the Veriff dashboard.

In the driver app, `DRIVER_VERIFF_HVP_URL` (`lib/config/driver_veriff_config.dart`) controls:

- **Non-empty** — Opens this URL in the browser **instead of** calling `create-driver-veriff-session` (no Edge Function JWT for that step).
- **Empty** — Use `flutter run --dart-define=DRIVER_VERIFF_HVP_URL=` to force **Station API** session flow only.

Linking webhooks to `drivers.id` is easier with **API-created sessions** (`verification.endUserId`). For HVP, users may enter **User ID** on Veriff’s form if your flow requires it.

### After verification: redirect vs app

- Veriff’s **callback URL** only opens in the **browser** — it does **not** automatically bring users back into the Flutter app. Users switch back with the app switcher (or you add **Universal Links / App Links** on your callback page later).
- The driver app **refreshes compliance when the app resumes** (foreground) so licence status can update after you return from Safari/Chrome.

### If the app still shows “Action needed” after Veriff says verified

The UI shows **Verified** for the driving licence row when either:

- `drivers.rijbewijs_verified` is `true`, **or**
- `drivers.veriff_status` is one of `approved` / `success` / `completed` (and expiry from `rijbewijs_expiry` or `veriff_id_expiry`).

If **`veriff_status` stays empty** in Supabase, the **webhook** is not updating your `drivers` row — common with **HVP** if the session is not tied to this driver (e.g. **User ID** on the HVP form must match `drivers.id`, or use **API session** flow with `endUserId`). Fix on the **Edge Function** / DB side, then pull-to-refresh or reopen the screen.

---

## Troubleshooting: `401` / `Invalid JWT` on `create-driver-veriff-session`

Supabase checks the **Bearer** token **before** your Edge Function runs.

The driver app calls **`functions.setAuth(session.accessToken)`** before `invoke` so the gateway receives your **user** JWT (not only the anon key). If you still see `401`, check:

1. **Stale session** — Sign out and sign in again, or hot-restart after a long idle. The app calls `refreshSession()` before starting Veriff and retries once on `401`.
2. **URL / anon key mismatch** — `SUPABASE_URL` and `SUPABASE_ANON_KEY` must be from the **same** project as the account you used to log in (Dashboard → **Settings** → **API**). If you use `--dart-define`, ensure both match; `.env` alone is not read by Flutter unless you wire it.
3. **Rotated anon key** — If the key was rotated in Supabase, reinstall the app or clear storage and sign in again with the updated key in your build/run config.
4. **Project JWT / API keys** — If `401` persists after sign-in + `setAuth`, check Supabase Dashboard → Edge Functions → your function → JWT settings, and that your app’s `SUPABASE_ANON_KEY` matches **Settings → API** for the same project.
