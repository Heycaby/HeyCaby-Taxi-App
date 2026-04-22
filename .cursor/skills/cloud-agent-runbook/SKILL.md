---
name: cloud-agent-runbook
description: Practical setup, testing, and workflow instructions for Cloud agents working in the HeyCaby Flutter monorepo. Covers environment bootstrap, per-area testing workflows, authentication mocking, and common pitfalls.
---

# Cloud Agent Runbook

## When to use this skill

Use this skill whenever you start working in the HeyCaby codebase from a Cloud agent environment. It covers first-time setup, testing workflows for every area of the codebase, and workarounds for the limitations of a headless (no-simulator, no-emulator) environment.

## Constraints of the Cloud environment

- No iOS Simulator, no Android emulator, no physical device — `flutter run` will fail.
- No Xcode or Android SDK installed by default — native builds (`flutter build ios`, `flutter build apk`) require SDK installation and are not expected to succeed.
- Secrets (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `MAPBOX_ACCESS_TOKEN`) may not be set. Tests and analysis still work without them because they are only read at runtime.

Everything below is designed to work within these constraints.

---

## First-time environment bootstrap

Run these commands once at the start of every session. They are idempotent and safe to re-run.

```bash
# 1. Install Flutter if not already available
which flutter || (
  git clone https://github.com/flutter/flutter.git --branch stable --depth 1 ~/flutter
  export PATH="$HOME/flutter/bin:$PATH"
)
export PATH="$HOME/flutter/bin:$PATH"

# 2. Accept licenses non-interactively
flutter --version
flutter precache --no-android --no-ios --no-web

# 3. Install melos (monorepo orchestrator)
dart pub global activate melos
export PATH="$HOME/.pub-cache/bin:$PATH"

# 4. Bootstrap all packages
cd /workspace
melos run get:all
```

If `melos run get:all` fails on a single package, fall back to running `flutter pub get` inside each directory under `apps/` and `packages/` individually.

### Verifying the bootstrap succeeded

```bash
cd /workspace
flutter analyze --no-fatal-infos --no-fatal-warnings apps/rider/lib apps/driver/lib
```

Zero errors means the environment is ready. Warnings from pre-existing code are acceptable.

---

## Codebase area map

| Area | Key paths | What to verify |
|------|-----------|----------------|
| Rider app | `apps/rider/lib/`, `apps/rider/test/` | Analysis, widget tests, route audit |
| Driver app | `apps/driver/lib/`, `apps/driver/test/` | Analysis, widget tests, route audit |
| Shared API | `packages/heycaby_api/lib/` | Analysis, unit tests if present |
| Models | `packages/heycaby_models/lib/` | Analysis, unit tests if present |
| UI / Themes | `packages/heycaby_ui/lib/` | Analysis, token coverage |
| Localization | `packages/heycaby_l10n/lib/` | Gen-l10n, missing key scan |
| Maps | `packages/heycaby_map/lib/` | Analysis |
| Utilities | `packages/heycaby_utils/lib/` | Analysis, unit tests if present |

---

## Testing workflows by area

### 1. Static analysis (every change, every area)

This is the single most important verification step. Run it after every code change.

```bash
cd /workspace
flutter analyze --no-fatal-infos --no-fatal-warnings apps/rider/lib apps/driver/lib
```

To analyze shared packages too:

```bash
melos run analyze
```

Rules:
- Zero errors before reporting a task as done.
- Warnings you introduced must be fixed.
- Pre-existing warnings are acceptable.

### 2. Widget and unit tests

Shared packages currently have no `test/` directory, so `melos run test:all` will report failures for them. Prefer running app tests individually:

```bash
# Rider tests (the most comprehensive suite)
cd /workspace/apps/rider && flutter test test/ --no-pub

# Driver tests
cd /workspace/apps/driver && flutter test test/ --no-pub
```

To run a single test file:

```bash
cd /workspace/apps/rider && flutter test test/booking_flow_test.dart --no-pub
```

Key test files:
- `apps/rider/test/booking_flow_test.dart` — booking modes, Netherlands bounding box, ride payload format, payment methods, saved-address types.
- `apps/rider/test/route_audit_test.dart` — verifies every navigation target is registered in the router.
- `apps/rider/test/widget_test.dart` — **currently broken** (references removed `MyApp` class); safe to ignore.
- `apps/driver/test/widget_test.dart` — smoke test for the driver app widget tree; **may fail** due to a dangling timer from `SplashScreen`.

