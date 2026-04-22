# How and what I rebranded

**Audience:** The next engineer or AI agent working in this repository.  
**Purpose:** A factual changelog of the **RydTap → HeyCaby** technical rebrand: what was renamed, how it was approached, what to verify, and what may still be outstanding.

**Cross-check the canonical brand guide:** All **marketing voice, logo rules, colors, App Store copy, SKUs, and checklist items** belong in **[Rebranding.MD](./Rebranding.MD)**. Use that document to validate *brand* decisions; use *this* document to understand *codebase and repo* changes.

**Related:** [TECHNICAL_DOCUMENTATION.md](./TECHNICAL_DOCUMENTATION.md) (architecture, CI), root [README.md](../README.md) (clone, setup, commands).

---

## 1. Executive summary

The product formerly known as **RydTap** / **RydTap Chauffeur** was rebranded to **HeyCaby** / **HeyCaby Driver** (April 2026). The work spanned:

- **Dart/Flutter:** New package names (`heycaby_*`), import paths, public type names (`HeyCaby…`), app entrypoints, and Riverpod/theme APIs aligned with the new brand.
- **Platforms:** New iOS bundle identifiers, Android `applicationId` values, Kotlin package directories, URL schemes for auth callbacks, and Mapbox/Supabase wiring where identifiers appeared.
- **Repo layout:** Renamed documentation trees, legal/static HTML folders, integration drop-ins for the external HeyCaby web app, and helper scripts (including env var `HEYCABY_WEB_ROOT`).
- **Backend-adjacent:** Supabase Edge Function(s) updated for redirect URLs using the **`heycaby://`** scheme (e.g. driver auth callback).
- **Persistence migration:** Theme preference in secure storage moved from a legacy key to **`heycaby_theme_id`**, with a one-time read of the old key so existing installs keep their theme (legacy key is stored obfuscated in code—see §5).

**GitHub org note:** The remote may still live under the **`rydtaptaxi`** organization (e.g. `github.com/rydtaptaxi/HeyCaby`). That is an **account/org name**, not the product name. The repository and apps are branded **HeyCaby**.

---

## 2. Naming map (old → new)

Use this table when searching history, old branches, or external docs.

| Area | Before (legacy) | After (HeyCaby) |
|------|------------------|-----------------|
| Consumer product | RydTap | HeyCaby |
| Driver product | RydTap Chauffeur | HeyCaby Driver |
| Rider Flutter package | `rydtap_rider` | `heycaby_rider` |
| Driver Flutter package | `rydtap_driver` | `heycaby_driver` |
| Shared packages | `rydtap_api`, `rydtap_models`, `rydtap_ui`, `rydtap_l10n`, `rydtap_map`, `rydtap_utils` | `heycaby_api`, `heycaby_models`, `heycaby_ui`, `heycaby_l10n`, `heycaby_map`, `heycaby_utils` |
| Melos workspace | (varied) | `name: heycaby` in `melos.yaml`; scopes `heycaby_rider`, `heycaby_driver` |
| Root Dart workspace pubspec | (varied) | `name: heycaby_workspace` |
| Spec / doc folder | `Rydtap-flutter-doc/`, files `rydtap_*.md` | `heycaby-flutter-doc/`, files `heycaby_*.md` |
| Chauffeur legal static site folder | `ryd-tap-tos/` | `heycaby-tos/` |
| Web integration mirror | `integrations/rydtap-web-public/` | `integrations/heycaby-web-public/` |
| Legal sync script | `scripts/sync-driver-legal-to-rydtap-web.sh` | `scripts/sync-driver-legal-to-heycaby-web.sh` (uses **`HEYCABY_WEB_ROOT`**) |
| Store screenshot tool | `tools/rydtap-rider-store-screenshots/` | `tools/heycaby-rider-store-screenshots/` |
| iOS bundle ID (rider) | (legacy RydTap-style id) | `nl.heycaby.rider` |
| iOS bundle ID (driver) | (legacy) | `nl.heycaby.driver` |
| Android applicationId (rider) | `com.rydtap.*` (legacy) | `com.heycaby.rider` |
| Android applicationId (driver) | `com.rydtap.*` (legacy) | `com.heycaby.driver` |
| Kotlin/Android namespace paths | `com.rydtap.…` | `com.heycaby.rider` / `com.heycaby.driver` under `android/app/src/main/kotlin/...` |
| Auth / deep link scheme | Legacy scheme (replaced) | **`heycaby://`** (e.g. `heycaby://driver/auth/callback`) |
| Theme secure storage key | Legacy `rydtap_theme_id` (see §5) | `heycaby_theme_id` |
| Public Dart APIs (examples) | `RydTap…`-style or old names | `HeyCabyThemeData`, `HeyCabyColorTokens`, `HeyCabySupabase`, app classes like `HeyCabyRiderApp` / `HeyCabyDriverApp` |

For **store listing names, support email, domain, and ASC identifiers**, use **[Rebranding.MD](./Rebranding.MD)** (quick reference tables near the end of that file).

---

## 3. How the rebrand was done (mechanical approach)

This is the order a future agent should *expect* when reading diffs or redoing a similar migration.

1. **Packages first**  
   Rename directories under `packages/` (`rydtap_*` → `heycaby_*`). Update each `pubspec.yaml` (`name:` and any `path:` dependencies). Replace `package:rydtap_*` imports with `package:heycaby_*` across apps and packages. Export libraries were renamed (e.g. `heycaby_ui.dart`).

2. **Apps**  
   Update `apps/rider/pubspec.yaml` and `apps/driver/pubspec.yaml` (`name:`, `description:`, path deps). Global replace of imports and types where the public API was prefixed with **HeyCaby**.

