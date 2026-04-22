# HeyCaby Flutter — Master AI Agent Build Prompt
## Complete A–Z Instructions for Building the Rider and Driver Apps
### Feed this prompt to your AI coding agent at the start of every session

---

## WHO YOU ARE AND WHAT YOU ARE BUILDING

You are building **HeyCaby** — a two-sided taxi platform for the Netherlands. Two separate Flutter apps:

1. **HeyCaby** (Rider app) — passengers book rides, track drivers, pay directly
2. **HeyCaby Driver** (Driver app) — professional taxi drivers receive and complete rides

HeyCaby is fundamentally different from Uber and Bolt:
- **0% commission** — drivers keep 100% of every fare
- **Drivers set their own rates** per km, per minute, minimum fare
- **Riders pay drivers directly** — cash, PIN card, or Tikkie (Dutch iDEAL)
- **Marketplace bidding** — riders post routes and drivers bid on price
- **Favourite drivers** — riders save and prioritise specific drivers
- **Full transparency** — drivers see rider name, pickup, and destination before accepting
- **Bubble zones** — neighbourhood zone system for matching

The backend is **already built and live**: Supabase project `fvrprxguoternoxnyhoj` (eu-west-1, PostgreSQL 17.6) with 31 tables, 6 Edge Functions, and a Next.js API at `https://heycaby.nl`. You are building the Flutter frontend only. The backend does not change.

---

## THE REFERENCE DOCUMENTS

Read all 6 before writing any code.

| File | Contents |
|------|---------|
| `heycaby_flutter_spec.md` | Architecture, monorepo structure, API contracts, state machines, edge cases, release gates |
| `heycaby_mapbox_flutter.md` | Mapbox installation, Android/iOS setup, token config, route lines, geocoding, known conflicts |
| `heycaby_rider_flutter.md` | Every rider screen, map states, Realtime subscriptions, booking state machine, build order |
| `heycaby_driver_flutter.md` | Every driver screen, background location, radar, onboarding, push, build order |
| `heycaby_color_themes.md` | 8 color themes, typography system, Riverpod providers, token semantic guide |

---

## ABSOLUTE RULES — NO EXCEPTIONS

### Rule 1 — No hardcoded colors
```dart
// BANNED
Container(color: Color(0xFFFBFBFA))
Container(color: Colors.white)
Icon(Icons.circle, color: Colors.green)

// REQUIRED
final colors = ref.watch(colorsProvider);
Container(color: colors.bg)
Icon(Icons.circle, color: colors.success)
```

### Rule 2 — No hardcoded fonts
```dart
// BANNED
TextStyle(fontFamily: 'Inter', fontSize: 16)
GoogleFonts.inter(fontSize: 16) // directly in a widget

// REQUIRED
final typo = ref.watch(typographyProvider);
Text('x', style: typo.bodyLarge.copyWith(color: colors.text))
```

### Rule 3 — Maximum 300 lines per file
Every file — screen, widget, service, provider — must be 300 lines or fewer. If approaching 300, split it. Name split files logically: `searching_screen.dart` splits into `searching_screen.dart` + `searching_map_layer.dart` + `searching_sheet.dart`.

### Rule 4 — Every string goes through localization
```dart
// BANNED
Text('Find my driver')
SnackBar(content: Text('Connection problem'))

// REQUIRED
Text(l10n.findMyDriver)
SnackBar(content: Text(l10n.connectionProblem))
```
Add every new key to `app_en.arb`, `app_nl.arb`, and `app_ar.arb` simultaneously. Never one without the others.

### Rule 5 — RTL-safe padding
```dart
// BANNED
Padding(padding: EdgeInsets.only(left: 16, right: 8))

// REQUIRED
Padding(padding: EdgeInsetsDirectional.only(start: 16, end: 8))
```

### Rule 6 — Never create a ride before "Find my driver" is tapped
`POST /api/ride/create` is called ONLY when the rider taps "Find my driver" on `TripSummaryScreen`. Never during address search, confirm, options, or payment. `SearchingScreen` requires a valid `ride_id` route parameter before Realtime subscriptions start.

### Rule 7 — Driver status writes to backend first, then UI
```dart
// WRONG — optimistic update
state = DriverAppState.onlineAvailable; // UI first
await api.setStatus('available');        // backend second

// REQUIRED
await api.setStatus('available');        // backend FIRST
if (success) state = DriverAppState.onlineAvailable;
```

### Rule 8 — Duplicate-sensitive actions lock immediately
For: create ride, accept ride, complete ride, submit bid, report no-show, submit rating.
```dart
bool _isSubmitting = false;

Future<void> _onTap() async {
  if (_isSubmitting) return;
  setState(() => _isSubmitting = true);
  try {
    await api.doThing();
  } catch (_) {
    if (mounted) setState(() => _isSubmitting = false);
    rethrow;
  }
}
```