When you add or change a screen, update `route_audit_test.dart` to include its route.

### 3. Route audit (navigation changes)

When you add, rename, or remove a route, verify the full navigation graph:

```bash
# List all registered routes
rg "path:" apps/rider/lib/router.dart
rg "path:" apps/driver/lib/router.dart

# List all navigation calls
rg "context\.(go|push|replace)" apps/rider/lib/ --type dart
rg "context\.(go|push|replace)" apps/driver/lib/ --type dart

# Find empty onTap callbacks (likely placeholder bugs)
rg "onTap:.*null" apps/rider/lib/ --type dart
rg "onTap:.*null" apps/driver/lib/ --type dart
```

Cross-reference every `context.go('/path')` against registered routes. Every route used must exist.

### 4. Localization (string or locale changes)

```bash
# Regenerate localization files
cd /workspace
melos run gen:l10n

# Verify no missing keys — the gen-l10n step will error if ARB files are inconsistent
# Then re-run analysis to catch any import issues
flutter analyze --no-fatal-infos --no-fatal-warnings apps/rider/lib apps/driver/lib
```

ARB files live in `packages/heycaby_l10n/lib/l10n/`. Supported locales: `en`, `nl`, `ar` (RTL).
When adding a new key, add it to all three locale files.

### 5. Theme and UI token changes

After modifying `packages/heycaby_ui/`:

```bash
# Analysis catches missing imports and type errors on tokens
flutter analyze --no-fatal-infos --no-fatal-warnings apps/rider/lib apps/driver/lib

# Verify token is used — search for hardcoded hex colors (a sign of a violation)
rg "Color\(0x" apps/rider/lib/ --type dart
rg "Color\(0x" apps/driver/lib/ --type dart
rg "Colors\." apps/rider/lib/ --type dart
rg "Colors\." apps/driver/lib/ --type dart
```

Any match from those searches in screen or widget code (not in `heycaby_ui` itself) is a code-rule violation.

### 6. Supabase schema changes

If you apply a migration or modify a Supabase table:

- SQL must be idempotent: `CREATE TABLE IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`.
- Every new table must have `ENABLE ROW LEVEL SECURITY` and at least one RLS policy.
- Never use `DROP TABLE`, `TRUNCATE`, `DELETE FROM`, or `DROP COLUMN` without explicit approval.
- After applying, run the Supabase security advisor to check for missing RLS.

### 7. Shared packages (`heycaby_api`, `heycaby_models`, `heycaby_utils`)

```bash
# Run tests if the package has them
cd /workspace/packages/heycaby_api && flutter test || true
cd /workspace/packages/heycaby_models && flutter test || true
cd /workspace/packages/heycaby_utils && flutter test || true

# Always run analysis
cd /workspace && melos run analyze
```

Changes to shared packages affect both apps. Always analyze both apps after touching a package.

---

## Authentication and identity — what Cloud agents need to know

### Rider app

Riders are **not** Supabase Auth users. Identity is progressive and token-based.

- Token and identity ID are stored in `flutter_secure_storage` (keys: `rider_token`, `rider_identity_id`).
- Guest booking works without any identity; token fields are optional in the ride payload.
- Identity is created when the rider provides an email (`EmailModal`) or booking name.
- The token is sent as `x-rider-token` on Next.js API calls.

For testing in a headless environment:
- Unit tests can exercise identity logic by calling `SecureStorage` methods directly (the `flutter_secure_storage` plugin has a mock channel for tests).
- Payload validation tests (`booking_flow_test.dart`) cover the required fields without needing a live backend.

### Driver app

Drivers **are** Supabase Auth users (email + OTP or email + password).

- Session is managed by `supabase_flutter` and stored in the platform keychain.
- Splash screen checks `HeyCabySupabase.client.auth.currentSession`; null means redirect to `/login`.
- `DriverApi` attaches `Authorization: Bearer <accessToken>` to requests.

For testing in a headless environment:
- The driver smoke test (`apps/driver/test/widget_test.dart`) pumps the app widget without a live session.
- For deeper tests, mock `Supabase.instance.client.auth` using Riverpod overrides in the test's `ProviderScope`.

---

## Feature flags

