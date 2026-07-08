# AGENTS.md

## Cursor Cloud specific instructions

### Environment overview

This is a Flutter monorepo (Melos) with two mobile apps (`apps/rider/`, `apps/driver/`) and six shared packages under `packages/`. See `README.md` and `docs/TECHNICAL_DOCUMENTATION.md` for project details and architecture.

### MCP (Model Context Protocol)

- **Prefer MCP tools** for external systems when a server is configured (Notion, Datadog, Supabase, etc.): read tool schemas, then invoke tools—avoid ad-hoc HTTP or guessing when MCP can do the job. See `.cursor/rules/heycaby-mcp.mdc`.

### Key constraints

- **No simulator/emulator available.** `flutter run` will fail. Verification is limited to static analysis, unit/widget tests, and localization generation.
- **Supabase** — `SUPABASE_URL` and `SUPABASE_ANON_KEY` must be passed via `--dart-define` (or merged `.env` for IPA builds) before `HeyCabySupabase.initialize()` succeeds; they are not hardcoded in `packages/heycaby_api`. Static analysis/tests do not start the apps. **`MAPBOX_ACCESS_TOKEN`** is still required at runtime for maps.
- **Supabase environments** — QA and device testing use **staging** (`fdavszxncggswuiwggcp`, `https://fdavszxncggswuiwggcp.supabase.co`). Apply MCP migrations and SQL to staging first; production is `fvrprxguoternoxnyhoj` only after staging passes or explicit prod request.
- **Android Play upload** — Before `flutter build appbundle`, add `apps/<app>/android/key.properties` (copy from `key.properties.example`). Release `assembleRelease` / `bundleRelease` fail fast if it is missing.

### iOS physical device (full app — no “minimal” shortcuts)

- **iPhone only (no iPad):** `TARGETED_DEVICE_FAMILY = 1` in all iOS targets (Runner + widget extension), and `UIDeviceFamily` in the host `Info.plist` files lists iPhone (`1`) only. The App Store then lists the app for iPhone, not as a native iPad app.
- **Secrets + Mapbox:** `./scripts/run_rider_ios_debug.sh` merges repo / `apps/rider/.env` into `ios/.ipa_dart_defines.json` and `Flutter/Secrets.xcconfig`, then `flutter run`. This is the **full** rider app (Supabase, Mapbox, widgets, live activities); nothing is intentionally stripped for device.
- **Store-parity on device (AOT, optimizations):** same script with **`--release`** (e.g. `./scripts/run_rider_ios_debug.sh --release -d <device_id>`). Still the full binary; you lose hot reload only.
- **Xcode targets:** `HeyCabyWidgetsExtension` must match the Podfile minimum iOS (**18.0**) and use **`ENABLE_USER_SCRIPT_SANDBOXING = NO`** like Runner so Flutter/CocoaPods script phases and embed steps stay reliable. Minimum is **OS version** (iOS **18+**), not phone generation — any compatible device on iOS 18 or newer is supported. On iOS **below** that, rider/driver **`main`** shows a full-screen “update iOS” message (see `kHeyCabyMinimumIosMajorVersion` in `heycaby_utils`) and does not initialize Supabase/Mapbox.
- **Supabase:** Remote DB must have migrations applied (`supabase db push` or SQL from `supabase/migrations/`) or some RPCs/columns will 400 until the schema matches the app.
- **Clean rebuild after toolchain flakiness:** `./scripts/ios_rider_rebuild.sh` then `run_rider_ios_debug.sh` again.

### Melos version

Melos 2.9.0 is required (global install via `dart pub global activate melos 2.9.0`). Newer versions (3.x+) require a local `melos` dev dependency in the root `pubspec.yaml` which this repo does not have.

### Quick-reference commands

All commands assume `PATH` includes `$HOME/flutter/bin` and `$HOME/.pub-cache/bin`.

| Task | Command |
|------|---------|
| Bootstrap | `cd /workspace && melos bootstrap` |
| Analyze both apps | `flutter analyze --no-fatal-infos --no-fatal-warnings apps/rider/lib apps/driver/lib` |
| Enforce app/backend boundaries | `melos run guard:boundaries` |
| Rider tests | `cd /workspace/apps/rider && flutter test test/ --no-pub` |
| Driver tests | `cd /workspace/apps/driver && flutter test test/ --no-pub` |
| Generate rider l10n | `cd /workspace/apps/rider && flutter gen-l10n` |
| iOS IPAs with secrets | `./scripts/build_ios_ipas.sh` merges repo `.env` + `apps/<app>/.env` (see `scripts/ipa_build_env.template`) |
| Rider device run (full app + secrets) | `./scripts/run_rider_ios_debug.sh` (add `--release` for AOT / App Store–like performance) |
| Rider iOS clean rebuild | `./scripts/ios_rider_rebuild.sh` after Flutter/Xcode oddities |
| Android release (Play) | `cd apps/rider` or `apps/driver` → create `android/key.properties` from `android/key.properties.example` → `flutter build appbundle --release` with same dart-defines as iOS where applicable |

### Known pre-existing test failures

- `apps/rider/test/widget_test.dart` — references removed `MyApp` class (renamed to `HeyCabyRiderApp`). Safe to ignore.
- `apps/driver/test/widget_test.dart` — fails due to dangling timer from `SplashScreen` typewriter animation. Safe to ignore.

### Gotchas

- **Primary CTAs:** `buildHeyCabyMaterialTheme` sets `filledButtonTheme`, `elevatedButtonTheme`, and `floatingActionButtonTheme` from `HeyCabyColorTokens` (`onAccent`, disabled alphas). Use plain `FilledButton` / `ElevatedButton` or only `*.styleFrom(padding:, shape:, …)` for layout. Do not use `foregroundColor: colors.text` on accent fills; non-accent buttons (error, card) still need full paired colors including disabled.
- **`melos run gen:l10n` partially fails** because the driver app scope is included but the driver uses a manual `driver_strings.dart` rather than gen-l10n ARB files. Run rider l10n separately: `cd apps/rider && flutter gen-l10n`.
- After `melos bootstrap`, you must also run `flutter pub get` individually in `apps/rider/` and `apps/driver/` to generate `.dart_tool/package_graph.json` (required by `flutter test`). The bootstrap alone does not generate this file with melos 2.9.0 on newer Flutter SDK versions.
- In Cloud, the workspace root is `/workspace` (not a developer-specific path).
