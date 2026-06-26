# BUSINESS-LOGIC-SEPARATION
## HeyCaby — Server-Driven Logic Architecture
### Making Flutter a Dumb Renderer. The Backend is the Brain.

**Created:** 2026-04-27  
**Based on:** Full codebase scan (driver app, rider app, shared packages) + Supabase schema audit  
**Status:** Design Document — No changes made

---

## THE CORE IDEA

Expo has OTA (Over the Air) updates. Flutter does not.  
But that's not actually the limitation — **the real power move is different.**

The question is not:  
> "How do I push code to the phone without App Store review?"

The question is:  
> "How do I make the app so dumb that I almost never need to push code?"

This is how **Airbnb, Lyft, and Uber** solved it.  
They call it **Server-Driven UI** and **Backend-Driven Logic**.

The app becomes a **runtime** — it knows how to render screens and handle gestures.  
The **backend decides what to show, what rules apply, what actions are allowed.**

---

## THE THREE-TIER MODEL

```
┌─────────────────────────────────────────────────────────┐
│  TIER 1 — UI RUNTIME (Flutter App)                      │
│  What it does: renders, animates, handles input         │
│  What it does NOT: make decisions                       │
└─────────────────────────────────────────────────────────┘
                          ↕  API
┌─────────────────────────────────────────────────────────┐
│  TIER 2 — DECISION LAYER (Go Backend)                   │
│  What it does: all business rules, all decisions        │
│  Returns: structured responses the app renders          │
└─────────────────────────────────────────────────────────┘
                          ↕  queries
┌─────────────────────────────────────────────────────────┐
│  TIER 3 — DATA LAYER (Supabase + Redis)                 │
│  What it does: stores, indexes, streams data            │
└─────────────────────────────────────────────────────────┘
```

The app **never** makes a business decision.  
It asks the backend: **"What should I show? What is allowed?"**  
The backend answers. The app renders.

---

## PART 1 — CURRENT STATE AUDIT

### What I Found in the Codebase

After scanning every key file, here is exactly where business logic currently lives — and what needs to move.

---

### 1.1 — COMPLIANCE DECISIONS IN FLUTTER (HIGH RISK)

**File:** `apps/driver/lib/utils/driver_go_online_policy.dart`

**What it does right now:**
```dart
bool driverHasRequiredNonLicenseInfo(DriverComplianceSnapshot? c, ...) {
  final hasChauffeurspas = _hasText(c.chauffeurspasNumber) && c.chauffeurspasExpiry != null;
  final hasKvk = _hasText(c.kvkNumber) && _hasText(c.kvkAddress);
  final hasInsurance = ...
  return hasChauffeurspas && hasKvk && hasInsurance && hasVehiclePlate && ...
}

bool driverMayGoOnline(DriverComplianceSnapshot? c, ...) {
  return driverHasRequiredNonLicenseInfo(c, ...) && c.rijbewijsVerified == true;
}
```

**The problem:**
- This is **NL-specific compliance logic** hardcoded in the Flutter app
- `chauffeurspas` and `kvk_number` are Dutch-only concepts
- A UK driver has PCO license, DVLA — completely different rules
- You cannot change compliance requirements without a new app release
- Every country you launch requires an app update

**What it should be:**
```
GET /api/v1/driver/readiness
Response:
{
  "can_go_online": false,
  "missing_items": [
    { "key": "kvk", "label": "KVK-nummer vereist", "action": "/driver/documents/kvk" },
    { "key": "rijbewijs", "label": "Rijbewijs nog niet goedgekeurd", "action": null }
  ],
  "compliance_type": "NL",
  "status_summary": "2 items missing before you can go online"
}
```

App renders the checklist. Backend decides what's in it.  
UK driver gets a different list. Nigeria gets a different list. Zero app update.

---

### 1.2 — DOCUMENT VALIDATION IN FLUTTER (NL-SPECIFIC)

**File:** `apps/driver/lib/utils/chauffeurspas_validation.dart`

