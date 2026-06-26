# 🏗️ HEYCABBY — COMPLETE GLOBAL TAXI INFRASTRUCTURE PYRAMID (UBER / BOLT STANDARD)

## 🇳🇱 OPERATING MODE (NEXT 6 MONTHS): NETHERLANDS-FIRST, GLOBAL-READY

This is the active execution mode for HeyCaby right now:

- Launch and optimize only in Netherlands cities first:
  - Rotterdam
  - Amsterdam
  - Eindhoven
  - Utrecht
  - Amersfoort
  - Hengelo
  - Breda
  - Dordrecht
- Keep architecture global-ready so expansion later is "turn on", not rebuild.

### Core principle

Build once, activate by config:

- Backend logic stays shared.
- Country/city behavior comes from data + feature flags.
- New market rollout should be a controlled activation sequence, not new core code.

---

## ✅ WHAT MUST STAY NL-FOCUSED NOW (WITHOUT BREAKING GLOBAL READINESS)

- Production traffic and operations: Netherlands only.
- Country defaults: `NL`, `EUR`, Dutch compliance paths.
- Rollout flags for non-NL markets: OFF by default.
- City activation: only NL target cities marked active for launch wave.

---

## ✅ WHAT MUST REMAIN GLOBAL-READY NOW

- `country_code` on all core operational tables.
- Currency-aware ride/payment/receipt schema.
- Country config in `app_config` (`country_config.NL`, `country_config.UK`, etc.).
- Feature flags for backend routing and migration control.
- Region-aware backend middleware and repositories (never mix countries).
- Redis keying by country/city strategy for future split.

---

## 🚀 "TURN-ON" CHECKLIST (NEW CITY / COUNTRY WITHOUT REBUILD)

Use this when enabling London, Sweden, or any new market later.

### A) Data activation (no app release required)

1. Add/activate target city row in `cities` with proper:
   - `country_code`
   - `timezone`
   - `currency`
2. Seed/activate `bubble_zones` (or service zones) for that city.
3. Confirm zone-country linkage and indexes are healthy.

### B) Country configuration activation

1. Ensure `country_config.<CODE>` exists in `app_config`.
2. Validate required docs/compliance list for that country.
3. Validate pricing and matching radius values.

### C) Backend activation

1. Keep core routes unchanged (`/api/v1/...` contract stable).
2. Confirm region resolution returns correct country for city requests.
3. Enable feature flags gradually (internal -> canary -> full):
   - `use_go_driver_locations`
   - `use_redis_locations`
   - `use_go_matching`
   - `use_go_ride_service` (when ready)

### D) Operational safety checks

1. `GET /health` and `GET /health/ready` pass expected criteria.
2. Dark-run script passes:
   - `scripts/dark_run_backend_checks.sh`
3. Verify role guards and endpoint behavior for rider/driver auth.
4. Run scenario matrix on real devices before public launch in that market.

### E) Go-live gate for new market

Only switch market to active when all are true:

- Data seeded and validated
- Country config validated
- Realtime matching stable
- Payment/receipt currency correct
- QA matrix pass with no P0 failures

---

## 🌍 FULL SYSTEM BLUEPRINT (WITH LOCATION, MAPBOX, MULTI-COUNTRY, CITY ARCHITECTURE, GLOBAL SCALE)

Excellent catch — you’re absolutely right.

Your previous architecture was missing one of the most critical systems:

# 📍 LOCATION INTELLIGENCE LAYER

For a real Uber/Bolt-grade platform, location is not “just maps.”

Location is actually split into multiple systems:

---

# 🧠 LOCATION HAS 3 DIFFERENT JOBS:

---

## 1️⃣ STATIC LOCATION DATA (Countries / Cities / Zones / Pricing Regions)

### Stored in:

# 🗄 SUPABASE (Primary Global Location Database)

This is your master global expansion system.

---

### Example:

