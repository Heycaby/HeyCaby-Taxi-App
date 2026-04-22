# HeyCaby Flutter Architecture Spec v1.1
## PWA → Flutter: Same Supabase Backend, Native Flutter UI
### Complete A–Z Guide for Rider App and Driver App

> **Status: Implementation Baseline — Frozen**
> This document is the single source of truth for migrating HeyCaby from a Next.js PWA to two native Flutter apps. The Supabase backend, all API contracts, business rules, and database schema remain **100% unchanged**. Only the frontend UI changes — rebuilt natively in Flutter.

> **v1.1 Update:** Live Supabase audit completed against HeyCaby production (`fvrprxguoternoxnyhoj`, eu-west-1). Spec updated to reflect actual schema — 31 tables verified, push notification gap documented with migration SQL, extra tables (ride_shares, notifications, app_analytics) incorporated, all 6 edge functions catalogued. See Part 3 (Supabase Schema) and Part 8 (Push Notifications) for the concrete changes required.

> **Developer Rule:** No silent deviations. If something needs to change, document it first. The backend is not touched except for the two minimal mobile push adaptations noted in Part 8.

---

## ARCHITECT'S NOTE — Why Flutter Over React Native

After evaluating both options, Flutter is the stronger choice for HeyCaby specifically because:

- **Single codebase, two platforms** — Dart compiles to native ARM; no JS bridge overhead.
- **Mapbox Flutter SDK** (`mapbox_maps_flutter`) is production-grade and actively maintained.
- **Supabase has a first-class Flutter SDK** (`supabase_flutter`) with built-in Realtime, Auth, and storage.
- **Background location** via `background_locator_2` or `geolocator` with `flutter_background_service` is battle-tested for taxi/delivery apps.
- **RTL (Arabic/Hebrew) support** is native in Flutter — `Directionality` widget + `intl` + `flutter_localizations` handle bidirectional text automatically.
- **Auto-translation** via device locale detection is straightforward using Flutter's `AppLocalizations` + ARB files.
- **Dart is strongly typed** — API contracts map cleanly to model classes with `json_serializable`.

This spec treats Flutter as the production-grade choice, not a compromise.

---

## TABLE OF CONTENTS