**What it does right now:**
```dart
ChauffeurspasValidationResult validateChauffeurspasNumber(String input) {
  var cleaned = input.trim().toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
  if (cleaned.startsWith('NL')) { cleaned = cleaned.substring(2); }
  if (!RegExp(r'^\d{8,12}$').hasMatch(cleaned)) {
    return ChauffeurspasValidationResult(
      valid: false,
      error: 'Een chauffeurspas nummer bestaat uit 8 tot 12 cijfers.',
    );
  }
  return ChauffeurspasValidationResult(valid: true, cleaned: cleaned);
}
```

**The problem:**
- Dutch document format baked into app code
- Error message hardcoded in Dutch
- UK, Nigeria, Germany all have different document numbers and formats
- New country = new document type = app update required

**What it should be:**
```
POST /api/v1/driver/document/validate
Body: { "doc_type": "chauffeurspas", "value": "NL12345678" }
Response:
{
  "valid": true,
  "cleaned": "12345678",
  "error": null
}
```

Validation logic lives in Go backend. Country-aware. Updatable without app release.

---

### 1.3 — DRIVER SUPPLY MATCHING IN FLUTTER (CRITICAL)

**File:** `apps/rider/lib/services/nearby_supply_service.dart`

**What it does right now — this is the biggest problem:**
```dart
// Flutter queries Supabase directly with a bounding box
final res = await HeyCabySupabase.client
    .from('driver_locations')
    .select('driver_id, latitude, longitude, updated_at')
    .gte('latitude', pickup.lat - latDelta)
    .lte('latitude', pickup.lat + latDelta)
    ...

// Flutter computes Haversine distance
static double distanceKm(double lat1, double lng1, ...) {
  const earthKm = 6371.0;
  final dLat = _rad(lat2 - lat1);
  ...  // 12 lines of math in Flutter
}

// Flutter applies fare calculation
static double _computeFare({
  required double tripKm,
  required double baseFare,
  required double perKmRate,
}) {
  final raw = baseFare + tripKm * perKmRate;
  return (raw * 10).roundToDouble() / 10;
}

// HARDCODED fallback rates in Flutter
static const double _fallbackBase = 4.25;   // ← EUR, hardcoded
static const double _fallbackPerKm = 1.85;  // ← EUR, hardcoded
static const double searchRadiusKm = 12.0;  // ← hardcoded radius
static const Duration maxLocationAge = Duration(minutes: 3); // ← hardcoded
```

**The problems:**
1. Flutter is doing matching. That's the backend's job.
2. Fallback rates (€4.25 / €1.85) are hardcoded in app code
3. Search radius (12km) is hardcoded — cannot adjust by city demand
4. Location age threshold (3 min) is hardcoded — cannot tune
5. Direct DB query from Flutter bypasses all Redis optimization
6. When you launch in UK, this code doesn't know about GBP or UK drivers

**What it should be:**
```
GET /api/v1/rider/nearby-supply
Query: pickup_lat, pickup_lng, dest_lat, dest_lng, country_code

Response:
{
  "country_code": "NL",
  "currency": "EUR",
  "categories": [
    {
      "category": "standard",
      "driver_count": 4,
      "nearest_km": 1.2,
      "from_price": 8.50,
      "currency": "EUR",
      "drivers": [
        {
          "driver_id": "...",
          "name": "Ahmed",
          "photo_url": "...",
          "rating": 4.9,
          "distance_km": 1.2,
          "estimated_fare": 12.40,
          "return_discount_pct": 15
        }
      ]
    }
  ],
  "search_radius_km": 12.0,
  "config": {
    "no_driver_delay_seconds": 5,
    "search_window_minutes": 10
  }
}
```

App renders what it gets. Backend does the matching via Redis GEO.  
UK users get GBP. NL users get EUR. You can change radius and timing without an app update.

---

### 1.4 — SHIFT MANAGEMENT WRITTEN FROM FLUTTER

**File:** `apps/driver/lib/services/driver_shift_session_service.dart`