```plaintext id="gmw93l"
Countries:
- Netherlands
- UK
- Ireland
- Sweden
- Nigeria
- Ghana

Cities:
- Rotterdam
- Amsterdam
- Utrecht
- London
- Manchester
- Dublin
- Stockholm
```

---

### Why Supabase?

Because this data is:
✅ Structured
✅ Permanent
✅ Searchable
✅ Expandable
✅ Admin-manageable

---

# Example DB Tables:

### countries

```plaintext id="v2uxkj"
id
name
country_code
currency
tax_rules
driver_plan_rules
status
```

---

### cities

```plaintext id="uv5tq2"
id
country_id
city_name
state_region
timezone
market_status
pricing_zone
```

---

### service_zones

```plaintext id="9h4a7n"
id
city_id
zone_name
polygon_coordinates
ride_rules
surge_rules
```

---

# 🚖 This becomes your:

### Global Expansion Brain

---

# 2️⃣ LIVE DRIVER / RIDER LOCATION (REAL-TIME)

### Stored in:

# ⚡ REDIS GEO

This is NOT your permanent city database.

This is:

### Real-time movement only

---

### Redis stores:

✅ Driver live coordinates
✅ Rider request coordinates
✅ Nearby drivers
✅ Driver availability
✅ Live geo-radius matching

---

### Example:

```plaintext id="0r4g5t"
Driver 248:
Lat: 51.9225
Lng: 4.47917
Status: Available
City: Rotterdam
```

---

# Redis = “Where are you right now?”

---

# 3️⃣ MAP + ROUTING + NAVIGATION

### Powered by:

# 🗺 MAPBOX

Because you use Mapbox instead of Google.

---

# MAPBOX handles:

✅ Address autocomplete
✅ Geocoding
✅ Reverse geocoding
✅ Routing
✅ Distance matrix
✅ ETA
✅ Navigation
✅ Traffic
✅ Route optimization

---

### Example:

Rider types:

### “Amsterdam Central”

Mapbox converts:

```plaintext id="zw2nzg"
Lat / Lng
Validated address
Region
City
Country
```

---

# 🚨 IMPORTANT:

Mapbox is NOT your database.

### Mapbox = Navigation + Search Tool

### Supabase = Global Location Memory

### Redis = Live Movement

---

# 🔺 FINAL COMPLETE HEYCABBY PYRAMID