1. [Principles](#part-0--principles)
2. [Project Structure](#part-1--project-structure)
3. [i18n & Auto-Translation](#part-2--i18n--auto-translation-arabic-dutch-english)
4. [Supabase Schema Audit — Live Verified](#part-3--supabase-schema-audit--live-verified)
5. [Supabase & API Layer](#part-4--supabase--api-layer)
6. [Rider App — Complete Guide](#part-5--rider-app)
7. [Driver App — Complete Guide](#part-6--driver-app)
8. [Mapbox Integration](#part-7--mapbox-integration)
9. [State Management](#part-8--state-management-riverpod)
10. [Push Notifications](#part-9--push-notifications)
11. [Rider State Machine](#part-10--rider-booking-state-machine-locked)
12. [Driver State Machine](#part-11--driver-state-machine-locked)
13. [Edge Cases & Failure Handling](#part-12--edge-cases--failure-handling)
14. [Shared Concerns](#part-13--shared-concerns)
15. [Migration Order](#part-14--migration-order-phase-by-phase)
16. [Non-Negotiable Infra Rules](#part-15--non-negotiable-infra-rules)
17. [Release Gates](#part-16--release-gates)

---

## PART 0 — PRINCIPLES

| Principle | Meaning |
|-----------|---------|
| **Backend unchanged** | Supabase tables, RLS policies, Edge Functions, and Next.js API routes stay exactly as they are. No schema changes. |
| **Same API contracts** | Every endpoint path, method, body, and response shape is preserved. Flutter calls the same URLs as the PWA. |
| **Two separate apps** | One Flutter app for **Rider** (HeyCaby) and one for **Driver** (HeyCaby Driver). Shared packages via local Dart packages. |
| **Native UI only** | All screens, maps, gestures, and navigation are built natively in Flutter. No WebView wrappers. |
| **Mapbox everywhere** | `mapbox_maps_flutter` for map rendering; Mapbox Search API for geocoding; Mapbox Directions API for routing. |
| **i18n-first** | Every string is localised from day one. Auto-detect device locale. Arabic triggers full RTL layout. |
| **Provider abstraction** | Map, geocoding, and routing calls are wrapped in service classes. Screens never call SDKs directly. |
| **Riverpod for state** | `flutter_riverpod` for all app state. Mirrors the PWA Zustand store logic. |

---

## PART 1 — PROJECT STRUCTURE

### 1.1 Monorepo Layout

```
heycaby-flutter/
  apps/
    rider/                  ← Flutter app: HeyCaby (consumer)
    driver/                 ← Flutter app: HeyCaby Driver (driver)
  packages/
    heycaby_api/             ← Shared: HTTP client, all API functions, types
    heycaby_models/          ← Shared: Dart model classes (Ride, Driver, Rider, Bid, etc.)
    heycaby_ui/              ← Shared: Theme tokens, reusable widgets, design system
    heycaby_l10n/            ← Shared: All ARB translation files, generated localizations
    heycaby_map/             ← Shared: MapService, GeocodingService, RoutingService wrappers
    heycaby_utils/           ← Shared: Validators, formatters, error handling, analytics
  backend/                  ← Existing Next.js app (UNCHANGED — do not touch)
```

### 1.2 Flutter Version

Use **Flutter 3.19+** (stable channel). Dart SDK **3.3+**. Lock versions in `pubspec.yaml` per app.

### 1.3 Rider App — `pubspec.yaml` Dependencies

```yaml
name: heycaby_rider
description: HeyCaby — Book a ride

environment:
  sdk: '>=3.3.0 <4.0.0'
  flutter: '>=3.19.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # State management
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0

  # Supabase
  supabase_flutter: ^2.5.0

  # Maps (Mapbox — lock this version)
  mapbox_maps_flutter: ^2.3.0

  # HTTP
  dio: ^5.4.0
  dio_cache_interceptor: ^3.5.0

  # Storage
  flutter_secure_storage: ^9.0.0
  shared_preferences: ^2.2.0

  # Location
  geolocator: ^11.0.0
  permission_handler: ^11.3.0

  # Push notifications
  firebase_core: ^3.0.0
  firebase_messaging: ^15.0.0
  flutter_local_notifications: ^17.0.0

  # Navigation
  go_router: ^13.2.0

  # Forms
  reactive_forms: ^17.0.0

  # UI utilities
  cached_network_image: ^3.3.0
  shimmer: ^3.0.0
  lottie: ^3.1.0

  # i18n
  intl: ^0.19.0

  # Local packages
  heycaby_api:
    path: ../../packages/heycaby_api
  heycaby_models:
    path: ../../packages/heycaby_models
  heycaby_ui:
    path: ../../packages/heycaby_ui
  heycaby_l10n:
    path: ../../packages/heycaby_l10n
  heycaby_map:
    path: ../../packages/heycaby_map
  heycaby_utils:
    path: ../../packages/heycaby_utils

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.0
  riverpod_generator: ^2.4.0
  json_serializable: ^6.7.0
  flutter_lints: ^4.0.0
```

### 1.4 Driver App — Additional Dependencies

Same as Rider, plus:

```yaml
  # Background location (driver only)
  flutter_background_service: ^5.0.0
  workmanager: ^0.5.0

  # Camera / file upload
  image_picker: ^1.1.0
  file_picker: ^8.0.0

  # External navigation deep links
  url_launcher: ^6.3.0
```

---

## PART 2 — i18n & Auto-Translation (Arabic, Dutch, English)

This is a first-class concern. Every string in both apps is localised. Auto-detection of device locale means Arabic users get Arabic + RTL automatically, Dutch users get Dutch, everyone else defaults to English.

### 2.1 Supported Locales

| Code | Language | Direction |
|------|----------|-----------|
| `en` | English | LTR |
| `nl` | Dutch | LTR |
| `ar` | Arabic | **RTL** |

Add more locales by adding ARB files — no code changes required.

### 2.2 ARB File Structure

All ARB files live in `packages/heycaby_l10n/lib/l10n/`.

**`app_en.arb`** (English — source of truth):
```json
{
  "@@locale": "en",
  "appName": "HeyCaby",
  "bookRide": "Book a ride",
  "whereAreYouGoing": "Where are you going?",
  "pickup": "Pickup",
  "destination": "Destination",
  "findMyDriver": "Find my driver",
  "searching": "Searching for a driver...",
  "driverAssigned": "Driver on the way",
  "driverArrived": "Your driver has arrived",
  "tripInProgress": "Trip in progress",
  "tripComplete": "Trip complete",
  "cancel": "Cancel",
  "confirm": "Confirm",
  "rateYourDriver": "Rate your driver",
  "fareEstimate": "Estimated fare",
  "scheduledFor": "Scheduled for {date}",
  "@scheduledFor": {
    "placeholders": {
      "date": { "type": "String" }
    }
  },
  "noDriversNearby": "No drivers nearby",
  "connectionProblem": "Connection problem. Please try again.",
  "locationPermissionRequired": "Location access is needed to set pickup and find nearby drivers.",
  "enableLocation": "Enable Location",
  "enterAddressManually": "Enter address manually",
  "home": "Home",
  "rides": "Rides",
  "account": "Account",
  "myRides": "My rides",
  "favoriteDrivers": "Favourite drivers",
  "paymentMethod": "Payment method",
  "cash": "Cash",
  "card": "Card",
  "instantRide": "Instant",
  "scheduledRide": "Schedule",
  "marketplace": "Marketplace",
  "favoritesOnly": "Favourites only",
  "offerFare": "Offer your fare",
  "bids": "Bids",
  "acceptBid": "Accept",
  "notifyMe": "Notify me when available",
  "rideHistory": "Ride history",
  "reportDriver": "Report driver",
  "support": "Support",
  "settings": "Settings",
  "language": "Language",
  "theme": "Theme",
  "homeAddress": "Home address",
  "savedAddresses": "Saved addresses",
  "logout": "Log out",
  "distance": "{km} km",
  "@distance": {
    "placeholders": {
      "km": { "type": "String" }
    }
  },
  "duration": "{min} min",
  "@duration": {
    "placeholders": {
      "min": { "type": "String" }
    }
  }
}
```

**`app_nl.arb`** (Dutch):
```json
{
  "@@locale": "nl",
  "appName": "HeyCaby",
  "bookRide": "Rit boeken",
  "whereAreYouGoing": "Waar ga je heen?",
  "pickup": "Ophaallocatie",
  "destination": "Bestemming",
  "findMyDriver": "Zoek mijn chauffeur",
  "searching": "Chauffeur zoeken...",
  "driverAssigned": "Chauffeur onderweg",
  "driverArrived": "Je chauffeur is er",
  "tripInProgress": "Rit bezig",
  "tripComplete": "Rit voltooid",
  "cancel": "Annuleren",
  "confirm": "Bevestigen",
  "rateYourDriver": "Beoordeel je chauffeur",
  "fareEstimate": "Geschatte prijs",
  "noDriversNearby": "Geen chauffeurs in de buurt",
  "connectionProblem": "Verbindingsprobleem. Probeer opnieuw.",
  "locationPermissionRequired": "Locatietoegang is nodig om ophaallocatie in te stellen en chauffeurs te vinden.",
  "enableLocation": "Locatie inschakelen",
  "enterAddressManually": "Adres handmatig invoeren",
  "home": "Home",
  "rides": "Ritten",
  "account": "Account"
}
```

**`app_ar.arb`** (Arabic — RTL):
```json
{
  "@@locale": "ar",
  "appName": "ريدتاب",
  "bookRide": "احجز رحلة",
  "whereAreYouGoing": "إلى أين تريد الذهاب؟",
  "pickup": "نقطة الانطلاق",
  "destination": "الوجهة",
  "findMyDriver": "ابحث عن سائقي",
  "searching": "جارٍ البحث عن سائق...",
  "driverAssigned": "السائق في الطريق",
  "driverArrived": "وصل سائقك",
  "tripInProgress": "الرحلة جارية",
  "tripComplete": "اكتملت الرحلة",
  "cancel": "إلغاء",
  "confirm": "تأكيد",
  "rateYourDriver": "قيّم سائقك",
  "fareEstimate": "الأجرة التقديرية",
  "noDriversNearby": "لا يوجد سائقون قريبون",
  "connectionProblem": "مشكلة في الاتصال. حاول مجدداً.",
  "locationPermissionRequired": "مطلوب الوصول إلى الموقع لتحديد نقطة الانطلاق وإيجاد السائقين القريبين.",
  "enableLocation": "تفعيل الموقع",
  "enterAddressManually": "إدخال العنوان يدوياً",
  "home": "الرئيسية",
  "rides": "الرحلات",
  "account": "الحساب"
}
```

### 2.3 l10n Setup in `pubspec.yaml`

In **each app's** `pubspec.yaml`:
```yaml
flutter:
  generate: true

flutter_gen:
  # not needed for l10n — use generate: true
```

Create `l10n.yaml` in each app root:
```yaml
arb-dir: ../../packages/heycaby_l10n/lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
preferred-supported-locales: [en, nl, ar]
nullable-getter: false
```

Run `flutter gen-l10n` to generate `AppLocalizations`.

### 2.4 Auto-Detection in `main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class HeyCabyApp extends StatelessWidget {
  const HeyCabyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      // Auto-detect device locale — no user action needed
      // If device is Arabic, app shows Arabic + RTL automatically
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // DO NOT set locale manually — let Flutter detect from device
      // Flutter will automatically pick the best supported match
      routerConfig: appRouter,
      title: 'HeyCaby',
    );
  }
}
```

### 2.5 RTL Auto-Layout

When Arabic is detected, Flutter automatically applies `Directionality.rtl` to the entire widget tree. This means:

- `Row` children reverse order automatically
- `TextAlign.start` becomes right-aligned
- `EdgeInsets.only(left: ...)` still works correctly via `EdgeInsetsDirectional`
- Navigation drawers open from the right

**Rule:** Always use `EdgeInsetsDirectional` instead of `EdgeInsets.only` for directional padding. Always use `CrossAxisAlignment.start` and `TextAlign.start` — never hard-code "left" or "right".

```dart
// ✅ CORRECT — RTL safe
Padding(
  padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
  child: Text(l10n.pickup, textAlign: TextAlign.start),
)

// ❌ WRONG — breaks in Arabic
Padding(
  padding: const EdgeInsets.only(left: 16, right: 8),
  child: Text(l10n.pickup, textAlign: TextAlign.left),
)
```

### 2.6 Using Translations in Code

```dart
// In any widget — get the current translations
final l10n = AppLocalizations.of(context)!;
// or with a Riverpod provider:
// final l10n = ref.watch(l10nProvider);

Text(l10n.findMyDriver)
Text(l10n.scheduledFor(formattedDate))
Text(l10n.distance('12.4'))
```

### 2.7 Adding a New Language

1. Create `packages/heycaby_l10n/lib/l10n/app_XX.arb` (where XX is the language code)
2. Add translations for all keys from `app_en.arb`
3. Run `flutter gen-l10n` in each app
4. Add the locale to `pubspec.yaml` supported locales — done

No code changes in screens, widgets, or business logic.

---

## PART 3 — SUPABASE SCHEMA AUDIT — LIVE VERIFIED

> Audited against **HeyCaby production** Supabase (`fvrprxguoternoxnyhoj`, eu-west-1, PostgreSQL 17.6). 31 tables inspected. Status: 28 fully matched, 2 need minor adaptation, 1 mobile-specific addition required.

### 3.1 Core Ride Tables — Matched

| Table | Flutter usage | Key columns confirmed |
|-------|---------------|-----------------------|
| `ride_requests` | Primary Realtime subscription target for both apps | `status`, `booking_mode` (instant/scheduled/marketplace), `assignment_mode` (auction/first_accept), `rider_token`, `rider_identity_id`, `favorites_only`, `scheduled_pickup_at`, `payment_methods[]`, `filter_electric`, `filter_pet_friendly`, `filter_wheelchair`, `pickup_coords` (PostGIS geography), `destination_coords` |
| `ride_bids` | Driver marketplace bidding; Realtime subscription | `bid_amount`, `eta_minutes`, `message` (max 200 chars), `status` (pending/accepted/rejected/withdrawn/expired), `driver_snapshot` (JSONB) |
| `rides` | Earnings screen, receipt linking | `final_fare`, `started_at`, `completed_at`, `duration_min`, `ride_request_id` |
| `ride_ratings` | Dual-rating system (rider→driver, driver→rider) | Blind reveal pattern via `ratings_revealed_at`; `rider_comment` max 100 chars |
| `receipts` | Driver complete screen; `generate-receipt` edge function | `ride_request_id`, `driver_id`, `amount`, `distance_km`, `delivery_method` |

### 3.2 Driver Tables — Matched

| Table | Flutter usage | Notes |
|-------|---------------|-------|
| `drivers` | Auth target; onboarding writes; status toggle | 100+ columns. All Dutch compliance fields present: `chauffeurspas_*`, `rijbewijs_*`, `vog_*`, `taxidiploma_*`, `kvk_*`, `rdw_*`. Has `push_token TEXT` — **use this for FCM token** (see Part 9). Enums: `driver_status` (available/on_ride/offline/on_break), `profile_status` (incomplete/pending_review/verified/suspended), `compliance_status`. Payment methods typed as `payment_method[]` enum (cash/card/tikkie/invoice). |
| `driver_locations` | Background location upload; PK is `user_id` (upsert) | `latitude`, `longitude`, `heading`, `speed_kmh`, `accuracy`, `current_zone_id`, `current_city_id`. Updated every ~5s when online. |
| `driver_onboarding_steps` | Multi-step onboarding screen reads/writes | Tracks each step: `step_personal_done`, `step_business_done`, `step_vehicle_done`, `step_compliance_done`, `step_rates_done`, `step_legal_done`. Sub-steps for each Dutch document type. |
| `driver_verifications` | Document upload + verify screen | Types: `chauffeurspas`, `rijbewijs`, `vog`, `taxidiploma`, `kvk`, `vehicle_rdw`, `vehicle_plate`, `vehicle_insurance`, `vehicle_apk`, `operator_license`. Verified by: `ilt_api`, `rdw_api`, `kvk_api`, `onfido`, `admin`, `system`. |
| `driver_intents` | Radar screen — driver heading intent | `intent_type` (home_zone/target_zone/stay/any), `target_zone_id`, expires after 4h. PK is `driver_id` (single active intent per driver). |
| `driver_radar_sessions` | Radar scan lifecycle | `scan_zones[]`, `auto_accept_enabled`, `auto_accept_min_score`, `chain_depth`. `scan-radar` edge function populates `radar_matches`. |
| `driver_trip_history` | Earnings/stats screens | Zone + city level; `pickup_zone_id`, `destination_zone_id`, `distance_km`. |
| `radar_matches` | Radar results; driver action tracking | `match_score`, `is_feasible`, `driver_action` (accepted/dismissed/ignored), `auto_accepted`. |

### 3.3 Rider Identity Tables — Matched

| Table | Flutter usage | Notes |
|-------|---------------|-------|
| `rider_identities` | **Canonical identity source for Flutter** | `email` (unique), `booking_name`, `language_pref`, `theme_pref`, `preferred_payment_methods[]`, `preferred_vehicle_type`, `filter_electric/pet_friendly/wheelchair`. Use this as the single source of truth — not `rider_profiles`. |
| `rider_sessions` | `session_token` = the `rider_token` used in all API calls | Linked to `rider_identities` via FK. Flutter stores `session_token` in `flutter_secure_storage` as `rider_token`. |
| `rider_otp_challenges` | Email OTP verification flow | `email`, `code`, `expires_at`. `VerificationScreen` calls `POST /api/rider/identity/verify-email`. |
| `saved_addresses` | Saved home address shortcut on HomeScreen | **Check constraint: `type = 'home'` only.** If work addresses needed later, run: `ALTER TABLE saved_addresses DROP CONSTRAINT saved_addresses_type_check; ALTER TABLE saved_addresses ADD CONSTRAINT saved_addresses_type_check CHECK (type IN ('home', 'work'));` |
| `recent_destinations` | Address search screen — recent suggestions | 120h TTL via `expires_at`. Show max 4, newest first. Auto-cleaned by backend. |
| `rider_profiles` | Supplemental zone/analytics record | Contains `session_token`, `home_zone_id`, `preferred_payment`. **In Flutter, use `rider_identities` as canonical identity.** Do not use `rider_profiles` as auth source. |

### 3.4 Favorites, Blocks & Reports — Matched

| Table | Flutter usage |
|-------|---------------|
| `rider_favorite_drivers` | `FavoriteDriversScreen` — GET/POST. `rider_identity_id → driver_id`. |
| `driver_blocks` | Blocked drivers list; `PATCH /api/rider/blocked` sets `is_active = false`. |
| `rider_driver_reports` | `ReportRideScreen` — POST. `block_driver = true` also creates a `driver_blocks` row automatically via backend trigger. |
| `rider_driver_report_overrides` | Rider can re-allow a reported driver. Backend-handled; no Flutter screen needed. |
| `favorite_ride_requests` | When `favorites_only = true` on a ride_request, backend populates this table to track which favourite drivers were notified and their responses (pending/accepted/ignored/expired/cancelled). |

### 3.5 Geo & Zone Tables — Matched

| Table | Flutter usage | Notes |
|-------|---------------|-------|
| `bubble_zones` | Zone label on HomeScreen map pin; `GET /api/zone-at-point` | 123 zones loaded. Has PostGIS `geom` column and `boundary` JSONB. `GET /api/drivers-nearby` queries this. |
| `zone_neighbors` | 756 neighbor pairs — backend matching only | Flutter never queries this directly. |
| `cities` | 4 cities active | Use `bbox` JSONB to restrict Mapbox Search to your service area. Pass as bbox to `GeocodingService.search()`. |

### 3.6 Community & Support — Matched

| Table | Flutter usage |
|-------|---------------|
| `community_posts` | `CommunityScreen` — channels: general, pricing, heads_up, tax, car, sub_needed, announcements. |
| `community_replies` | Threaded replies. Soft-delete via `is_deleted`. |
| `messages` | In-app rider ↔ driver chat per `ride_request_id`. Realtime subscription in `ChatScreen`. |
| `tickets` | AI-assisted support tickets. Status flow: open → in_progress → awaiting_user → auto_resolved → escalated → resolved → closed. Flutter creates via `driver-agent` edge function. |
| `ride_reports` | Anonymous/contact form reports — backend only. |
| `notifications` | In-app notification log. **Flutter: subscribe via Realtime** for notification badge in both apps. Columns: `user_type`, `user_id`, `category`, `title`, `body`, `priority` (critical/high/medium/low/silent), `channel` (push/in_app/both/silent), `read_at`. |

### 3.7 Extra Tables — Flutter Implications

These tables exist in your database but were not in the original spec. All are useful in Flutter.

| Table | Flutter action |
|-------|----------------|
| `ride_shares` | After ride creation, fetch `share_token` via `GET /api/ride/[id]`. Surface "Share ride" button on `ActiveRideScreen`. Build URL as `https://heycaby.nl/track/{share_token}` and open via `url_launcher`. |
| `app_analytics` | 483 events already logged from PWA. Call `track-analytics` edge function (no JWT required) for `app_open`, `ride_started`, `driver_signup`. Add a new event type `flutter_install` to distinguish mobile traffic. |
| `waitlist` | Pre-launch only — ignore in Flutter app. |
| `page_views` | Web analytics only — ignore in Flutter. |
| `profiles` | Driver app: Supabase Auth creates a row here automatically. Read driver data from `drivers` table, not `profiles`. |
| `users` | Legacy user type table — ignore in Flutter. |
| `security_events` | Backend security audit — Flutter never reads or writes directly. |
| `agent_logs` | AI agent audit trail — backend only. |

### 3.8 Edge Functions — All Active

| Function | JWT required | Flutter usage |
|----------|-------------|---------------|
| `generate-receipt` | Yes | Called by `POST /api/driver/receipt`. `DriverCompleteScreen` triggers after completing a ride. Pass Supabase Bearer token in Authorization header. |
| `driver-agent` | No | AI support agent. Call from `SupportScreen` for driver help. No auth header needed — identify driver by payload. |
| `send-push` | Yes | Push delivery. **Needs FCM branch for mobile tokens** (see Part 9). Currently Web Push only. |
| `verify-chauffeurspas` | Yes | ILT API verification. Called during driver onboarding compliance step. |
| `scan-radar` | Yes | Radar matching engine. Driver `RadarScreen` triggers this; Flutter subscribes to `radar_matches` via Realtime. |
| `track-analytics` | No | Call on `app_open`, `ride_started`, `driver_signup`. Safe to fire without auth — no PII. |

### 3.9 Realtime Subscriptions — Confirmed Tables

| Subscription | Table | Filter | Used by |
|-------------|-------|--------|---------|
| Ride status updates | `ride_requests` | `id = ride_id` | Rider `SearchingScreen`, `ActiveRideScreen`, `InProgressScreen` |
| Notify-me conversion | `driver_notify_queue` | `id = notify_queue_id` | Rider `NotifyMe` state |
| Incoming rides | `ride_requests` | status changes | Driver `HomeScreen`, `MarketScreen` |
| Bids on a request | `ride_bids` | `ride_request_id = id` | Rider `BidsScreen` (marketplace) |
| Radar matches | `radar_matches` | `driver_id = driver_id` | Driver `RadarScreen` |
| Driver intents | `driver_intents` | `driver_id = driver_id` | Driver `RadarScreen` |
| Community posts | `community_posts` | none (all) | Driver `CommunityScreen` |
| Chat messages | `messages` | `ride_request_id = id` | `ChatScreen` both apps |
| In-app notifications | `notifications` | `user_id = current_user_id` | Notification badge, both apps |

---

## PART 4 — SUPABASE & API LAYER

### 4.1 Architecture Rule

The Flutter apps connect to the **same Supabase project** the PWA uses. Zero backend changes.

- **Rider app** — HTTP only for business logic. Uses Supabase Realtime client for live subscriptions (ride status, notify-me queue).
- **Driver app** — Supabase Auth for login. Supabase Realtime for incoming rides. HTTP for all lifecycle actions.

### 4.2 Supabase Client Setup

In `packages/heycaby_api/lib/src/supabase_client.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class HeyCabySupabase {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: const String.fromEnvironment('SUPABASE_URL'),
      anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
```

Initialize in `main.dart` before `runApp()`:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HeyCabySupabase.initialize();
  runApp(
    const ProviderScope(
      child: HeyCabyApp(),
    ),
  );
}
```

### 4.3 HTTP API Client (Dio)

In `packages/heycaby_api/lib/src/api_client.dart`:

```dart
import 'package:dio/dio.dart';

class ApiClient {
  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://heycaby.nl',
  );

  late final Dio _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(LogInterceptor(responseBody: false));
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) =>
      _dio.get<T>(path, queryParameters: queryParameters, cancelToken: cancelToken);

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
    String? idempotencyKey,
  }) =>
      _dio.post<T>(
        path,
        data: data,
        cancelToken: cancelToken,
        options: idempotencyKey != null
            ? Options(headers: {'x-idempotency-key': idempotencyKey})
            : null,
      );

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
  }) =>
      _dio.patch<T>(path, data: data, cancelToken: cancelToken);
}

// Singleton — use as a Riverpod provider
final apiClientProvider = Provider<ApiClient>((_) => ApiClient());
```

### 4.4 Secure Token Storage

In `packages/heycaby_api/lib/src/secure_storage.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Rider identity
  static Future<void> saveRiderIdentity({
    required String token,
    required String identityId,
    String? email,
  }) async {
    await Future.wait([
      _storage.write(key: 'rider_token', value: token),
      _storage.write(key: 'rider_identity_id', value: identityId),
      if (email != null) _storage.write(key: 'rider_email', value: email),
    ]);
  }

  static Future<Map<String, String?>> getRiderIdentity() async {
    final results = await Future.wait([
      _storage.read(key: 'rider_token'),
      _storage.read(key: 'rider_identity_id'),
      _storage.read(key: 'rider_email'),
    ]);
    return {
      'rider_token': results[0],
      'rider_identity_id': results[1],
      'rider_email': results[2],
    };
  }

  static Future<void> clearRiderIdentity() async {
    await Future.wait([
      _storage.delete(key: 'rider_token'),
      _storage.delete(key: 'rider_identity_id'),
      _storage.delete(key: 'rider_email'),
    ]);
  }

  // Driver session is managed by Supabase client directly
}
```

### 4.5 Rider API Functions

Full list matching the spec. In `packages/heycaby_api/lib/src/rider_api.dart`:

```dart
class RiderApi {
  RiderApi(this._client);
  final ApiClient _client;

  // Auth
  Future<Map<String, dynamic>> getMe({
    required String riderToken,
    required String riderIdentityId,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/api/rider/me',
      queryParameters: {
        'rider_token': riderToken,
        'rider_identity_id': riderIdentityId,
      },
    );
    return res.data!;
  }

  Future<Map<String, dynamic>> createIdentity({required String email}) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/api/rider/identity',
      data: {'email': email},
    );
    return res.data!;
  }

  Future<void> verifyEmail({required String email, required String code}) async {
    await _client.post('/api/rider/identity/verify-email', data: {'email': email, 'code': code});
  }

  // Profile
  Future<Map<String, dynamic>> getProfile({required String riderIdentityId}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/api/rider/profile',
      queryParameters: {'rider_identity_id': riderIdentityId},
    );
    return res.data!;
  }

  Future<void> updateProfile({
    required String riderIdentityId,
    required Map<String, dynamic> data,
  }) async {
    await _client.patch(
      '/api/rider/profile',
      data: {...data, 'rider_identity_id': riderIdentityId},
    );
  }

  // Rides
  Future<List<dynamic>> getRides({required String riderToken}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/api/rider/rides',
      queryParameters: {'rider_token': riderToken},
    );
    return res.data!['rides'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getRideById({required String id, required String riderToken}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/api/rider/rides/$id',
      queryParameters: {'rider_token': riderToken},
    );
    return res.data!;
  }

  // Ride creation (called ONLY when user taps "Find my driver")
  Future<Map<String, dynamic>> createRide({
    required Map<String, dynamic> payload,
    required String idempotencyKey,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/api/ride/create',
      data: payload,
      idempotencyKey: idempotencyKey,
    );
    return res.data!;
  }

  Future<void> cancelRide({required String rideId, required String cancelledBy}) async {
    await _client.post('/api/ride/cancel', data: {
      'ride_id': rideId,
      'cancelled_by': cancelledBy,
    });
  }

  Future<Map<String, dynamic>> getFareEstimate({
    required double pickupLat, required double pickupLng,
    required double destLat, required double destLng,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/api/ride/fare-estimate',
      queryParameters: {
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'dest_lat': destLat,
        'dest_lng': destLng,
      },
    );
    return res.data!;
  }

  Future<void> rateRide({required Map<String, dynamic> payload}) async {
    await _client.post('/api/ride/rate', data: payload);
  }

  Future<Map<String, dynamic>> notifyMe({required Map<String, dynamic> payload}) async {
    final res = await _client.post<Map<String, dynamic>>('/api/ride/notify-me', data: payload);
    return res.data!;
  }

  // Auction / Marketplace
  Future<Map<String, dynamic>> postAuction({required Map<String, dynamic> payload}) async {
    final res = await _client.post<Map<String, dynamic>>('/api/auction/post', data: payload);
    return res.data!;
  }

  Future<Map<String, dynamic>> searchDrivers({required Map<String, dynamic> payload}) async {
    final res = await _client.post<Map<String, dynamic>>('/api/auction/search', data: payload);
    return res.data!;
  }

  Future<void> acceptBid({required String rideRequestId, required String bidId}) async {
    await _client.post('/api/auction/accept-bid', data: {
      'ride_request_id': rideRequestId,
      'bid_id': bidId,
    });
  }

  Future<void> fallbackBroadcast({required Map<String, dynamic> payload}) async {
    await _client.post('/api/auction/fallback', data: payload);
  }

  // Saved addresses & recent destinations
  Future<Map<String, dynamic>?> getSavedAddress({
    required String riderIdentityId,
    required String type,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/api/rider/saved-addresses',
      queryParameters: {'rider_identity_id': riderIdentityId, 'type': type},
    );
    return res.data;
  }

  Future<List<dynamic>> getRecentDestinations({required String riderIdentityId}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/api/rider/recent-destinations',
      queryParameters: {'rider_identity_id': riderIdentityId},
    );
    return res.data!['destinations'] as List<dynamic>;
  }

  Future<void> addRecentDestination({
    required Map<String, dynamic> destination,
    required String riderIdentityId,
  }) async {
    await _client.post('/api/rider/recent-destinations', data: {
      ...destination,
      'rider_identity_id': riderIdentityId,
    });
  }

  // Nearby drivers
  Future<int> getDriversNearby({
    required double lat, required double lng, double radiusKm = 5,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/api/drivers-nearby',
      queryParameters: {'lat': lat, 'lng': lng, 'radius_km': radiusKm},
    );
    return res.data!['count'] as int? ?? 0;
  }
}

final riderApiProvider = Provider<RiderApi>(
  (ref) => RiderApi(ref.watch(apiClientProvider)),
);
```

### 4.6 Driver API Functions

In `packages/heycaby_api/lib/src/driver_api.dart`:

```dart
class DriverApi {
  DriverApi(this._client);
  final ApiClient _client;

  Future<void> setStatus({required String status}) async {
    await _client.patch('/api/driver/status', data: {'status': status});
  }

  Future<void> uploadLocation({
    required double lat, required double lng, double? heading,
  }) async {
    await _client.post('/api/driver/location', data: {
      'lat': lat, 'lng': lng,
      if (heading != null) 'heading': heading,
    });
  }

  Future<void> acceptRide({required String rideRequestId}) async {
    await _client.post('/api/driver/ride/accept', data: {'ride_request_id': rideRequestId});
  }

  Future<void> markArrived({required String rideRequestId}) async {
    await _client.post('/api/driver/ride/arrived', data: {'ride_request_id': rideRequestId});
  }

  Future<void> startRide({required String rideRequestId}) async {
    await _client.post('/api/driver/ride/start', data: {'ride_request_id': rideRequestId});
  }

  Future<void> completeRide({required String rideRequestId}) async {
    await _client.post('/api/driver/ride/complete', data: {'ride_request_id': rideRequestId});
  }

  Future<void> reportNoShow({required Map<String, dynamic> payload}) async {
    await _client.post('/api/driver/ride/no-show', data: payload);
  }

  Future<void> rateRider({required Map<String, dynamic> payload}) async {
    await _client.post('/api/driver/ride/rate', data: payload);
  }

  Future<void> createReceipt({required Map<String, dynamic> payload}) async {
    await _client.post('/api/driver/receipt', data: payload);
  }

  Future<void> placeBid({required Map<String, dynamic> payload}) async {
    await _client.post('/api/auction/bid', data: payload);
  }

  Future<void> acceptFirst({required String rideRequestId}) async {
    await _client.post('/api/auction/accept-first', data: {'ride_request_id': rideRequestId});
  }

  Future<Map<String, dynamic>> getRadar({required double lat, required double lng}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/api/auction/radar',
      queryParameters: {'lat': lat, 'lng': lng},
    );
    return res.data!;
  }
}

final driverApiProvider = Provider<DriverApi>(
  (ref) => DriverApi(ref.watch(apiClientProvider)),
);
```

### 4.7 Realtime Subscriptions

In `packages/heycaby_api/lib/src/realtime_service.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeService {
  final _supabase = Supabase.instance.client;

  // Rider: subscribe to ride status changes
  RealtimeChannel subscribeToRide({
    required String rideId,
    required void Function(Map<String, dynamic> payload) onUpdate,
  }) {
    return _supabase
        .channel('ride:$rideId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ride_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: rideId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }

  // Rider: notify-me queue subscription
  RealtimeChannel subscribeToNotifyQueue({
    required String notifyQueueId,
    required void Function(Map<String, dynamic> payload) onUpdate,
  }) {
    return _supabase
        .channel('notify:$notifyQueueId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'driver_notify_queue',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: notifyQueueId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }

  // Driver: subscribe to new ride requests
  RealtimeChannel subscribeToRideRequests({
    required void Function(Map<String, dynamic> payload) onInsert,
    required void Function(Map<String, dynamic> payload) onUpdate,
  }) {
    return _supabase
        .channel('ride_requests_driver')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'ride_requests',
          callback: (payload) => onInsert(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ride_requests',
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }

  void removeChannel(RealtimeChannel channel) {
    _supabase.removeChannel(channel);
  }
}

final realtimeServiceProvider = Provider<RealtimeService>((_) => RealtimeService());
```

---

## PART 5 — RIDER APP

### 4.1 Navigation (go_router)

In `apps/rider/lib/router.dart`:

```dart
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) => RiderShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/rides', builder: (_, __) => const RidesScreen()),
        GoRoute(path: '/account', builder: (_, __) => const AccountScreen()),
      ],
    ),
    // Booking stack
    GoRoute(path: '/search', builder: (_, __) => const AddressSearchScreen()),
    GoRoute(path: '/confirm', builder: (_, s) => ConfirmDestinationScreen(extra: s.extra)),
    GoRoute(path: '/options', builder: (_, s) => BookingOptionsScreen(extra: s.extra)),
    GoRoute(path: '/payment', builder: (_, s) => PaymentScreen(extra: s.extra)),
    GoRoute(path: '/summary', builder: (_, s) => TripSummaryScreen(extra: s.extra)),
    GoRoute(path: '/searching/:rideId', builder: (_, s) => SearchingScreen(rideId: s.pathParameters['rideId']!)),
    GoRoute(path: '/active/:rideId', builder: (_, s) => ActiveRideScreen(rideId: s.pathParameters['rideId']!)),
    GoRoute(path: '/inprogress/:rideId', builder: (_, s) => InProgressScreen(rideId: s.pathParameters['rideId']!)),
    GoRoute(path: '/complete/:rideId', builder: (_, s) => CompleteScreen(rideId: s.pathParameters['rideId']!)),
    GoRoute(path: '/rate/:rideId', builder: (_, s) => RateScreen(rideId: s.pathParameters['rideId']!)),
    GoRoute(path: '/rides/:id', builder: (_, s) => RideDetailScreen(id: s.pathParameters['id']!)),
    // Modals
    GoRoute(path: '/verify', builder: (_, __) => const VerificationScreen()),
    GoRoute(path: '/favorites', builder: (_, __) => const FavoriteDriversScreen()),
    GoRoute(path: '/report', builder: (_, __) => const ReportRideScreen()),
  ],
);
```

### 4.2 Screens (1:1 with PWA)

| PWA Route | Flutter Screen | Notes |
|-----------|---------------|--------|
| Home | `HomeScreen` | Map + bottom sheet "Where to?", home address shortcut, recent destinations |
| Address search | `AddressSearchScreen` | Mapbox Search autocomplete, pickup + destination |
| Confirm destination | `ConfirmDestinationScreen` | Route preview, distance, duration, Continue |
| Booking options | `BookingOptionsScreen` | Instant / Scheduled / Marketplace, vehicle type, favorites-only toggle |
| Payment | `PaymentScreen` | Payment method, booking name; NO ride created yet |
| Trip summary | `TripSummaryScreen` | Full trip details; ride created ONLY when "Find my driver" tapped |
| Searching | `SearchingScreen` | Spinner, timer, Notify me, Cancel; Realtime subscription |
| Active ride | `ActiveRideScreen` | Driver card, ETA, vehicle, Realtime updates |
| In progress | `InProgressScreen` | Trip underway, support access |
| Complete | `CompleteScreen` | Receipt, rate driver |
| Rate | `RateScreen` | Stars + reasons, POST `/api/ride/rate` |
| Rides list | `RidesScreen` | GET `/api/rider/rides?rider_token=...` |
| Ride detail | `RideDetailScreen` | GET `/api/rider/rides/[id]`, report, track link |
| Account | `AccountScreen` | Profile, language, theme, home address, notifications, favorites |
| Favorite drivers | `FavoriteDriversScreen` | GET/POST `/api/rider/favorites` |
| Report ride | `ReportRideScreen` | POST `/api/rider/report` |
| Verification | `VerificationScreen` | OTP modal |

### 4.3 Rider State (Riverpod)

In `apps/rider/lib/providers/booking_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_models/heycaby_models.dart';

enum BookingState {
  idle,
  editingTrip,
  tripReview,
  creatingRide,
  searching,
  driverAssigned,
  driverArriving,
  inProgress,
  completed,
  notifyMe,
}

enum BookingMode { instant, scheduled, marketplace }

class BookingNotifier extends Notifier<BookingData> {
  @override
  BookingData build() => BookingData.empty();

  void setPickup(AddressResult pickup) =>
      state = state.copyWith(pickup: pickup, bookingState: BookingState.editingTrip);

  void setDestination(AddressResult destination) =>
      state = state.copyWith(destination: destination);

  void setBookingMode(BookingMode mode) =>
      state = state.copyWith(bookingMode: mode);

  void setFavoritesOnly(bool value) =>
      state = state.copyWith(favoritesOnly: value);

  void setPaymentMethod(String method) =>
      state = state.copyWith(paymentMethod: method);

  void setScheduledAt(DateTime? dt) =>
      state = state.copyWith(scheduledAt: dt);

  void setActiveRide(String rideId, String? driverId) =>
      state = state.copyWith(
        activeRideId: rideId,
        assignedDriverId: driverId,
        bookingState: BookingState.searching,
      );

  void transitionTo(BookingState newState) =>
      state = state.copyWith(bookingState: newState);

  void reset() => state = BookingData.empty();
}

@Riverpod(keepAlive: true)
BookingNotifier bookingNotifier(BookingNotifierRef ref) => BookingNotifier();
```

### 4.4 Find My Driver — Critical Implementation

This is the most important flow in the rider app. Full implementation:

```dart
// In TripSummaryScreen
class TripSummaryScreen extends ConsumerStatefulWidget {
  const TripSummaryScreen({super.key, this.extra});
  final Object? extra;

  @override
  ConsumerState<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends ConsumerState<TripSummaryScreen> {
  bool _isCreating = false;
  CancelToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel('Screen disposed');
    super.dispose();
  }

  Future<void> _onFindMyDriver() async {
    if (_isCreating) return; // Prevent duplicate taps

    final booking = ref.read(bookingNotifierProvider);
    final identity = await SecureStorage.getRiderIdentity();
    final riderToken = identity['rider_token'];
    final riderIdentityId = identity['rider_identity_id'];

    if (riderToken == null || riderIdentityId == null) {
      context.go('/verify');
      return;
    }

    setState(() => _isCreating = true);
    _cancelToken = CancelToken();

    try {
      final idempotencyKey = '${riderIdentityId}_${DateTime.now().millisecondsSinceEpoch}';

      final result = await ref.read(riderApiProvider).createRide(
        payload: {
          'pickup_lat': booking.pickup!.lat,
          'pickup_lng': booking.pickup!.lng,
          'pickup_address': booking.pickup!.address,
          'dest_lat': booking.destination!.lat,
          'dest_lng': booking.destination!.lng,
          'dest_address': booking.destination!.address,
          'booking_mode': booking.bookingMode.name,
          'payment_method': booking.paymentMethod,
          'rider_token': riderToken,
          'rider_identity_id': riderIdentityId,
          'favorites_only': booking.favoritesOnly,
          if (booking.scheduledAt != null)
            'scheduled_at': booking.scheduledAt!.toIso8601String(),
        },
        idempotencyKey: idempotencyKey,
      );

      final rideId = result['ride_id'] as String;
      ref.read(bookingNotifierProvider.notifier).setActiveRide(rideId, null);

      if (mounted) context.go('/searching/$rideId');
    } on DioException catch (e) {
      if (!mounted) return;
      _showError(AppLocalizations.of(context)!.connectionProblem);
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Trip details...
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _isCreating ? null : _onFindMyDriver,
                child: _isCreating
                    ? const CircularProgressIndicator.adaptive()
                    : Text(l10n.findMyDriver),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## PART 6 — DRIVER APP

### 5.1 Navigation

```dart
final driverRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final isAuthed = Supabase.instance.client.auth.currentUser != null;
    if (!isAuthed && state.matchedLocation != '/login') return '/login';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    ShellRoute(
      builder: (context, state, child) => DriverShell(child: child),
      routes: [
        GoRoute(path: '/driver/home', builder: (_, __) => const DriverHomeScreen()),
        GoRoute(path: '/driver/market', builder: (_, __) => const MarketScreen()),
        GoRoute(path: '/driver/radar', builder: (_, __) => const RadarScreen()),
        GoRoute(path: '/driver/community', builder: (_, __) => const CommunityScreen()),
        GoRoute(path: '/driver/earnings', builder: (_, __) => const EarningsScreen()),
        GoRoute(path: '/driver/profile', builder: (_, __) => const DriverProfileScreen()),
      ],
    ),
    GoRoute(path: '/driver/ride/:id', builder: (_, s) => DriverRideDetailScreen(id: s.pathParameters['id']!)),
    GoRoute(path: '/driver/ride/:id/complete', builder: (_, s) => DriverCompleteScreen(id: s.pathParameters['id']!)),
    GoRoute(path: '/driver/ride/:id/rate', builder: (_, s) => DriverRateScreen(id: s.pathParameters['id']!)),
    GoRoute(path: '/driver/go-online', builder: (_, __) => const GoOnlineScreen()),
  ],
);
```

### 5.2 Driver Screens (1:1 with PWA)

| PWA Route | Flutter Screen | Notes |
|-----------|---------------|--------|
| Login | `LoginScreen` | Supabase Auth email/password |
| Register | `RegisterScreen` | Supabase Auth sign up |
| Onboarding | `OnboardingScreen` (multi-step) | Personal, legal, vehicle, rates, docs; Supabase writes |
| Go online | `GoOnlineScreen` | Status toggle, PATCH `/api/driver/status`, start location loop |
| Driver home | `DriverHomeScreen` | Map, status badge, incoming rides, Realtime |
| Market | `MarketScreen` | Nu / Gepland / Markt tabs; accept-first, bid |
| Radar | `RadarScreen` | Return rides, GET `/api/auction/radar`, bid sheet |
| Ride detail | `DriverRideDetailScreen` | Status stepper, deep link nav, arrived/start/complete |
| Complete | `DriverCompleteScreen` | Receipt generation |
| Rate rider | `DriverRateScreen` | POST `/api/driver/ride/rate` |
| Favorites | `FavoritesScreen` | GET/POST `/api/driver/favorite-requests` |
| Community | `CommunityScreen` | Supabase `community_posts` |
| Earnings | `EarningsScreen` | Completed rides, earnings summary |
| Profile | `DriverProfileScreen` | Driver info, photo, vehicle |
| Settings | `DriverSettingsScreen` | Logout, preferences |

### 5.3 Driver State (Riverpod)

```dart
enum DriverAppState {
  loggedOut,
  onboardingIncomplete,
  offline,
  goingOnline,
  onlineAvailable,
  reviewingRequest,
  acceptingRide,
  assigned,
  arrived,
  inProgress,
  completingRide,
  completed,
  onBreak,
  errorRecovery,
}

class DriverStateNotifier extends Notifier<DriverData> {
  @override
  DriverData build() => DriverData.empty();

  void setStatus(DriverAppState state) =>
      this.state = this.state.copyWith(appState: state);

  void setActiveRide(String rideId) =>
      state = state.copyWith(activeRideId: rideId, appState: DriverAppState.assigned);

  void clearActiveRide() =>
      state = state.copyWith(activeRideId: null, appState: DriverAppState.onlineAvailable);
}
```

### 5.4 Background Location (Driver Only)

In `apps/driver/lib/services/location_service.dart`:

```dart
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

@pragma('vm:entry-point')
void backgroundLocationTask(ServiceInstance service) async {
  // This runs in a separate isolate
  final locationStream = Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  );

  locationStream.listen((position) {
    service.invoke('location_update', {
      'lat': position.latitude,
      'lng': position.longitude,
      'heading': position.heading,
      'timestamp': position.timestamp.toIso8601String(),
    });
  });
}

class DriverLocationService {
  static Future<void> start() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: backgroundLocationTask,
        isForegroundMode: true,
        notificationChannelId: 'heycaby_driver_location',
        initialNotificationTitle: 'HeyCaby Driver',
        initialNotificationContent: 'Locatie actief — je bent online',
      ),
      iosConfiguration: IosConfiguration(
        onForeground: backgroundLocationTask,
        onBackground: backgroundLocationTask,
      ),
    );
    await service.startService();
  }

  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  static Stream<Map<String, dynamic>?> get locationUpdates {
    final service = FlutterBackgroundService();
    return service.on('location_update');
  }
}
```

**In the Driver Home screen**, listen to location updates and upload to backend:

```dart
void _startLocationUpload() {
  DriverLocationService.locationUpdates.listen((data) async {
    if (data == null) return;
    await ref.read(driverApiProvider).uploadLocation(
      lat: data['lat'] as double,
      lng: data['lng'] as double,
      heading: data['heading'] as double?,
    );
  });
}
```

### 5.5 External Navigation Deep Links

```dart
class NavigationHandoffService {
  static Future<void> navigateTo({
    required double lat,
    required double lng,
    required String label,
  }) async {
    final encoded = Uri.encodeComponent(label);

    // Try Apple Maps first (iOS), Google Maps (Android), fallback Waze
    final appleUrl = 'maps://maps.apple.com/?daddr=$lat,$lng&dirflg=d';
    final googleUrl = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';
    final wazeUrl = 'waze://?ll=$lat,$lng&navigate=yes';

    if (Platform.isIOS && await canLaunchUrl(Uri.parse(appleUrl))) {
      await launchUrl(Uri.parse(appleUrl));
    } else if (await canLaunchUrl(Uri.parse(googleUrl))) {
      await launchUrl(Uri.parse(googleUrl), mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(Uri.parse(wazeUrl), mode: LaunchMode.externalApplication);
    }
  }
}
```

---

## PART 7 — MAPBOX INTEGRATION

### 6.1 Package

Use **`mapbox_maps_flutter: ^2.3.0`** only. Do not add any other Mapbox or map package.

### 6.2 Mapbox Credentials

Store in environment — never hardcode.

In `apps/rider/android/app/src/main/res/values/mapbox.xml` (Android):
```xml
<resources>
  <string name="mapbox_access_token" translatable="false">
    <!-- injected at build time from environment -->
  </string>
</resources>
```

In `apps/rider/ios/Runner/Info.plist` (iOS):
```xml
<key>MBXAccessToken</key>
<string>$(MAPBOX_ACCESS_TOKEN)</string>
```

Pass via CI/CD environment variables — never in source code.

### 6.3 Provider Abstraction (Mandatory)

All map/geocode/routing calls go through service wrappers. Screens never call Mapbox directly.

```dart
// packages/heycaby_map/lib/src/map_service.dart
abstract class MapService {
  Widget buildMapView({
    required CameraOptions initialCamera,
    required void Function(MapboxMap map) onMapCreated,
  });

  Future<void> animateTo(MapboxMap map, CameraOptions options);
  Future<void> addMarker(MapboxMap map, {required LatLng position, required String id});
  Future<void> showRoute(MapboxMap map, List<LatLng> geometry);
  Future<LatLng?> getUserLocation();
}

// packages/heycaby_map/lib/src/geocoding_service.dart
abstract class GeocodingService {
  // Returns address suggestions for query (min 3 chars, debounced 300ms)
  Future<List<AddressResult>> search({
    required String query,
    required LatLng? proximity,
    String? country,
    BoundingBox? bbox,
  });

  // Reverse geocode coordinates to address string
  Future<AddressResult?> reverseGeocode(LatLng position);
}

// packages/heycaby_map/lib/src/routing_service.dart
abstract class RoutingService {
  // Get route between two points
  // Results are CACHED — do not re-fetch when pickup/destination unchanged
  Future<RouteResult?> getRoute({
    required LatLng from,
    required LatLng to,
  });
}
```

Implementations use Mapbox APIs. Future provider swap only requires new implementations — screens unchanged.

### 6.4 Cost Rules (Enforce in Code)

```dart
// Geocoding service implementation — enforce cost rules
class MapboxGeocodingService implements GeocodingService {
  String? _sessionToken;
  Timer? _debounceTimer;

  @override
  Future<List<AddressResult>> search({
    required String query,
    required LatLng? proximity,
    String? country,
    BoundingBox? bbox,
  }) async {
    // Rule 1: Minimum 3 characters before calling API
    if (query.trim().length < 3) return [];

    // Rule 2: One session token per active search flow
    _sessionToken ??= _generateSessionToken();

    return _performSearch(query, proximity, country, bbox);
  }

  void startNewSession() => _sessionToken = _generateSessionToken();
  void endSession() => _sessionToken = null;

  String _generateSessionToken() => const Uuid().v4();
}
```

In the search screen:
```dart
// Rule 3: Debounce 300ms
_searchController.addListener(() {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 300), () {
    if (_searchController.text.length >= 3) {
      ref.read(geocodingProvider).search(query: _searchController.text, ...);
    }
  });
});

// Rule 4: Only fetch route when both pickup AND destination are selected
void _onDestinationSelected(AddressResult destination) {
  if (booking.pickup != null) {
    ref.read(routingProvider).getRoute(from: booking.pickup!.latlng, to: destination.latlng);
  }
}
```

---

## PART 8 — STATE MANAGEMENT (RIVERPOD)

### 7.1 Why Riverpod

Riverpod is the production-grade Flutter state solution. It maps directly to the Zustand patterns in the PWA spec:

| PWA (Zustand) | Flutter (Riverpod) |
|---------------|--------------------|
| `useBookingStore` | `bookingNotifierProvider` |
| `useDriverStore` | `driverStateProvider` |
| Store actions | `notifier.method()` |
| Reactive selectors | `ref.watch(provider.select(...))` |

### 7.2 Providers Structure

```dart
// Rider providers
final riderIdentityProvider = FutureProvider<RiderIdentity?>((ref) async {
  final identity = await SecureStorage.getRiderIdentity();
  if (identity['rider_token'] == null) return null;
  return RiderIdentity.fromMap(identity);
});

final bookingNotifierProvider = NotifierProvider<BookingNotifier, BookingData>(
  BookingNotifier.new,
);

final activeRideProvider = StreamProvider.family<RideData, String>((ref, rideId) {
  return ref.watch(realtimeServiceProvider).watchRide(rideId);
});

// Driver providers
final driverAuthProvider = StreamProvider<User?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange
      .map((event) => event.session?.user);
});

final driverStateProvider = NotifierProvider<DriverStateNotifier, DriverData>(
  DriverStateNotifier.new,
);

final incomingRidesProvider = StreamProvider<List<RideRequest>>((ref) {
  return ref.watch(realtimeServiceProvider).watchIncomingRides();
});
```

### 7.3 App Launch — Restore State

In `main.dart`, after Supabase initializes, check for an active ride and restore the correct screen:

```dart
// In a startup provider
final startupProvider = FutureProvider<StartupResult>((ref) async {
  final identity = await SecureStorage.getRiderIdentity();
  if (identity['rider_token'] == null) return StartupResult.unauthenticated;

  // Check if there's an active ride to resume
  final riderToken = identity['rider_token']!;
  // Could check local storage for activeRideId, then verify with GET /api/ride/[id]
  // If active, restore correct booking state
  return StartupResult.authenticated;
});
```

---

## PART 9 — PUSH NOTIFICATIONS

### 9.1 The Gap — What Exists vs What Flutter Needs

Your Supabase project has three push-related tables. Two of them are Web Push only and cannot be used by Flutter as-is:

| Table | Current state | Flutter state |
|-------|--------------|---------------|
| `push_subscriptions` | Stores VAPID fields: `endpoint`, `p256dh`, `auth` | Cannot use — these are browser Web Push fields |
| `rider_push_subscriptions` | Same VAPID structure + `rider_identity_id` | Needs `device_token` + `platform` columns added |
| `drivers.push_token` | Single `TEXT` column already on the `drivers` table | **Ready to use now** — write FCM token here on driver app launch |

The PWA keeps working unchanged. Flutter requires two small additions described below.

### 9.2 Required Schema Changes (Minimal — Non-Breaking)

**For riders** — add two columns to `rider_push_subscriptions`:

```sql
ALTER TABLE public.rider_push_subscriptions
  ADD COLUMN IF NOT EXISTS device_token TEXT,
  ADD COLUMN IF NOT EXISTS platform TEXT CHECK (platform IN ('ios', 'android'));
```

This is non-breaking. Existing Web Push rows have `NULL` in both new columns. The `send-push` edge function checks which columns are populated to decide delivery path.

**For drivers** — no schema change needed. `drivers.push_token` already exists as a `TEXT` column. Write the FCM token there on every app launch.

### 9.3 Update `send-push` Edge Function

The `send-push` edge function (currently Web Push only) needs a mobile delivery branch. The logic split:

```typescript
// In send-push/index.ts — add after existing Web Push logic

if (record.device_token && record.platform) {
  // Mobile path: send via FCM
  await sendFcmNotification({
    token: record.device_token,
    title: payload.title,
    body: payload.body,
    data: payload.data,
  });
} else if (record.endpoint && record.p256dh && record.auth) {
  // Web Push path: existing logic unchanged
  await sendWebPush(record, payload);
}
```

Add `FCM_SERVER_KEY` (or Firebase Admin SDK credentials) to your Supabase project secrets.

### 9.4 Firebase Setup

Both apps use Firebase Cloud Messaging (FCM) for Android + APNs for iOS.

1. Create a Firebase project (or use existing one)
2. Add Android (`google-services.json`) and iOS (`GoogleService-Info.plist`) configs to each app
3. Enable FCM in Firebase Console
4. Add Firebase Admin SDK service account JSON to Supabase secrets as `FIREBASE_SERVICE_ACCOUNT`

### 9.5 Flutter Push Service Implementation

In `packages/heycaby_api/lib/src/push_service.dart`:

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushService {
  static Future<void> initializeForRider() async {
    await Firebase.initializeApp();
    await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _registerRiderToken(token);
    FirebaseMessaging.instance.onTokenRefresh.listen(_registerRiderToken);
    FirebaseMessaging.onBackgroundMessage(_handleBackground);
    FirebaseMessaging.onMessage.listen(_handleForeground);
  }

  static Future<void> initializeForDriver() async {
    await Firebase.initializeApp();
    await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _registerDriverToken(token);
    FirebaseMessaging.instance.onTokenRefresh.listen(_registerDriverToken);
    FirebaseMessaging.onBackgroundMessage(_handleBackground);
    FirebaseMessaging.onMessage.listen(_handleForeground);
  }

  // RIDER: upsert into rider_push_subscriptions with device_token + platform
  static Future<void> _registerRiderToken(String token) async {
    final identity = await SecureStorage.getRiderIdentity();
    final identityId = identity['rider_identity_id'];
    if (identityId == null) return;

    await Supabase.instance.client
        .from('rider_push_subscriptions')
        .upsert({
          'rider_identity_id': identityId,
          'device_token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          // Leave endpoint/p256dh/auth null for mobile rows
          'rider_token': identity['rider_token'] ?? '',
          'endpoint': 'mobile:$token', // unique placeholder so unique constraint passes
        }, onConflict: 'rider_identity_id')
        .select();
  }

  // DRIVER: write FCM token to drivers.push_token column (already exists)
  static Future<void> _registerDriverToken(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    await Supabase.instance.client
        .from('drivers')
        .update({'push_token': token})
        .eq('user_id', user.id);
  }

  @pragma('vm:entry-point')
  static Future<void> _handleBackground(RemoteMessage message) async {
    // Background handler — runs in isolate
  }

  static void _handleForeground(RemoteMessage message) {
    FlutterLocalNotificationsPlugin().show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'heycaby_channel',
          'HeyCaby',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
```

### 9.6 Initialise in `main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HeyCabySupabase.initialize();
  await PushService.initializeForRider(); // or initializeForDriver() in driver app
  runApp(const ProviderScope(child: HeyCabyApp()));
}
```

### 9.7 PWA Compatibility

The PWA continues to use Web Push (VAPID) via the existing `rider_push_subscriptions` rows that have `endpoint` / `p256dh` / `auth` populated. Flutter rows have `device_token` + `platform` populated instead. The `send-push` edge function routes based on which fields are present. Both delivery paths coexist in the same table — no migration of existing PWA subscriptions required.

---

## PART 10 — RIDER BOOKING STATE MACHINE (LOCKED)

This is the single source of truth for the rider booking flow in Flutter. The logic is identical to the spec — only the implementation language changes.

### States

```dart
enum BookingState {
  idle,           // App open, no booking
  editingTrip,    // Entering pickup/destination
  tripReview,     // Confirm → Options → Payment → Summary (NO ride created)
  creatingRide,   // Locked — POST /api/ride/create in flight
  searching,      // Ride exists, waiting for driver
  driverAssigned, // Driver accepted
  driverArriving, // Driver approaching
  inProgress,     // Trip underway
  completed,      // Ride finished
  notifyMe,       // In notify-me queue
}
```

### State Transitions

```
idle → editingTrip → tripReview → creatingRide → searching
                                                     ↓
                                            driverAssigned → driverArriving → inProgress → completed → idle
                                                     ↓
                                                  notifyMe → driverAssigned
                                                     ↓
                                                    idle (cancel)
```

### Screen → State Mapping

| Screen | Booking State |
|--------|---------------|
| `HomeScreen` | `idle` |
| `AddressSearchScreen` | `editingTrip` |
| `ConfirmDestinationScreen` | `tripReview` |
| `BookingOptionsScreen` | `tripReview` |
| `PaymentScreen` | `tripReview` |
| `TripSummaryScreen` | `tripReview` |
| Loading after "Find my driver" | `creatingRide` |
| `SearchingScreen` | `searching` |
| `ActiveRideScreen` | `driverAssigned` / `driverArriving` |
| `InProgressScreen` | `inProgress` |
| `CompleteScreen` | `completed` |
| NotifyMe UI | `notifyMe` |

### Non-Negotiable Rules

1. **No ride before "Find my driver"** — `POST /api/ride/create` is called only on button tap in `TripSummaryScreen`
2. **Trip Summary is local only** — renders from `BookingNotifier` state, not from a backend ride
3. **Single create action** — button disabled immediately, idempotency key sent
4. **Searching requires `ride_id`** — the `SearchingScreen` must receive a valid `ride_id` as a route parameter
5. **Pre-create cancel = local reset** — no API call
6. **Post-create cancel = `POST /api/ride/cancel`**
7. **Realtime starts after creation** — subscribe to `ride_requests` only after `ride_id` is returned

---

## PART 11 — DRIVER STATE MACHINE (LOCKED)

### States

```dart
enum DriverAppState {
  loggedOut,
  onboardingIncomplete,
  offline,
  goingOnline,
  onlineAvailable,
  reviewingRequest,
  acceptingRide,    // Locked — accept API call in flight
  assigned,
  arrived,
  inProgress,
  completingRide,   // Locked — complete API call in flight
  completed,
  onBreak,
  errorRecovery,
}
```

### State Transitions

```
loggedOut → onboardingIncomplete → offline → goingOnline → onlineAvailable
                                                                 ↓
                                                         reviewingRequest → acceptingRide → assigned → arrived → inProgress → completingRide → completed → onlineAvailable
                                                                 ↓
                                                              onBreak ↔ onlineAvailable
                                                    (any active state) → errorRecovery → restored state
```

### Non-Negotiable Rules

1. **Accept only once** — button disabled immediately on tap
2. **Start only after arrived** — `start` action blocked unless state is `arrived`
3. **Complete only after start** — `complete` action blocked unless state is `inProgress`
4. **Active ride blocks conflicting actions** — no second ride accept while `assigned` / `arrived` / `inProgress`
5. **Backend is truth** — on conflict, fetch current ride and restore from backend
6. **Location must continue** — through `onlineAvailable`, `assigned`, `arrived`, `inProgress`
7. **Recovery on reopen** — if active ride exists, skip home and navigate to correct screen

### App Reopen Recovery

```dart
// In DriverHomeScreen initState
Future<void> _recoverStateOnLaunch() async {
  final driverState = ref.read(driverStateProvider);
  if (driverState.activeRideId == null) return;

  try {
    final ride = await ref.read(driverApiProvider)
        .getRideById(driverState.activeRideId!);
    final status = ride['status'] as String;

    switch (status) {
      case 'assigned':
        context.go('/driver/ride/${driverState.activeRideId}');
      case 'in_progress':
        context.go('/driver/ride/${driverState.activeRideId}');
      case 'completed':
        context.go('/driver/ride/${driverState.activeRideId}/complete');
      default:
        ref.read(driverStateProvider.notifier).clearActiveRide();
    }
  } catch (_) {
    // If fetch fails, show home — don't crash
  }
}
```

---

## PART 12 — EDGE CASES & FAILURE HANDLING

Both apps must handle all of these. They represent the difference between a prototype and a production platform.

### 11.1 Rider Edge Cases

| Scenario | Required Behavior |
|----------|-------------------|
| Network drops during ride creation | Show "Connection problem. Please try again." — stay on Trip Summary — allow retry — do NOT assume ride was created |
| Duplicate "Find my driver" tap | Button disabled after first tap — idempotency key prevents backend duplicate |
| App closed during searching | On reopen: check `activeRideId` → GET ride → resume correct screen |
| Network loss during searching | Show "Reconnecting…" banner — retry realtime subscription — continue when reconnected |
| Driver cancels after accepting | Realtime update → show "Driver cancelled. Searching again." → return to `searching` state |
| GPS permission denied | Show explanation → offer "Enable Location" or "Enter manually" — app still works with manual entry |
| App crash mid-ride | On relaunch: check secure storage for `activeRideId` → fetch ride → restore screen |
| Ride completed but app missed event | On screen open: GET `/api/ride/[id]` — if `status == completed`, navigate to Complete |
| Notify-me conversion | Realtime on `driver_notify_queue` → convert → navigate to `ActiveRide` |

### 11.2 Driver Edge Cases

| Scenario | Required Behavior |
|----------|-------------------|
| Ride already taken by another driver | HTTP 409 → "This ride was already accepted." → remove from list → return to `onlineAvailable` |
| Accept fails (network timeout) | On timeout: do NOT assume accepted → query active ride → if assigned: go to `assigned` → if not: return to `onlineAvailable` |
| Driver tries to go offline during active ride | Show warning: "You have an active ride. Finish the trip first." |
| App closes during ride | On reopen: fetch active ride → navigate to correct screen — never drop to home |
| Rider cancels while driver is navigating | Realtime → "Ride cancelled by rider" → stop navigation → clear ride → return to `onlineAvailable` |
| Rider no-show | After wait period: show "Report No Show" → POST `/api/driver/ride/no-show` |
| Location loop fails | Show "Location tracking interrupted" warning → offer "Fix Location" |
| Realtime disconnect | Attempt reconnect → fallback to polling if needed — driver must still receive rides |
| GPS permission removed while online | Force driver to `offline` → "Location permission required to receive rides." → "Open Settings" button |
| Duplicate accept taps | Disable button immediately — backend enforces single acceptance |

### 11.3 General Rules

- Every API call must have a **timeout** (10s connect, 15s receive in Dio config above)
- Every API error must produce a **user-safe localised message** — no raw error strings in UI
- **UI state must always match backend state** — when in doubt, fetch and reconcile
- **Ride lifecycle must be recoverable** even after app close, network drop, or phone restart

---

## PART 13 — SHARED CONCERNS

### 12.1 Design System (`heycaby_ui` Package)

```dart
// packages/heycaby_ui/lib/src/tokens.dart
class HeyCabyColors {
  static const primary = Color(0xFF1A1A2E);
  static const accent = Color(0xFF16213E);
  static const surface = Color(0xFFF5F5F5);
  static const error = Color(0xFFE53935);
  static const success = Color(0xFF43A047);
  // ... full palette
}

class HeyCabySpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class HeyCabyTextStyles {
  static const heading1 = TextStyle(fontSize: 28, fontWeight: FontWeight.w700);
  static const heading2 = TextStyle(fontSize: 22, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontSize: 16, fontWeight: FontWeight.w400);
  static const caption = TextStyle(fontSize: 13, fontWeight: FontWeight.w400);
}
```

All custom widgets live in `heycaby_ui`. Both rider and driver apps import from here. No ad-hoc per-screen styling for core controls.

### 12.2 Theme

```dart
// In each app's main.dart
ThemeData buildTheme(BuildContext context) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: HeyCabyColors.primary),
    useMaterial3: true,
    textTheme: const TextTheme(
      // Match tokens
    ),
  );
}
```

### 12.3 Safe Area — Mandatory on Every Screen

```dart
// Every screen must wrap content in SafeArea
Scaffold(
  body: SafeArea(
    child: YourScreenContent(),
  ),
)
```

No content under notch, Dynamic Island, or home indicator. Minimum 44×44 touch targets on all interactive elements.

### 12.4 Error Handling

```dart
// packages/heycaby_utils/lib/src/error_handler.dart
class AppError {
  final String userMessage;
  final String? debugMessage;
  final bool isRetryable;

  const AppError({
    required this.userMessage,
    this.debugMessage,
    this.isRetryable = true,
  });

  static AppError fromDioException(DioException e, AppLocalizations l10n) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => AppError(
        userMessage: l10n.connectionProblem,
        isRetryable: true,
      ),
      DioExceptionType.connectionError => AppError(
        userMessage: l10n.connectionProblem,
        isRetryable: true,
      ),
      _ => AppError(
        userMessage: l10n.connectionProblem,
        debugMessage: e.message,
        isRetryable: true,
      ),
    };
  }
}
```

### 12.5 Environment Configuration

Use `--dart-define` at build time, not `.env` files:

```bash
# Development
flutter run \
  --dart-define=API_BASE_URL=https://heycaby.nl \
  --dart-define=SUPABASE_URL=https://yourproject.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key \
  --dart-define=MAPBOX_ACCESS_TOKEN=pk.your_token