**What it does right now:**
```dart
// Flutter writes shift records DIRECTLY to Supabase
await _client.from('driver_shift_sessions').insert({
  'driver_id': driverId,
  'shift_started_at': now,
  'is_active': true,
  'break_reminder_interval_minutes': 120,  // ← hardcoded in Flutter
  'breaks': [],
}).select('id').maybeSingle();

await _client.from('drivers').update({
  'current_shift_id': sessionId,
  'shift_started_at': now,
}).eq('id', driverId);
```

**The problem:**
- Break reminder interval (120 min) is hardcoded in the app
- Flutter is performing a multi-step write (insert + update) — no atomicity
- If either write fails, state is inconsistent
- Cannot change shift rules without an app release

**What it should be:**
```
POST /api/v1/driver/shift/start
Response: { "shift_id": "...", "started_at": "...", "break_reminder_minutes": 120 }

POST /api/v1/driver/shift/end
Response: { "total_online_minutes": 240, "rides_completed": 8, "earnings": 145.50 }
```

Backend handles the atomic write. Break rules come from country config.

---

### 1.5 — HARDCODED TIMING CONSTANTS IN FLUTTER

**Files:**
- `apps/rider/lib/constants/rider_search_window.dart` → `Duration(minutes: 10)`
- `apps/rider/lib/constants/rider_matching_ui.dart` → `Duration(seconds: 5)`
- `apps/rider/lib/constants/rider_near_term_window.dart` → `Duration(hours: 48)`

These control how long the app searches for a driver, when it shows alternatives, and when it shows the "upcoming ride" banner. All hardcoded. None adjustable without an app update.

These must come from the backend config response on app boot.

---

### 1.6 — HARDCODED URLS IN APP (COMPILE-TIME)

**File:** `packages/heycaby_api/lib/src/app_public_config.dart`

```dart
const String kAppPublicWebOrigin = String.fromEnvironment(
  'APP_PUBLIC_WEB_ORIGIN',
  defaultValue: 'https://heycaby.nl',  // ← baked in at compile time
);
```

These are compile-time dart-define constants — baked into the binary.  
Cannot be changed after build. Fine for the base URL, but any business-facing URL should be served dynamically.

---

### 1.7 — WHAT'S ALREADY CORRECT (KEEP THESE PATTERNS)

**`TripCategoryPricingService`** — calls Supabase RPC, no hardcoding. Good.  
**`DriverApi`** — HTTP client that calls `/api/driver/...`. Right pattern.  
**`driver_platform_fee_gate.dart`** — reads fee from backend, renders what it gets. Good.  
**`fn_estimate_trip_category_prices`** — pricing runs in database function. Good.

---

## PART 2 — THE TARGET DESIGN

### The App Runtime Contract

The Flutter app should only know how to:
1. Render pre-designed screens
2. Display data it receives from the backend
3. Send user actions (taps, inputs) to the backend
4. Receive decisions back and render them

The app should **never** contain:
- If-else logic for compliance rules
- Pricing calculations
- Country-specific document validation
- Hardcoded search windows, radii, or timeouts
- Direct database queries for business data

---

### 2.1 — THE BOOT CONFIG API

Every time the app starts (or resumes), it fetches a boot config. This config drives the entire session.

```
GET /api/v1/config
Headers: Authorization: Bearer {supabase_jwt}

Response:
{
  "country_code": "NL",
  "currency": "EUR",
  "currency_symbol": "€",
  "min_app_version": "1.2.0",
  "force_update": false,
  "search": {
    "driver_search_window_minutes": 10,
    "no_driver_card_delay_seconds": 5,
    "near_term_scheduled_window_hours": 48,
    "max_search_radius_km": 12.0,
    "driver_location_max_age_minutes": 3
  },
  "feature_flags": {
    "marketplace_enabled": true,
    "radar_enabled": true,
    "community_hub_enabled": true,
    "scheduled_rides_enabled": true,
    "return_trips_enabled": true
  },
  "support": {
    "driver_help_url": "https://heycaby.nl/help/drivers",
    "rider_help_url": "https://heycaby.nl/help/riders"
  },
  "legal": {
    "terms_url": "https://heycaby.nl/terms",
    "privacy_url": "https://heycaby.nl/privacy"
  }
}
```

