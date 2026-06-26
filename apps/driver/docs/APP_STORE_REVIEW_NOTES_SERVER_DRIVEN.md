# Driver app: server-driven behavior & App Store review

Use this when filling **App Review Information** / **Notes** in App Store Connect, or when an reviewer asks why the app loads configuration from the network.

## Terminology (for your team)

- **“Serverless” (AWS sense)** — compute that scales to zero (Lambda, Cloud Functions). HeyCaby’s **Go API on AWS** and **Supabase** are server-side, but the product goal you describe is better named **server-driven** or **thin client**: **business rules and eligibility live on servers**; the iOS app is mainly UI, device APIs, and calling those servers.
- **Fully “static app”** in the strict sense is **not** accurate: the shipped binary still contains Flutter UI code, navigation, maps, permissions, and offline-safe defaults. What you *can* avoid is **re-shipping the store** for every **policy/threshold/copy** change if those are served as **data** (JSON) and enforced on the backend.

## What is already server-driven (deep-dive summary)

| Area | How it works | Primary code / contracts |
|------|----------------|---------------------------|
| **Go API base URL** | Can be resolved from Supabase `app_config` + RPC (and defines for overrides) so infra can move without always rebaking the same hostname. | `packages/heycaby_api/lib/src/driver_api_base_resolver.dart` |
| **Remote tuning & flags** | Supabase RPC `fn_driver_runtime` → `config.feature_flags` + `config.search` (search windows, radii, TTL-style knobs). Go `/api/v1/config` is **not** required for launch. | `apps/driver/lib/services/driver_runtime_service.dart`, `apps/driver/lib/models/driver_runtime_models.dart` |
| **Go-online eligibility** | **Authoritative** checklist: Supabase `fn_driver_runtime` → `readiness` (`can_go_online`, checklist items, progressive milestones). Flutter is a dumb renderer. | `apps/driver/lib/utils/driver_go_online_runtime_action.dart` |
| **Going online / status** | Supabase RPC `fn_driver_set_status` — blocked reasons, payment redirects, messages from JSON. Go `/api/v1/driver/status` remains in repo but is not the launch path. | `driver_runtime_service.dart`, `packages/heycaby_api/lib/src/driver_api.dart` |
| **Ride accept / decline** | HTTP client (`DriverApi`) with JWT — not direct status writes from UI for those actions. | `packages/heycaby_api/lib/src/driver_api.dart` |
| **Auth & profile data** | Supabase Auth + Postgres (RLS); large surface in `DriverDataService` — still **server** data, accessed via SDK rather than only Go. | `apps/driver/lib/services/driver_data_service.dart` |

## What still lives in the app (so you still need store builds sometimes)

- **New screens, flows, and navigation** — require a new binary unless you invest in a full **server-driven UI schema** (not current scope for the whole app).
- **Native / Flutter plugins** — Mapbox, push, Veriff browser flow, permissions — ship with the app.
- **Strings & accessibility** — mostly `driver_strings.dart` (not gen-l10n); marketing/legal copy on the web is separate.
- **UX timers and shells** — e.g. incoming request countdown is client-side timing; **outcome** still goes through API where required.
- **Direct Supabase reads/writes** — many lists and profile updates use the Supabase client. That is still **remote** logic enforcement (RLS + triggers), but **not** the same as “everything goes only through the Go binary.” Splitting reads vs writes is a product/engineering choice documented in `apps/driver/DRIVER_APP_MAP.md` (e.g. ride lifecycle via API).

For a wider gap analysis (what could move next), see `BUSINESS-LOGIC-SEPARATION.md` and `SERVER-DRIVEN-APP-ARCHITECTURE.md` at repo root.

## App Store review — does this hurt approval?

**Generally no**, if you stay within Apple’s line:

- **Guideline 2.5.2** — Apps must not download or install **executable code** that changes the app’s behavior outside review. **Remote JSON** (feature flags, copy, numeric limits) and **API-driven rules** that the app **interprets in fixed, reviewed code paths** are normal (same class as many production apps).
- **Risky patterns** (avoid): downloading scripts/plugins that **eval** new behavior; hot-patching **native** code; opaque bytecode not shipped with the app.

HeyCaby’s pattern — **fixed Dart client** + **server returns structured JSON** + **backend enforces** eligibility and payments — is **aligned** with typical review expectations.

**Disclosure obligations** (separate from “server-driven”):

- **App Privacy** — declare data collected and linked to the user (location, identifiers, diagnostics, etc.) consistently with your privacy policy.
- **Account deletion** — if you offer account creation, Guideline 5.1.1(v) still applies; deletion path must work regardless of where “logic” runs.
- **Location** — driver app is location-centric; justify **When In Use** / **Always** usage strings against real features.

## Copy-paste: “Notes for reviewer” (App Store Connect)

You can paste and adjust the bracketed parts:

```
HeyCaby Driver is a native Flutter app for professional drivers. Core eligibility,
pricing gates, and “go online” rules are enforced on our backend APIs (HTTPS JSON),
not only inside the app binary. The app fetches remote configuration (e.g. search
windows, feature toggles) from our API and applies it using built-in, App Review–visible
Dart code paths—similar to standard remote configuration. We do not download or execute
arbitrary code to change app behavior.

The app uses Supabase for authentication and database-backed features with server-side
RLS policies, and uses our Go API for driver operational endpoints (e.g. readiness and
status). Location is used for dispatch and navigation consistent with the app’s purpose.

If you need test credentials or a demo driver account, use: [FILL IN].

**Going online in review:** Create the demo user in Supabase Auth and set **User metadata** to include  
`"review_account": true` (boolean). That JWT flag makes the Go API treat the session as **App Store review**:
readiness checks are bypassed, **weekly platform fee is not required**, and the role is treated as **driver**
(see `backend/internal/middleware/auth/auth.go` `extractUserType` / `extractReviewAccount`).  
After editing metadata the reviewer must **sign out and sign back in** so the access token is refreshed.
```

## Copy-paste: short “Review notes” variant (character-limited fields)

```
Driver ops app: eligibility & config from HTTPS JSON APIs + Supabase; no downloadable
executable logic. Location for dispatch/navigation. Demo: [credentials or “see attachment”].
```

---

**Maintainers:** When you add **new** remote-controlled behavior, keep `SERVER-DRIVEN-APP-ARCHITECTURE.md` in mind: prefer **data + server enforcement**, keep the client a **renderer + transport**, and document anything that could look like “changing the app without review.”