### Rule 9 — Never use mock data
Everything shown to the user comes from the live Supabase backend. If data is unavailable, show a skeleton loader or empty state. No hardcoded names, vehicles, prices, or map pins.

### Rule 10 — Security at every API call
- All ride lifecycle actions go through the Next.js API, never direct Supabase client writes
- Rider token + identity ID stored in `flutter_secure_storage` only (never `SharedPreferences`)
- Mapbox token, Supabase URL, anon key come from `--dart-define` at build time — never hardcoded
- Check for duplicate pending rides before creating a new one (`POST /api/ride/create` includes idempotency key)

### Rule 11 — Check for duplicates before inserting
Before any write that could produce duplicates (favorites, recent destinations, push subscriptions), check if the record already exists.

---

## THE SUPABASE BACKEND (DO NOT CHANGE)

**Project:** `fvrprxguoternoxnyhoj` (HeyCaby production, eu-west-1)
**Next.js API base:** `https://heycaby.nl`
**Auth:** Driver app = Supabase Auth (email/password). Rider app = `rider_token` + `rider_identity_id` from secure storage.

### Key tables:

| Table | Purpose |
|-------|---------|
| `ride_requests` | Core ride record. Status: pending → accepted → driver_arrived → started → completed/cancelled. `booking_mode`: instant/scheduled/marketplace. Realtime subscription target. |
| `drivers` | Profile, status, rates, compliance. `push_token` = FCM token storage. |
| `driver_locations` | PK = `user_id`. Upsert every 5s. Rider subscribes for live car tracking. |
| `rider_identities` | Canonical rider identity. `email`, `booking_name`, `language_pref`, `theme_pref`, `preferred_payment_methods[]`. |
| `rider_sessions` | `session_token` = the `rider_token` used in all API calls. |
| `ride_ratings` | Dual rating. `ratings_revealed_at` set when both parties submit. |
| `ride_bids` | Marketplace bids from drivers. |
| `driver_notify_queue` | Notify-me queue when no driver available. |
| `driver_intents` | Radar heading intent per driver. |
| `radar_matches` | Results from `scan-radar` edge function. |
| `rider_favorite_drivers` | rider_identity_id → driver_id. |
| `recent_destinations` | 120h TTL, max 4 per rider. |
| `saved_addresses` | type='home' only (check constraint). |
| `messages` | In-app chat per ride_request_id. |
| `community_posts` | Driver community board. |
| `notifications` | In-app notification log. Realtime for badge. |
| `ride_shares` | Share token for live ride tracking. |
| `bubble_zones` | 123 zones. Use `bbox` from `cities` table for Mapbox search restriction. |

**Important:** `rider_identities` is canonical rider identity. `rider_profiles` is supplemental — do NOT use as auth source.

### Edge Functions:
| Function | JWT? | Called by |
|----------|------|----------|
| `generate-receipt` | Yes | Driver after completing ride |
| `driver-agent` | No | Driver support screen |
| `send-push` | Yes | Backend triggers automatically — Flutter never calls directly |
| `verify-chauffeurspas` | Yes | Driver onboarding compliance |
| `scan-radar` | Yes | Driver radar screen |
| `track-analytics` | No | Both apps: app_open, ride_started, driver_signup |

---

## THE MAP SYSTEM

**Package:** `mapbox_maps_flutter: 2.19.1` — exact version, no caret.
**Token setup:** `MapboxOptions.setAccessToken()` in `main.dart` before `runApp()`. Pass via `--dart-define=MAPBOX_PUBLIC_TOKEN=pk.xxx`.
**No secret token needed** for Mapbox v11+. Ignore tutorials mentioning `SDK_REGISTRY_TOKEN`.
**Coordinates:** Always `Position(longitude, latitude)` — longitude first. Never reverse these.

### Map states:
| Screen | Coverage | What's shown |
|--------|---------|-------------|
| Rider Home | 55% | GPS puck, ambient driver dots, zone boundary |
| Address Search | 0% | Map hidden |
| Confirm Destination | 68% | Blue pickup circle + gold pin + route polyline + ETA |
| Booking Options | 35% | Same route locked |
| Payment | 58% | Same route, 15% dim overlay |
| Searching | 72% | Pickup with pulse ring, zone hex (marketplace) |
| Active Ride | 68% | Live car marker, ETA bubble, route to pickup |
| In Progress | 70% | Car, route to destination |
| Complete | 65% | Destination pin with green checkmark |
| Driver Home | 55% | Rotating car puck, demand dots, zone |
| New Ride Request | 60% | Driver pos + pickup pin + dashed route |
| Active (to pickup) | 68% | Car + solid route + ETA |
| At Pickup | 65% | Street level, green arrival ring |
| In Progress | 70% | Car + destination route |
| Radar | 100% | City level, hex zones by demand, match pins |