**What this replaces:**
- `kRiderDriverSearchWindow` → `config.search.driver_search_window_minutes`
- `kRiderNoDriverCardDelay` → `config.search.no_driver_card_delay_seconds`
- `kRiderNearTermScheduledWindow` → `config.search.near_term_scheduled_window_hours`
- `NearbySupplyService.searchRadiusKm` → `config.search.max_search_radius_km`
- `NearbySupplyService.maxLocationAge` → `config.search.driver_location_max_age_minutes`
- `kAppPublicWebOrigin` (partially) → `config.legal.*`, `config.support.*`
- Feature toggles → `config.feature_flags.*`

App boots. Gets config. Caches it (5 min TTL in memory). Renders accordingly.  
You can change any of these values without pushing an app update.

---

### 2.2 — THE DRIVER READINESS API

Replaces `driver_go_online_policy.dart` and the checklist in `go_online_screen.dart`.

```
GET /api/v1/driver/readiness
Headers: Authorization: Bearer {driver_jwt}

Response (NL driver, missing items):
{
  "can_go_online": false,
  "compliance_type": "NL",
  "checklist": [
    { "key": "profile_photo",   "label": "Profielfoto",           "complete": true,  "action": null },
    { "key": "vehicle_photo",   "label": "Voertuigfoto",          "complete": true,  "action": null },
    { "key": "chauffeurspas",   "label": "Chauffeurspas",         "complete": true,  "action": "/driver/documents" },
    { "key": "kvk",             "label": "KVK-nummer",            "complete": false, "action": "/driver/documents/kvk" },
    { "key": "rijbewijs",       "label": "Rijbewijs goedkeuring", "complete": false, "action": null, "note": "In beoordeling door ops" },
    { "key": "terms",           "label": "Voorwaarden",           "complete": true,  "action": null },
    { "key": "indemnification", "label": "Vrijwaring",            "complete": true,  "action": null }
  ],
  "missing_count": 2,
  "status_message": "2 stappen om online te gaan"
}
```

Same call for a UK driver:
```json
{
  "can_go_online": false,
  "compliance_type": "UK",
  "checklist": [
    { "key": "pco_license",  "label": "PCO Licence",   "complete": false, "action": "/driver/documents/pco" },
    { "key": "dvla",         "label": "DVLA Check",    "complete": true,  "action": null },
    { "key": "insurance",    "label": "Insurance",     "complete": false, "action": "/driver/documents/insurance" }
  ]
}
```

**App renders the same checklist component. Backend decides what's in the list.**  
Zero app update when adding new document requirements to any country.

---

### 2.3 — THE DOCUMENT VALIDATION API

Replaces `chauffeurspas_validation.dart` and any other country-specific validation.

```
POST /api/v1/driver/document/validate
Body:
{
  "doc_type": "chauffeurspas",
  "value": "NL12345678",
  "country_code": "NL"
}

Response (valid):
{ "valid": true, "cleaned": "12345678", "error": null }

Response (invalid):
{ "valid": false, "cleaned": "12345678", "error": "Chauffeurspas moet 8–12 cijfers bevatten." }
```

Go backend contains all validation rules per country and document type.  
Error messages can be localized server-side per `Accept-Language` header.

---

### 2.4 — THE NEARBY SUPPLY API

Replaces all of `nearby_supply_service.dart` — the biggest logic removal from Flutter.

```
GET /api/v1/rider/nearby-supply
Query params:
  pickup_lat=51.9225
  pickup_lng=4.4792
  dest_lat=52.3676    (optional)
  dest_lng=4.9041     (optional)

Headers: Authorization: Bearer {rider_jwt}

Response:
{
  "country_code": "NL",
  "currency": "EUR",
  "search_radius_km": 12.0,
  "categories": [
    {
      "category": "standard",
      "label": "Standard",
      "icon": "car",
      "driver_count": 3,
      "nearest_km": 1.4,
      "from_price": 9.50,
      "currency": "EUR",
      "drivers": [
        {
          "driver_id": "abc-123",
          "name": "Hassan",
          "photo_url": "https://...",
          "rating": 4.87,
          "distance_km": 1.4,
          "estimated_fare": 12.40,
          "currency": "EUR",
          "return_discount_pct": 20,
          "return_discount_fare": 9.90
        }
      ]
    },
    {
      "category": "xl",
      "driver_count": 1,
      ...
    }
  ]
}
```

