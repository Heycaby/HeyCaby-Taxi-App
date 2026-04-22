# HeyCaby — Flutter monorepo

**HeyCaby** is a Dutch taxi marketplace: riders book rides in the consumer app; professional drivers use **HeyCaby Driver** for dispatch, navigation, and earnings. This repository contains **two production Flutter apps** and **six shared Dart packages**, managed with **Melos**.

| | |
|--|--|
| **Repository** | [github.com/rydtaptaxi/HeyCaby](https://github.com/rydtaptaxi/HeyCaby) |
| **Clone** | `git clone https://github.com/rydtaptaxi/HeyCaby.git` |
| **Stack** | Flutter 3.19+ · Dart 3.3+ · Supabase · Mapbox · Riverpod · go_router |
| **Backend** | Supabase (Postgres, Auth, Realtime) + HeyCaby **web** API at [heycaby.nl](https://heycaby.nl) (Next.js, separate repo) |

---

## Table of contents

1. [Overview](#overview)
2. [Rebrand & repository history (2026)](#rebrand--repository-history-2026)
3. [Monorepo layout](#monorepo-layout)
4. [Prerequisites](#prerequisites)
5. [Bootstrap & first-time setup](#bootstrap--first-time-setup)
6. [Configuration & secrets](#configuration--secrets)
7. [Running the apps](#running-the-apps)
8. [iOS & Android notes](#ios--android-notes)
9. [Quality checks & tests](#quality-checks--tests)
10. [Release builds (iOS IPA)](#release-builds-ios-ipa)
11. [Design system & localization](#design-system--localization)
12. [CI & automation](#ci--automation)
13. [Documentation](#documentation)
14. [Contributing & code rules](#contributing--code-rules)
15. [Security](#security)

---

## Overview

- **Rider app** (`apps/rider/`, package `heycaby_rider`): map-first booking, guest-friendly identity (token-based), RTL (Arabic), multi-theme.
- **Driver app** (`apps/driver/`, package `heycaby_driver`): Supabase Auth, background-friendly location, Mapbox, compliance (e.g. Veriff, documents), in-app support.
- **Shared packages** (`packages/heycaby_*`): API client, models, UI tokens/themes, map services, utils, optional shared l10n ARBs.

The **Supabase schema and Edge Functions** are the system of record; Flutter work consumes them. Detailed architecture, features, and history are in **[docs/TECHNICAL_DOCUMENTATION.md](docs/TECHNICAL_DOCUMENTATION.md)**.

---

## Rebrand & repository history (2026)

The product and GitHub project were rebranded to **HeyCaby** (April 2026). **Git history is unchanged**—commits, branches, and tags are the same repository, renamed.

| Area | Summary |
|------|---------|
| **Packages** | `heycaby_api`, `heycaby_ui`, `heycaby_models`, `heycaby_map`, `heycaby_utils`, `heycaby_l10n` |
| **Public APIs** | Types such as `HeyCabySupabase`, `HeyCabyThemeData`, `HeyCabyColorTokens` |
| **Git remote** | `https://github.com/rydtaptaxi/HeyCaby.git` — update old clones: `git remote set-url origin https://github.com/rydtaptaxi/HeyCaby.git` |
| **Specs & legal** | `heycaby-flutter-doc/` (`heycaby_*.md`), `heycaby-tos/`, `integrations/heycaby-web-public/` |
| **iOS bundle IDs** | `nl.heycaby.rider` / `nl.heycaby.driver` |
| **Android IDs** | `com.heycaby.rider` / `com.heycaby.driver` |
| **Deep links** | `heycaby://` — configure **Supabase Auth** redirect URLs accordingly |
| **Theme storage** | Primary key `heycaby_theme_id`; legacy on-device key still read once then migrated |

**Brand guide, App Store SKUs, and checklist:** [docs/Rebranding.MD](docs/Rebranding.MD).

---

## Monorepo layout

Your checkout folder name may differ (e.g. `HeyCaby`, `HEYCABY-FLUTTER`); paths below are relative to the repo root.

```
.
├── apps/
│   ├── rider/                 # HeyCaby consumer app (heycaby_rider)
│   └── driver/                # HeyCaby Driver (heycaby_driver)
├── packages/
│   ├── heycaby_api/           # Supabase, Dio, secure storage, identity helpers
│   ├── heycaby_models/        # Shared data types
│   ├── heycaby_ui/            # Themes, tokens, glass widgets
│   ├── heycaby_l10n/          # Optional shared ARBs
│   ├── heycaby_map/           # Mapbox-facing services
│   └── heycaby_utils/         # Validators, formatters, shared helpers
├── heycaby-flutter-doc/       # Architecture & build spec markdown (reference)
├── heycaby-tos/               # Static chauffeur terms & support HTML
├── integrations/
│   └── heycaby-web-public/    # Drop-in public/ assets for HeyCaby web
├── supabase/                  # Migrations, SQL scripts, Edge Function sources
├── simulation/                # Python helpers for ride/driver simulation
├── scripts/                   # IPA build, legal sync to web repo, etc.
├── docs/                      # Technical docs, rebranding, Supabase notes
├── melos.yaml                 # Workspace scripts (get:all, analyze, dev, …)
├── pubspec.yaml               # Root workspace marker (heycaby_workspace)
└── AGENTS.md                  # Agent/CI constraints and command cheatsheet
```

---

## Prerequisites

| Tool | Notes |
|------|--------|
| **Flutter** | Stable, **≥ 3.19** (see each app’s `pubspec.yaml`) |
| **Dart** | **≥ 3.3** |
| **Melos** | **2.9.0** recommended: `dart pub global activate melos 2.9.0` — ensure `~/.pub-cache/bin` is on `PATH` |
| **CocoaPods** | For iOS: `pod` available when working in `apps/*/ios/` |
| **Xcode / Android SDK** | For device and store builds |

---

## Bootstrap & first-time setup

From the repository root:

```bash
# Link local packages (Melos)
melos bootstrap

# Install dependencies in every app/package
melos run get:all
```

On recent Flutter SDKs, also run **`flutter pub get`** inside each app so `.dart_tool/package_graph.json` exists (needed for **`flutter test`**):

```bash
cd apps/rider && flutter pub get && cd ../..
cd apps/driver && flutter pub get && cd ../..
```

**Rider localizations** (gen-l10n; driver uses manual `driver_strings.dart` for most copy):

```bash
cd apps/rider && flutter gen-l10n
```

> **`melos run gen:l10n`** may fail for the driver scope because the driver is not fully on gen-l10n ARBs—prefer the rider-only command above.

---

## Configuration & secrets

**Do not commit** production keys. Use **`--dart-define`**, **`.env`** (for IPA script / local tooling), or CI variables.

### Required at runtime (both apps, typical)

| Variable | Purpose |
|----------|---------|
| `SUPABASE_URL` | Project URL (default in code points at production ref; override for staging) |
| `SUPABASE_ANON_KEY` | Supabase anonymous key |
| `MAPBOX_ACCESS_TOKEN` | **Public** Mapbox token (`pk.…`) |

### Optional / extended

See **`scripts/ipa_build_env.template`** for Mapbox style URLs per theme, API base URL, and other keys the IPA merge script forwards.

**iOS Mapbox:** `MBXAccessToken` is wired from **`MAPBOX_ACCESS_TOKEN`** via `ios/Flutter/*.xcconfig` / `Secrets.xcconfig` when using the IPA script.

---

## Running the apps

Use **`--dart-define`** for secrets (example values—replace `YOUR_*`):

### Rider (`apps/rider/`)

```bash
cd apps/rider
flutter run \
  --dart-define=SUPABASE_URL=https://fvrprxguoternoxnyhoj.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=MAPBOX_ACCESS_TOKEN=YOUR_MAPBOX_PK_TOKEN
```

Or from root (Melos):

```bash
melos run rider:dev -- \
  --dart-define=SUPABASE_URL=https://fvrprxguoternoxnyhoj.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=MAPBOX_ACCESS_TOKEN=YOUR_MAPBOX_PK_TOKEN
```

### Driver (`apps/driver/`)

Same pattern; driver also needs a valid **Supabase session** after login (OTP/email flow).

```bash
cd apps/driver
flutter run \
  --dart-define=SUPABASE_URL=https://fvrprxguoternoxnyhoj.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=MAPBOX_ACCESS_TOKEN=YOUR_MAPBOX_PK_TOKEN
```

### VS Code / Cursor

Add a **`launch.json`** under **`apps/rider/`** or **`apps/driver/`** with the same `--dart-define` entries in `args` (see historical examples in git or duplicate from the commands above).

---

## iOS & Android notes

### iOS

- Open **`apps/rider/ios/Runner.xcworkspace`** or **`apps/driver/ios/Runner.xcworkspace`** — **not** the bare `.xcodeproj` (CocoaPods).
- **Driver `Podfile`** uses **`use_frameworks!`** and **`use_modular_headers!`** so plugins (e.g. **geolocator_apple**) resolve **`Flutter/Flutter.h`**.
- After dependency changes: `cd apps/<app>/ios && pod install`.

### Android

- Application IDs: **`com.heycaby.rider`**, **`com.heycaby.driver`** (see Gradle files).

### Store identity

Bundle / package IDs match **HeyCaby** branding. Treat store listings as **new** apps unless you have an explicit **transfer** plan. Metadata reference: **[docs/Rebranding.MD](docs/Rebranding.MD)**.

---

## Quality checks & tests

| Task | Command |
|------|---------|
| Analyze rider + driver (focused) | `flutter analyze --no-fatal-infos --no-fatal-warnings apps/rider/lib apps/driver/lib` |
| Melos analyze all | `melos run analyze` |
| Rider tests | `cd apps/rider && flutter test test/ --no-pub` |
| Driver tests | `cd apps/driver && flutter test test/ --no-pub` |

**Known flaky / outdated tests (see [AGENTS.md](AGENTS.md)):** default `widget_test.dart` files may fail (rider: old `MyApp` reference; driver: splash typewriter timer). Fix or skip intentionally when tightening CI.

---

## Release builds (iOS IPA)

From repo root, maintain **`.env`** (and optionally **`apps/rider/.env`**, **`apps/driver/.env`**) using **`scripts/ipa_build_env.template`** as a guide.

```bash
./scripts/build_ios_ipas.sh
```

- Merges env layers and writes **`Secrets.xcconfig`** for Mapbox plist substitution.
- Optional: `ENV_FILE=~/.heycaby/extra.env ./scripts/build_ios_ipas.sh`
- One app only: `./scripts/build_ios_ipas.sh --rider-only` or `--driver-only`

---

## Design system & localization

- **Tokens only** in UI: colors, type, spacing from **`heycaby_ui`** (`HeyCabyColorTokens`, typography providers, themes).
- **Themes:** `taxi-1` (rider default), `fresh` (driver default), `daylight`, `blossom`, `taxi-2`…`taxi-4`; legacy IDs are migrated when loading from storage.
- **Rider l10n:** `apps/rider/lib/l10n/*.arb` → `flutter gen-l10n`.
- **Driver:** mostly **`driver_strings.dart`** + supported locales in `MaterialApp` (en, nl, de, fr, es, ar, tr).
- **RTL:** Arabic supported for rider; use directional padding (`EdgeInsetsDirectional`).

---

## CI & automation

- **GitLab CI:** [`.gitlab-ci.yml`](.gitlab-ci.yml) — analyze, tests, debug APKs; optional macOS IPA jobs when runners and secrets are configured (`ENABLE_MACOS_IOS_JOBS`, Supabase/Mapbox variables).
- **Safe directory:** CI uses **`${CI_PROJECT_DIR}`** for `git` safe.directory.

---

## Documentation

| Doc | Contents |
|-----|----------|
| [docs/TECHNICAL_DOCUMENTATION.md](docs/TECHNICAL_DOCUMENTATION.md) | Architecture, features, setup, testing, governance, appendices |
| [docs/Rebranding.MD](docs/Rebranding.MD) | Brand, store IDs, voice, rebrand checklist |
| [heycaby-flutter-doc/](heycaby-flutter-doc/) | Deep specs: API, rider/driver screens, Mapbox, themes, agent prompt |
| [AGENTS.md](AGENTS.md) | Automation/agents: Melos version, cloud constraints, gotchas |

**Legal HTML sync to HeyCaby web:**

```bash
export HEYCABY_WEB_ROOT=/path/to/your/heycaby-web-clone
./scripts/sync-driver-legal-to-heycaby-web.sh
```

---

## Contributing & code rules

1. No hardcoded colors/fonts/spacing — **`heycaby_ui`** tokens only.  
2. No user-visible string literals in screens — **l10n** / driver string tables.  
3. **`EdgeInsetsDirectional`**, not `left`/`right`-only insets.  
4. Wrap screens with **`SafeArea`** where appropriate.  
5. Mapbox only through **service layers**, not raw SDK calls from arbitrary widgets.  
6. Secrets in **`flutter_secure_storage`**, not `SharedPreferences`.  
7. Prefer files **under ~300 lines**; split large screens.  
8. **Rider** and **Driver** remain **separate apps** (no merged binary).

Full contribution and review expectations: **docs/TECHNICAL_DOCUMENTATION.md** §6.

---

## Security

- Rotate keys if exposed; **never** commit `.env` with real secrets.  
- Supabase **RLS** enforces data access; mobile clients must not bypass policy with service keys.  
- Report vulnerabilities through your org’s preferred channel.

---

## Supabase (reference)

| | |
|--|--|
| **Project ref** | `fvrprxguoternoxnyhoj` |
| **Region** | `eu-west-1` |
| **Flutter role** | Client only — schema migrations and Edge Functions are coordinated separately |

---

*HeyCaby Flutter monorepo — README maintained for GitHub. For exhaustive technical detail, start with [docs/TECHNICAL_DOCUMENTATION.md](docs/TECHNICAL_DOCUMENTATION.md).*