Route lines always use `DirectionsService` + `RouteLayer`. Never draw a straight line.

---

## COLOR + FONT SYSTEM

8 themes. Rider default: `taxi-shade-6`. Driver default: `taxi-shade-2`.

Access every color via:
```dart
final colors = ref.watch(colorsProvider);
final typo = ref.watch(typographyProvider);
```

Token mapping — memorize:
- `colors.bg` → every Scaffold backgroundColor
- `colors.surface` → bottom sheets, modals
- `colors.card` → card backgrounds
- `colors.accent` → primary CTA buttons only
- `colors.accentL` → selected state background
- `colors.text` → headings + primary body
- `colors.textMid` → labels, captions
- `colors.textSoft` → placeholders, hints
- `colors.success` → online, completed, confirmed
- `colors.warning` → on-break, caution
- `colors.error` → offline, error, validation failures

Icons: use Material Icons + `hugeicons` for premium icons. No emoji in production UI.

---

## ARCHITECTURE

```
heycaby-flutter/
  apps/
    rider/          — HeyCaby (rider)
    driver/         — HeyCaby Driver (driver)
  packages/
    heycaby_api/     — HTTP client, Supabase client, all API functions
    heycaby_models/  — Dart model classes (json_serializable)
    heycaby_ui/      — Themes, tokens, typography, shared widgets
    heycaby_l10n/    — ARB files (en, nl, ar), generated localizations
    heycaby_map/     — MapService, GeocodingService, DirectionsService, RouteLayer
    heycaby_utils/   — Error handling, validators, analytics helpers
```

**State management:** Riverpod. Key providers:
- `bookingProvider` — rider booking state (idle through completed)
- `driverStateProvider` — driver lifecycle state
- `themeProvider` / `colorsProvider` / `typographyProvider`
- `riderIdentityProvider` — rider token + identity from secure storage

**Navigation:** go_router.

Rider tabs: `/` → `/rides` → `/account`
Booking stack: `/search` → `/confirm` → `/options` → `/payment` → `/summary` → `/searching/:id` → `/active/:id` → `/inprogress/:id` → `/complete/:id` → `/rate/:id`

Driver tabs: `/driver` → `/driver/market` → `/driver/radar` → `/driver/community` → `/driver/earnings`
Driver ride: `/driver/ride/new/:id` → `/driver/ride/active/:id` → `/driver/ride/pickup/:id` → `/driver/ride/progress/:id` → `/driver/ride/complete/:id` → `/driver/ride/rate/:id`

---

## BOOKING STATE MACHINE (RIDER — LOCKED)

```
idle → editingTrip → tripReview → creatingRide → searching
                                                     ↓
                                           driverAssigned → driverArriving → inProgress → completed → idle
                                                     ↓
                                                 notifyMe
```

`tripReview` covers: ConfirmDestination, BookingOptions, Payment, TripSummary. All local only. No ride in DB.

`creatingRide` = one POST /api/ride/create call, triggered by "Find my driver" tap.
- Disable button immediately
- Send idempotency key: `'${identityId}_${DateTime.now().millisecondsSinceEpoch}'`
- On success: store ride_id, navigate to /searching/:id, start Realtime
- On failure: show error, stay on TripSummary, re-enable button

Cancel before `creatingRide` = local reset only, no API.
Cancel after `creatingRide` = POST /api/ride/cancel + local reset.

---

## BOOKING CARDS — CRITICAL UX

On `BookingOptionsScreen`:
- Neither card is pre-selected when screen opens
- Both start in neutral unselected state
- Unselected: neutral border, empty circle outline top-right
- Selected: accent border + accentL fill + filled circle with white tick
- "Continue" button disabled until card selected AND rider name filled

---

## ADDRESSES — ALWAYS SHOW FULL ADDRESS

Everywhere an address appears: street + house number + postcode + city.
Example: "Beatrixlaan 80, 3072 EL Rotterdam"
Never just "Dransdorf" or a street name alone.
Use `AddressResult.fullAddress` from `GeocodingService.retrieve()`.

---

## PUSH NOTIFICATIONS

Drivers: FCM token → `drivers.push_token` (column exists). Write on every app launch.

Riders: Add columns to `rider_push_subscriptions` first:
```sql
ALTER TABLE public.rider_push_subscriptions
  ADD COLUMN IF NOT EXISTS device_token TEXT,
  ADD COLUMN IF NOT EXISTS platform TEXT CHECK (platform IN ('ios', 'android'));
```
Then upsert FCM token there on launch.

`send-push` edge function handles delivery automatically. Flutter never calls it directly.

---

## BACKGROUND LOCATION (DRIVER ONLY)