**Go backend:**
1. Detects country from JWT → selects correct Redis GEO set (`drivers:NL`)
2. Runs Redis `GEORADIUS` for fast spatial query
3. Fetches driver profiles from Supabase (or Redis cache)
4. Computes fares using CountryConfig rates (not hardcoded)
5. Returns structured response

**Fallback rates** (`_fallbackBase = 4.25`, `_fallbackPerKm = 1.85`) move to `country_config.NL.fallback_base_fare` in `app_config`. Configurable without any build.

---

### 2.5 — THE SHIFT MANAGEMENT API

Replaces `driver_shift_session_service.dart`.

```
POST /api/v1/driver/shift/start
Headers: Authorization: Bearer {driver_jwt}
Response:
{
  "shift_id": "uuid",
  "started_at": "2026-04-27T08:00:00Z",
  "break_reminder_minutes": 120,
  "country_code": "NL"
}

POST /api/v1/driver/shift/break/start
POST /api/v1/driver/shift/break/end

POST /api/v1/driver/shift/end
Response:
{
  "shift_id": "uuid",
  "ended_at": "2026-04-27T16:00:00Z",
  "total_online_minutes": 480,
  "total_break_minutes": 30,
  "rides_completed": 12,
  "earnings": 198.50,
  "currency": "EUR"
}
```

Backend performs atomic DB writes. App receives result and renders.  
Break reminder interval comes from `country_config.NL.break_reminder_minutes`. Country-configurable.

---

### 2.6 — THE DRIVER STATUS API (GOING ONLINE/OFFLINE)

Current flow has multiple steps across app, Supabase, and the gate service.  
Collapse it to a single backend call.

```
POST /api/v1/driver/status
Body: { "status": "available", "lat": 51.9225, "lng": 4.4792 }

Response (success):
{
  "status": "available",
  "shift_id": "uuid",
  "country_code": "NL"
}

Response (blocked — payment required):
{
  "status": "offline",
  "blocked_reason": "payment_required",
  "payment_url": "https://payment.mollie.com/...",
  "weekly_fee_cents": 3000,
  "currency": "EUR"
}

Response (blocked — compliance):
{
  "status": "offline",
  "blocked_reason": "compliance_incomplete",
  "redirect": "/driver/readiness"
}
```

Backend checks: compliance → payment → then sets status.  
App receives one of three outcomes: success, payment needed, compliance needed.  
No decision logic in Flutter at all.

---

### 2.7 — THE RIDE LIFECYCLE API

All ride state transitions go through Go backend, not direct Supabase writes.

```
Driver endpoints:
  POST /api/v1/driver/ride/{ride_id}/accept
  POST /api/v1/driver/ride/{ride_id}/arrived
  POST /api/v1/driver/ride/{ride_id}/start
  POST /api/v1/driver/ride/{ride_id}/complete
  POST /api/v1/driver/ride/{ride_id}/cancel

Rider endpoints:
  POST /api/v1/rider/ride/request       (create ride request)
  POST /api/v1/rider/ride/{id}/cancel
  GET  /api/v1/rider/ride/{id}/status   (polling fallback)
```