There is no feature-flag system in this codebase. Feature gating is done via:

1. **Route presence** — a screen exists only after its route is added to `router.dart`.
2. **Conditional UI** — `if` checks on model fields or provider state (e.g., `if (booking.isScheduled)`).
3. **Backend-driven** — the Next.js API or Supabase RLS can gate behavior server-side.

To mock a "flag" for testing, override the relevant Riverpod provider in a test's `ProviderScope`.

---

## Environment variables and secrets

Required at runtime (not needed for analysis or tests):

| Variable | Purpose | Prefix |
|----------|---------|--------|
| `SUPABASE_URL` | Supabase project URL | `https://` |
| `SUPABASE_ANON_KEY` | Supabase anon/publishable key | `eyJ` |
| `MAPBOX_ACCESS_TOKEN` | Mapbox public token | `pk.` |

Both apps load these from a `.env` file via `flutter_dotenv` in `main.dart`. The `.env` files are gitignored.

For Cloud agents:
- Analysis and tests do **not** require these values.
- If you need to create a `.env` for a build check, use placeholder values:
  ```
  SUPABASE_URL=https://placeholder.supabase.co
  SUPABASE_ANON_KEY=placeholder
  MAPBOX_ACCESS_TOKEN=pk.placeholder
  ```
- Never commit real secrets. Never log secrets.

---

## Common pitfalls and fixes

| Problem | Fix |
|---------|-----|
| `melos: command not found` | `dart pub global activate melos && export PATH="$HOME/.pub-cache/bin:$PATH"` |
| `flutter: command not found` | Install Flutter or `export PATH="$HOME/flutter/bin:$PATH"` |
| `pub get` fails in a single package | Run `flutter pub get` in the workspace root first, then retry in the failing package |
| Analysis reports errors in generated files | Generated files (`*.g.dart`, `*.freezed.dart`, `l10n/`) are excluded in `analysis_options.yaml` — if they appear, run `melos run gen:l10n` |
| `flutter test` fails with "no connected devices" | Tests do not require a device — if you see this, ensure you are using `flutter test`, not `flutter run` |
| Route audit finds a mismatch | Add or fix the route in `router.dart` and update `route_audit_test.dart` |
| Hardcoded color/string lint hits | Move the value to `heycaby_ui` tokens or `AppLocalizations` respectively |
| `melos run test:all` fails across many packages | Shared packages have no `test/` directory, so `flutter test` exits non-zero on them. Run app tests individually instead: `cd apps/rider && flutter test test/ --no-pub` |
| `apps/rider/test/widget_test.dart` fails with `MyApp` not found | Pre-existing issue — the test references a class that was renamed to `HeyCabyRiderApp`. Ignore or fix the import. |
| `apps/driver/test/widget_test.dart` fails with pending timer | Pre-existing issue — `SplashScreen` starts a typewriter animation in `initState`, leaving a dangling timer. Ignore or add `await tester.pumpAndSettle()` / cancel the timer in `dispose`. |

---

## Quick-reference command cheat sheet

```bash
# Bootstrap
melos run get:all

# Analyze everything
flutter analyze --no-fatal-infos --no-fatal-warnings apps/rider/lib apps/driver/lib

# Run all tests
melos run test:all

# Run rider tests only
cd /workspace/apps/rider && flutter test test/ --no-pub

# Run driver tests only
cd /workspace/apps/driver && flutter test test/ --no-pub

# Regenerate localization
melos run gen:l10n

# Search for code-rule violations
rg "Color\(0x" apps/ --type dart
rg "Colors\." apps/ --type dart -g '!test/'
rg "EdgeInsets\.only" apps/ --type dart
```

---

## Updating this skill

When you discover a new testing trick, workaround, or runbook-worthy pattern during a session, add it to this file so future agents benefit immediately.

Guidelines for updates:
- Add new pitfalls to the **Common pitfalls and fixes** table.
- Add new per-area testing steps under the relevant **Testing workflows** subsection.
- If a new codebase area emerges (e.g., a new shared package), add a row to the **Codebase area map** table and a corresponding testing subsection.
- Keep entries concrete and actionable — prefer exact commands and file paths over vague advice.
- After editing this file, run `flutter analyze` to make sure no documentation-adjacent code samples have syntax issues, then commit the update with a message like `chore: update cloud-agent-runbook skill`.