# Production build
flutter build appbundle \
  --dart-define=API_BASE_URL=... \
  # etc.
```

Never hardcode tokens. Never commit `.env` files with production keys.

---

## PART 14 — MIGRATION ORDER (PHASE BY PHASE)

### Phase 1 — Foundation (Week 1–2)

1. Create monorepo structure (`apps/rider`, `apps/driver`, `packages/*`)
2. Set up `heycaby_models` — port all Dart model classes with `json_serializable`
3. Set up `heycaby_api` — Dio client, Supabase client, all API functions, secure storage
4. Set up `heycaby_l10n` — ARB files for EN/NL/AR, run `flutter gen-l10n`
5. Set up `heycaby_map` — service abstractions (interfaces); implement Mapbox providers
6. Set up `heycaby_ui` — theme tokens, base widgets, safe-area scaffold
7. Configure Mapbox credentials in both apps' iOS and Android configs
8. Verify Supabase Realtime works from Flutter (write a test subscription)

### Phase 2 — Rider Core (Week 3–5)

9. Rider navigation shell (tabs: Home, Rides, Account) with go_router
10. Rider auth flow — identity creation, OTP verification, secure storage
11. `HomeScreen` — Mapbox map view, bottom sheet "Where to?", driver count pin
12. `AddressSearchScreen` — Mapbox geocoding, pickup + destination, recent destinations
13. `ConfirmDestinationScreen` — Mapbox Directions, route preview
14. `BookingOptionsScreen` — instant / scheduled / marketplace, vehicle type, favorites-only
15. `PaymentScreen` — payment method selection, booking name
16. `TripSummaryScreen` — local-only review; "Find my driver" button → POST create
17. `SearchingScreen` — Supabase Realtime subscription; Notify-me; Cancel
18. `ActiveRideScreen` + `InProgressScreen` + `CompleteScreen` + `RateScreen`
19. `RidesScreen` + `RideDetailScreen`
20. `AccountScreen` — profile, saved addresses, favorites, language switcher

### Phase 3 — Driver Core (Week 6–8)

21. Driver auth — Supabase email/password login, register
22. Driver onboarding multi-step flow (personal, legal, vehicle, docs, rates)
23. `GoOnlineScreen` — status toggle, PATCH status, start location service
24. Background location service (test on physical device — not simulator)
25. `DriverHomeScreen` — map, status badge, Realtime ride_requests
26. `MarketScreen` — Nu / Gepland / Markt tabs; accept-first; bid
27. `DriverRideDetailScreen` — stepper, arrived / start / complete / no-show
28. `RadarScreen` — GET radar, driver_intents, bid
29. `DriverCompleteScreen` + `DriverRateScreen` — receipt, POST rate
30. Community, Earnings, Profile, Settings screens

### Phase 4 — Polish & Production (Week 9–10)

31. Push notification registration — both apps, mobile device token endpoint
32. Deep links — ride ID, notify queue ID
33. Offline handling and reconnection logic
34. Full RTL testing with Arabic locale on device
35. Safe area testing on iPhone 14/15 (Dynamic Island) and various Android form factors
36. Error state UI for all screens (empty states, network errors, retry buttons)
37. Analytics integration (same events as PWA if desired)
38. App Store / Play Store metadata, permission copy text, screenshots

---

## PART 15 — NON-NEGOTIABLE INFRA RULES

### Networking

- Every API call: **timeout + retry + cancellation** (Dio config above handles this)
- All errors → **localised user-safe messages** via `AppError.fromDioException`
- **Duplicate-sensitive actions** (create ride, accept ride, complete ride, submit bid): disable button immediately on first tap + send idempotency key

### Security

- `rider_token`, `rider_identity_id`, Supabase session → **`flutter_secure_storage` only**
- No PII in plain `SharedPreferences` or `Hive`
- Mapbox tokens, Supabase keys → `--dart-define` at build time only
- No secrets in source code or version control

### i18n

- **Every UI string** goes through `AppLocalizations` — no hardcoded English strings in widgets
- Use `EdgeInsetsDirectional` everywhere — never `EdgeInsets.only(left/right)`
- Test Arabic layout on a real device or simulator with Arabic locale set

### Background Location (Driver)

- Must use **Expo development builds** equivalent — i.e., Flutter app with proper native config, not a basic debug build
- Test on **physical iPhone and Android** — simulators do not accurately reflect OS background throttling
- Document behavior under iOS Low Power Mode and Android Doze
- Handle permission denial and "Reduced Accuracy" gracefully

### Safe Area

- Every screen uses `SafeArea` or equivalent insets — no exceptions
- All primary actions must be reachable — test on iPhone 14 Pro (Dynamic Island) and budget Android

### Store Readiness

- Location permission copy must explain the value to the user:
  - Driver iOS: "HeyCaby Driver uses your location in the background so riders can find you and you can receive ride requests."
  - Rider: "HeyCaby uses your location to set your pickup point and show nearby drivers."
- Misleading permission prompts cause App Store rejection
- Screenshots must match actual app behavior

---

## PART 16 — RELEASE GATES

### v1 Rider — Definition of Done

- [ ] Can create **instant ride** (search → confirm → options → payment → summary → find driver → create → searching)
- [ ] Can create **scheduled ride** (same flow with date/time)
- [ ] Can track ride state in **real time** (searching → assigned → arriving → in progress → complete)
- [ ] Can **cancel** ride (pre-create: local reset; post-create: API cancel)
- [ ] Can view **ride history** (list + detail)
- [ ] **Push notifications** work (driver accepted, driver arrived)
- [ ] **Maps, search, routing** stable on iPhone and Android (no crashes)
- [ ] **Arabic RTL** renders correctly and all strings are translated
- [ ] **No controls hidden by notch/home bar** on any target device
- [ ] **App restart mid-ride** resumes correct screen

### v1 Driver — Definition of Done

- [ ] Can **sign in** and **complete onboarding**
- [ ] Can **go online / offline** (status toggle + PATCH API)
- [ ] **Background location uploads reliably** on physical iOS and Android device
- [ ] Can **receive and accept** a ride
- [ ] Can complete full **ride lifecycle** (arrived → start → complete)
- [ ] Can **bid** in marketplace
- [ ] Can **deep link** to Apple Maps / Google Maps / Waze
- [ ] **Push notifications** work (new ride, cancellation)
- [ ] **App restart during active ride** resumes correct screen (not home)

### Performance (Both Apps)

- [ ] Home screen opens without visible blank flash — map shell or skeleton visible within 300ms
- [ ] Address search feels **responsive** (debounced; no blocking on each keystroke)
- [ ] No **blocking loaders** for common actions — inline / non-modal feedback
- [ ] No excessive re-renders on map screens — throttle location updates; avoid per-frame `setState`

---

## DEVELOPER COMPLIANCE NOTICE

This spec is the frozen baseline for Flutter implementation. Any deviation requires explicit discussion and documentation before implementation. Silent changes to architecture, dependencies, state shape, or API call timing will jeopardise the migration.

**Core rule:** The Supabase backend, tables, RLS policies, and Next.js API routes are not touched. Only the Flutter UI is built — connecting to the existing backend exactly as specified.

**Final priority order:**
1. Rider foundation (navigation, API client, auth)
2. Rider booking flow (search → confirm → create → realtime)
3. Rider ride tracking (active → complete)
4. Driver auth + onboarding
5. Driver online/location (background service — test early on device)
6. Driver ride lifecycle (accept → complete)
7. i18n + RTL + Arabic locale
8. Push notifications
9. Polish + edge cases + release gates

Test Mapbox, Supabase Realtime, push notifications, and background location **early** — these are the riskiest pieces and the ones most likely to need device-specific debugging time.

---

*HeyCaby Flutter Architecture Spec v1.1 — Generated from PWA spec v1.2. Updated with live Supabase audit (HeyCaby production, 31 tables, 6 edge functions). Push notification schema gap documented with migration SQL. Extra tables (ride_shares, notifications, app_analytics) incorporated. Backend unchanged except two minimal push adaptations noted in Part 9.*