Each endpoint:
1. Validates state transition (backend decides if it's allowed)
2. Writes atomically to Supabase
3. Updates Redis state
4. Sends FCM notification
5. Returns new state to caller

No multi-step writes from Flutter. No race conditions. No duplicate acceptance bugs.

---

## PART 3 — WHAT STAYS IN FLUTTER

These things belong in the app and should never move to backend:

| Flutter Keeps | Reason |
|---|---|
| GPS location tracking | Native device API — can't be remote |
| Map rendering (Mapbox) | Client-side rendering library |
| Camera (document photos) | Native hardware |
| Push notification receipt | Device-bound |
| Animation and transitions | UI layer |
| Offline state (no internet UX) | Cannot reach backend |
| Local storage (draft bookings) | UX only, not business |
| Audio (ride request sound) | Hardware |

---

## PART 4 — THE IMPLEMENTATION PLAN

### Phase 1 — Boot Config (Lowest Risk, Highest Gain)

**Build `GET /api/v1/config` first.** This is the safest change.

In Flutter, create a `RemoteConfigService`:
```dart
class RemoteConfigService {
  static AppConfig? _cached;
  static DateTime? _cachedAt;
  
  static Future<AppConfig> fetch(String jwtToken) async {
    if (_cached != null && DateTime.now().difference(_cachedAt!) < Duration(minutes: 5)) {
      return _cached!;
    }
    final response = await dio.get('/api/v1/config');
    _cached = AppConfig.fromJson(response.data);
    _cachedAt = DateTime.now();
    return _cached!;
  }
}
```

Then replace every hardcoded constant:
```dart
// Before:
const kRiderDriverSearchWindow = Duration(minutes: 10);

// After:
final config = await RemoteConfigService.fetch(jwt);
final searchWindow = Duration(minutes: config.search.driverSearchWindowMinutes);
```

**Risk: Zero.** You're just moving constants from compiled code to a JSON response.

---

### Phase 2 — Driver Readiness API

Replace `driver_go_online_policy.dart` with a backend call.

In Go backend, build the readiness engine:
```go
// internal/service/driver_service/readiness.go
func (s *DriverService) GetReadiness(ctx context.Context, driverID, countryCode string) (*ReadinessResponse, error) {
    config := s.countryConfig[countryCode]
    driver := s.repo.GetDriverCompliance(ctx, driverID)
    
    checklist := []ChecklistItem{}
    for _, required := range config.RequiredDocs {
        item := buildChecklistItem(required, driver)
        checklist = append(checklist, item)
    }
    
    canGoOnline := allComplete(checklist)
    return &ReadinessResponse{
        CanGoOnline:     canGoOnline,
        ComplianceType:  countryCode,
        Checklist:       checklist,
    }, nil
}
```

In Flutter, replace `driverMayGoOnline()` call with:
```dart
final readiness = await driverApi.getReadiness();
final canGoOnline = readiness.canGoOnline;
final checklist = readiness.checklist;
```

**Risk: Low.** The decision outcome is the same — just computed on the server now.

---

### Phase 3 — Nearby Supply API (Biggest Win)

Replace `NearbySupplyService.loadForPickup()` with a backend API call.

The Flutter side becomes:
```dart
class NearbySupplyService {
  static Future<NearbySupplyResponse> loadForPickup({
    required double pickupLat,
    required double pickupLng,
    double? destLat,
    double? destLng,
  }) async {
    final response = await riderApi.getNearbySupply(
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      destLat: destLat,
      destLng: destLng,
    );
    return NearbySupplyResponse.fromJson(response);
  }
}
```

That's it. 200 lines of matching, geo math, and fare calculation in Flutter → 10 lines of API call.

The rest lives in Go backend hitting Redis.

**Risk: Medium.** Test thoroughly. Keep the old implementation behind a feature flag:
```dart
if (config.featureFlags.useGoNearbySupply) {
  return await _fetchFromBackend();
} else {
  return await _fetchFromSupabaseDirect(); // old path
}
```

Flip the flag gradually. Monitor errors. Remove old path when stable.

---

### Phase 4 — Document Validation API

Replace `chauffeurspas_validation.dart` with backend validation.

Flutter sends the value to validate. Backend responds with valid/invalid + error message.  
The app just shows whatever error message it gets back. Fully localizable from server.

**Risk: Low.** Validation is a request/response — easy to test.

---

### Phase 5 — Shift Management API

Replace `DriverShiftSessionService` with backend calls.

**Risk: Low-Medium.** This is currently multi-step — backend handles it atomically. Better than before.

---

### Phase 6 — Document Validation + Go Online Flow Merge

Collapse the full "go online" flow:
1. App taps "Go Online"
2. Single call: `POST /api/v1/driver/status { "status": "available" }`
3. Backend does all checks (compliance → payment → shift start → set status)
4. Returns outcome
5. App renders

**Risk: Medium.** Touches the core driver flow. Heavy testing required.

---

## PART 5 — DATA FLOW DIAGRAM (AFTER SEPARATION)

### Rider Books a Ride

```
Rider taps "Book"
       ↓
Flutter: GET /api/v1/rider/nearby-supply?lat=...&lng=...
       ↓
Go Backend:
  1. Get country_code from JWT
  2. Query Redis GEORADIUS drivers:NL
  3. Fetch driver profiles (cache hit → Redis, miss → Supabase)
  4. Compute fares (from CountryConfig)
  5. Return structured JSON
       ↓
Flutter renders driver cards (no pricing logic in Flutter)
       ↓
Rider selects driver + taps "Confirm"
       ↓
Flutter: POST /api/v1/rider/ride/request
  { driver_id, pickup, destination, vehicle_category, payment_method }
       ↓
Go Backend:
  1. Validate request
  2. Write ride_request to Supabase (with country_code + currency)
  3. Set Redis ride state
  4. Send FCM push to driver
  5. Return { ride_request_id, status: "searching" }
       ↓
Flutter listens to Supabase Realtime for ride_request status updates
(Supabase Realtime stays — it's great for this)
```

---

### Driver Goes Online

```
Driver taps "Go Online"
       ↓
Flutter: POST /api/v1/driver/status { status: "available", lat, lng }
       ↓
Go Backend:
  1. Validate JWT → get driver_id, country_code
  2. Check readiness (compliance complete?)
     → No → return { blocked_reason: "compliance_incomplete" }
  3. Check platform fee (payment due?)
     → Yes → return { blocked_reason: "payment_required", payment_url }
  4. Start shift session (atomic write to driver_shift_sessions + drivers)
  5. Update driver status in Supabase
  6. Write to Redis GEO: GEOADD drivers:NL lng lat driver_id
  7. Return { status: "available", shift_id }
       ↓
Flutter renders "You're online" screen
```

---

## PART 6 — WHAT YOU CAN CHANGE WITHOUT APP UPDATE (AFTER THIS)

After implementing this separation, you can change the following **from `app_config` alone**, with zero app update, zero user disruption:

| Setting | Old | New |
|---|---|---|
| Driver search window | Hardcoded 10 min | Remote: any value |
| No-driver card delay | Hardcoded 5 sec | Remote: per city/demand |
| Nearby supply radius | Hardcoded 12km | Remote: per country |
| Location max age | Hardcoded 3 min | Remote |
| Fallback base fare | Hardcoded €4.25 | Remote: per country |
| Fallback per-km rate | Hardcoded €1.85 | Remote: per country |
| Break reminder interval | Hardcoded 120 min | Remote: per country |
| Required compliance docs | Hardcoded NL rules | Remote: per country |
| Document error messages | Hardcoded Dutch | Remote: per language |
| Feature flags | Recompile required | Remote: instant toggle |
| Support URLs | Compile-time dart-define | Remote |
| Min app version / force update | Not possible | Remote |
| UK vs NL pricing rules | New app build | Remote config |
| Scheduled ride window (48h) | Hardcoded | Remote |

---

## PART 7 — SUMMARY

**Today:** Flutter is making compliance decisions, computing fares, querying the database directly, and running country-specific validation in Dart code.

**After this plan:** Flutter renders. The backend decides. The separation is clean.

Every country you launch, every compliance rule you change, every pricing adjustment, every timing tweak — happens in the backend. Not in an app update.

The app becomes a runtime. The backend is the product.

This is how Uber, Lyft, and Grab operate at global scale. The apps are thin clients. The intelligence lives on the server.

---

*This document covers business logic separation only. For infrastructure scaling, Redis integration, and multi-country DB schema, see `NEW-BACKEND-PLAN-SCALABLE.md`.*