3. **iOS**  
   `Runner` bundle identifier, `Info.plist` display names / URL types if present, `project.pbxproj`, and **CocoaPods** (`Podfile`). Driver **`Podfile`** uses **`use_modular_headers!`** with **`use_frameworks!`** so plugins resolve **`Flutter/Flutter.h`**. Always open **`Runner.xcworkspace`**.

4. **Android**  
   `applicationId` and namespace in Gradle; move `MainActivity.kt` (and related) into **`com/heycaby/...`** package folders; update `AndroidManifest.xml` references.

5. **Supabase / Edge**  
   Update redirect URLs in Edge Functions (example: `supabase/functions/apple-review-auth/index.ts` → `heycaby://driver/auth/callback`). **Supabase Dashboard:** Auth redirect allowlist must include the same paths you ship.

6. **Theme storage**  
   New key `heycaby_theme_id`; legacy key read once via obfuscated `String.fromCharCodes` in `heycaby_ui` theme notifier (avoid scattering the literal legacy string in grep-heavy code). **`DriverThemeNotifier`** avoids applying the rider default when storage is empty.

7. **Docs and scripts**  
   Rename folders and markdown cross-links; replace `RYDTAP-FLUTTER`-style examples with neutral “repo root” or `HeyCaby` where appropriate. IPA / env templates updated for new naming where keys or comments referenced the old brand.

8. **README**  
   Root [README.md](../README.md) rewritten for GitHub: setup, `dart-define`, Melos 2.9.0 note, iOS/Android table, links to **Rebranding.MD** and **TECHNICAL_DOCUMENTATION.md**.

9. **Git**  
   Prefer **`git mv`** for large renames to preserve history. A single commit accidentally bundled **README + several folder renames** when other paths were already staged—when committing, confirm **`git status`** so scope matches intent.

---

## 4. Legacy theme key (intentional obscurity)

In `packages/heycaby_ui/lib/src/theme/theme_provider.dart`:

- **Current key:** `heycaby_theme_id`
- **Legacy key:** The old `rydtap_theme_*` string is **not** stored as a single literal in source; it is built with **`String.fromCharCodes(const <int>[...])`** so existing users’ saved theme still loads and is then written under the new key.

**Implication for agents:** Grepping for `rydtap_theme` may return **no hits** in Dart even though migration logic exists. Read `theme_provider.dart` directly.

---

## 5. Git / GitHub state (verify locally)

Repository history was **not** rewritten: commits are continuous; only names and paths changed.

**What was pushed early:** At least one push included the **new root README** and **folder renames** (spec doc tree, `heycaby-tos`, `integrations/heycaby-web-public`, screenshot tool, sync script rename).  

**What may still need pushing:** A large set of **app and package renames** (often **hundreds of files**) can remain as **local commits or uncommitted changes** until `git push origin main` (or your default branch) completes.

**Before assuming remote parity, run:**

```bash
git status
git log origin/main..HEAD --oneline
git diff --stat origin/main..HEAD
```

If `origin/main` still shows `rydtap_*` package directories but your laptop shows only `heycaby_*`, the **full technical rebrand is not yet on GitHub**—push or open a PR.

---

## 6. What is left / checklist for the next agent

Use this as a punch list; strike items when verified.

| Item | Action |
|------|--------|
| **Remote vs local** | Confirm all `heycaby_*` packages and app renames are **pushed**; CI should see consistent `pubspec` paths. |
| **Supabase Auth URLs** | Dashboard redirect URLs include **`heycaby://`** paths used in app and Edge Functions. |
| **App Store / Play** | Bundle IDs and package names match **[Rebranding.MD](./Rebranding.MD)**; new listings vs transfer is a **business** decision. |
| **`.cursor` / skills** | May still mention old product names in rules or skills; update if they confuse agents (optional). |
| **Generated iOS scripts** | Files like `ios/Flutter/flutter_export_environment.sh` may contain **absolute paths** from a developer machine (`RYDTAP-FLUTTER`); they are **generated**—do not hand-edit; run `flutter pub get` / build locally to regenerate. |
| **Widget tests** | Default template tests may reference old root widget class names; see [AGENTS.md](../AGENTS.md) known failures. |
| **Svelte PWAs** | If present in the repo as experiments, align or remove per product direction (not part of core Flutter monorepo). |
| **Grep hygiene** | Search `rydtap`, `RydTap`, `RYDTAP` (case variants) after merges; allowlisted exceptions: GitHub org **`rydtaptaxi`**, historical **git** messages, and intentional legacy **char-code** theme key. |

---

## 7. Quick verification commands

```bash
# Package directories (expect heycaby_* only after migration)
ls packages/

# Obvious legacy strings in tracked source (adjust excludes as needed)
rg -i 'rydtap|ryd-tap' --glob '!**/.dart_tool/**' --glob '!**/build/**'

# Melos package names
grep -E '^name:' apps/*/pubspec.yaml packages/*/pubspec.yaml
```

---

## 8. Document index

| Document | Role |
|----------|------|
| **[Rebranding.MD](./Rebranding.MD)** | Brand identity, themes, voice, **store** metadata, legal URLs, checklist—**source of truth for marketing and product naming**. |
| **This file** | **Engineering handoff:** repo renames, platform IDs, migration behavior, git caveats. |
| [TECHNICAL_DOCUMENTATION.md](./TECHNICAL_DOCUMENTATION.md) | Stack, features, CI, contribution rules. |
| [README.md](../README.md) | Clone URL, bootstrap, run commands, troubleshooting pointers. |

---

*Last updated: April 2026 — maintained so future agents can orient without re-deriving the full rebrand from git history alone.*