Use `flutter_background_service: ^5.0.0` + `geolocator: ^11.0.0`.
Must test on a physical device. Simulator is not sufficient.
Uploads to `driver_locations` every 5 seconds while online.
Android foreground notification: "Locatie actief — je bent online"
On 3 consecutive upload failures: show "Location tracking interrupted" banner.

---

## BUILD ORDER

### Phase 1 — Foundation first
1. Verify Mapbox renders on real Android + real iPhone
2. Verify Supabase Realtime subscription works
3. Set up all Riverpod providers
4. Set up SecureStorage for tokens
5. Set up all API client functions

### Phase 2 — Rider core
6. HomeScreen (map + sheet + search bar)
7. AddressSearchScreen (Mapbox geocoding, 3-char min, 300ms debounce)
8. ConfirmDestinationScreen (route line + FULL addresses + ETA card)
9. BookingOptionsScreen (two cards, NO auto-select, visible checkmarks)
10. PaymentScreen (three methods + info modal)
11. TripSummaryScreen (local review + idempotent "Find my driver")
12. SearchingScreen (Realtime + pulse animation + cancel)
13. ActiveRideScreen (live driver tracking)
14. InProgressScreen → CompleteScreen → RateScreen
15. RidesScreen + RideDetailScreen + AccountScreen + FavouriteDriversScreen

### Phase 3 — Driver core
16. Supabase Auth (login/register)
17. Onboarding (personal → business → vehicle → compliance → rates → legal)
18. GoOnlineScreen (backend first, then UI)
19. Background location service (TEST ON PHYSICAL DEVICE)
20. DriverHomeScreen (status pill + map + incoming slot)
21. NewRideRequestScreen (30s countdown + race condition handler)
22. ActiveRideNavScreen → AtPickupScreen → RideInProgressScreen → RideCompleteScreen
23. RateRiderScreen
24. MarketScreen (Nu / Gepland / Markt tabs)
25. RadarScreen (hex map + match cards)
26. Earnings, Community, Profile, Settings

### Phase 4 — Polish
27. Push notification registration (both apps)
28. External navigation handoff (Apple Maps / Google Maps / Waze)
29. App recovery on launch (resume correct screen if killed mid-ride)
30. ride_shares — "Share ride" button on Active Ride screen
31. notifications table — Realtime badge in both apps
32. Arabic RTL test on device
33. Safe area test on iPhone 14 Pro + budget Android

---

## SYNC TEST — MANDATORY

Test on TWO REAL PHONES simultaneously before marking any screen done.

| Event | Target latency |
|-------|---------------|
| Rider creates ride → driver receives notification | < 5s |
| Driver accepts → rider sees driver dot | < 3s |
| Driver moves → rider car marker updates | < 5s |
| Driver taps "Arrived" → rider status updates | < 2s |
| Driver taps "Start ride" → rider status updates | < 2s |
| Driver taps "Complete" → rider sees complete screen | < 3s |

If any latency target is missed consistently, check Supabase dashboard → Replication → Publications and ensure `ride_requests` is included.

---

## SECURITY CHECKLIST

```
[ ] No hardcoded tokens or keys in any source file
[ ] All tokens come from --dart-define at build time
[ ] rider_token and rider_identity_id in flutter_secure_storage only
[ ] Driver Supabase session managed by supabase_flutter (persisted securely)
[ ] All ride lifecycle actions go through /api/driver/ride/* not direct Supabase writes
[ ] POST /api/ride/create includes idempotency key header
[ ] All duplicate-sensitive actions disable button on first tap
[ ] No PII in SharedPreferences or plain local storage
[ ] Background location permission strings explain value clearly
[ ] Mapbox token starts with pk. (public) never sk. (secret)
[ ] Duplicate check before inserting favorites, subscriptions
```

---

## QUALITY STANDARD

HeyCaby competes against Uber and Bolt. The five moments that define quality:

1. **Driver accepts** — rider goes from "searching" to driver name in < 3s. Feels instant.
2. **Driver arrives** — rider's status pill turns green within 2s of driver tapping Arrived.
3. **Ride starts** — both maps change at the same moment.
4. **Payment reminder** — when driver completes the ride, the payment instruction is the single most visible element on screen. Unmissable.
5. **Rating submitted** — post-ride flow takes under 30 seconds. Clean, satisfying close.

Every screen should feel as polished as Bolt's rider app or the Uber driver app. The theme system, typography, icon consistency, and smooth map transitions are not optional — they are what makes a user trust the platform.

---

*HeyCaby Flutter Master Agent Prompt — March 2026*
*Feed this to your AI coding agent at the start of every build session.*
*All 5 reference documents must be in the agent context.*
*Backend: Supabase project fvrprxguoternoxnyhoj. API: https://heycaby.nl. Both unchanged.*