```plaintext id="u5x8kh"
                                           🔺 USER EXPERIENCE LAYER 🔺
----------------------------------------------------------------------------------------------------------------
|                                                                                                              |
|                          FLUTTER RIDER APP + FLUTTER DRIVER APP                                             |
|                                                                                                              |
| Rider: Book Ride | Marketplace | Schedule | Track | Pay | Rate                                               |
| Driver: Go Online | Accept | Navigate | Arrive | Start | Complete | Earnings                                |
|                                                                                                              |
----------------------------------------------------------------------------------------------------------------
                                                     │
                                                     ▼

                                           🌐 WEB / ACCESS LAYER 🌐
----------------------------------------------------------------------------------------------------------------
|                                                                                                              |
|                                      VERCEL (Website + Onboarding + Admin)                                  |
|                                                                                                              |
| Driver Signup | Landing Pages | QR Pages | Driver Dashboard | Admin Dashboard                               |
|                                                                                                              |
----------------------------------------------------------------------------------------------------------------
                                                     │
                                                     ▼

                                          🧠 CORE BUSINESS BRAIN 🧠
----------------------------------------------------------------------------------------------------------------
|                                                                                                              |
|                                        GO BACKEND (AWS HOSTED)                                               |
|                                                                                                              |
| Ride Logic | Driver Matching | Marketplace | Pricing | Billing | Founding Logic | Multi-Country Logic       |
| Cancellation | Scheduling | Dispatch | Driver Plans | Ride State Machine | Notifications                    |
|                                                                                                              |
----------------------------------------------------------------------------------------------------------------
                        │                                  │                                  │
                        ▼                                  ▼                                  ▼

            📍 GLOBAL LOCATION LAYER              ⚡ REAL-TIME MOVEMENT LAYER           🗺 NAVIGATION LAYER
----------------------------------------------------------------------------------------------------------------
|                                                                                                              |
| SUPABASE (Countries/Cities/Zones):             REDIS GEO:                           MAPBOX:                  |
| ✅ Countries                                    ✅ Driver live location               ✅ Address search          |
| ✅ Cities                                       ✅ Rider live location                ✅ Routing                |
| ✅ Service zones                                ✅ Availability                       ✅ ETA                    |
| ✅ Pricing zones                                ✅ Dispatch speed                     ✅ Traffic                |
| ✅ Country configs                              ✅ Ride locks                         ✅ Navigation             |
|                                                                                                              |
----------------------------------------------------------------------------------------------------------------
                        │                                  │                                  │
                        ▼                                  ▼                                  ▼

                                           🗄 CORE DATA + OPERATIONS LAYER 🗄
----------------------------------------------------------------------------------------------------------------
|                                                                                                              |
| SUPABASE CORE:                                                                                                |
| ✅ Auth                                                                                                       |
| ✅ Drivers                                                                                                    |
| ✅ Riders                                                                                                     |
| ✅ Rides History                                                                                              |
| ✅ Verification                                                                                                |
| ✅ Payments                                                                                                    |
| ✅ Plans                                                                                                       |
| ✅ Founding Program                                                                                           |
| ✅ Compliance                                                                                                  |
|                                                                                                              |
----------------------------------------------------------------------------------------------------------------
                                                     │
                                                     ▼

                                           ☁️ INFRASTRUCTURE LAYER ☁️
----------------------------------------------------------------------------------------------------------------
|                                                                                                              |
| AWS                                                                                                          |
| ✅ Go Hosting                                                                                                 |
| ✅ Redis Hosting                                                                                              |
| ✅ Load Balancers                                                                                             |
| ✅ Monitoring                                                                                                 |
| ✅ Logs                                                                                                       |
| ✅ Security                                                                                                   |
| ✅ Regional Expansion                                                                                         |
|                                                                                                              |
----------------------------------------------------------------------------------------------------------------
```

---

# 🌍 GLOBAL COUNTRY EXPANSION LOGIC

---

## Example:

### Netherlands

* Rotterdam
* Amsterdam
* Utrecht
* Den Haag

### UK

* London
* Manchester
* Birmingham

### Ireland

* Dublin
* Cork

---

# Each country should have:

✅ Local currency
✅ Pricing plans
✅ Driver compliance
✅ Zone rules
✅ Surge logic
✅ Taxes

---

# 🚖 FULL TAXI COMPANY REQUIREMENTS (UBER/BOLT STANDARD)

---

## Must Include:

### Rider:

✅ Book now
✅ Schedule
✅ Marketplace
✅ Multi-stop
✅ Cancel
✅ Chat
✅ Call
✅ Driver tracking

---

### Driver:

✅ Availability
✅ Accept/Decline
✅ Route
✅ Earnings
✅ Driver plans
✅ Ratings
✅ Driver zones

---

### Admin:

✅ Country launch
✅ City launch
✅ Driver compliance
✅ Pricing
✅ Promotions
✅ Fraud detection

---

# 🔥 MASTER SYSTEM FORMULA

## Flutter = Experience

## Vercel = Access

## Go = Brain

## Supabase = Global Memory

## Redis = Real-Time Speed

## Mapbox = Navigation Intelligence

## AWS = Global Foundation

---

# 🛑 CRITICAL RULE

### If you want global scale:

Location must NEVER live in one place only.

---

# CORRECT:

### Cities/Countries → Supabase

### Live movement → Redis

### Navigation → Mapbox

---

# 🏁 FINAL END GOAL

This is no longer “just an app.”

### This is:

# A GLOBAL MOBILITY OPERATING SYSTEM

Built to scale from:

### Rotterdam → Netherlands → Europe → Africa → Global

---
