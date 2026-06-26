# NEW-BACKEND-PLAN-SCALABLE
## HeyCaby — Uber-Grade Backend Redesign & Global Scale Execution Plan

**Created:** 2026-04-27  
**Author:** Architecture Review (Claude Code)  
**Status:** READ-ONLY PLAN — No changes made to production

---

## PART 1 — CURRENT STATE AUDIT

### Progress Update (2026-04-28)

- Step 1.9 performance index rollout has been applied and verified on live Supabase.
- Applied indexes:
  - `idx_drivers_profile_status` on `drivers(profile_status)`
  - `idx_ride_requests_rider_id_created` on `ride_requests(rider_id, created_at DESC)`
  - `idx_notifications_user_id_read` on `notifications(user_id, read_at, created_at DESC)`
- Schema note: `notifications.read_at` is used (not `is_read`) to match production schema.
- Migration synced in repo:
  - `supabase/migrations/20260428175500_scale_add_remaining_perf_indexes_v2.sql`

### What You Have (Supabase: HEYCABY-TAXI)

**Region:** eu-west-1 (Ireland)  
**Database:** PostgreSQL 17 on Supabase  
**Tables:** 84 tables, all with RLS enabled  
**Functions:** 100+ custom PL/pgSQL functions and triggers  

### Architecture Right Now

```
Flutter Apps (Driver + Rider)
         ↓
Supabase (PostgREST + Auth + Realtime)
         ↓
PostgreSQL (all logic lives here)
         ↓
PostGIS (geo queries for zones)
```

### Critical Gaps Found (What's Missing for Scale)

| Gap | Impact | Priority |
|-----|--------|----------|
| No `country_code` on any table | Cannot route NL vs UK vs NG traffic | CRITICAL |
| `cities` table has no country link | Cities are floating, not country-bound | CRITICAL |
| No `currency` field on `ride_requests` | EUR is hardcoded by assumption | CRITICAL |
| No Go backend | Flutter hits Supabase directly — no business logic layer | CRITICAL |
| No Redis | Driver matching runs on PostgreSQL — cannot scale past ~500 concurrent drivers | CRITICAL |
| No country config system | Pricing, fees, rules are hardcoded in app or DB functions | HIGH |
| No API versioning | Breaking the schema breaks all live app users instantly | HIGH |
| `app_config` only has 5 rows | No remote feature flags, no country configs | HIGH |
| KVK number is hardcoded to drivers | NL-specific compliance baked in, not configurable | MEDIUM |
| Matching logic is in Supabase functions | `fn_get_nearby_drivers_by_category`, `fn_scan_radar_matches` — all in Postgres | MEDIUM |

### What You Have That's Already Good

- PostGIS installed and working (`bubble_zones.geom`)
- `cities` table exists — foundational for multi-city
- `service_cities` array on `drivers` — already city-scoped
- `rate_currency` on `drivers` table — currency awareness exists
- `driver_locations` table — can be migrated to Redis
- `bubble_zones` → `zone_neighbors` → zone adjacency system — solid geo model
- `vehicle_category_config` + `vehicle_category_base_rates` — configurable rates
- Comprehensive trust/rating system (`driver_trust_scores`)
- Strong RLS security on 83/84 tables
- `notification_campaigns` + lifecycle system — production-grade

---

## PART 2 — TARGET ARCHITECTURE

### What You're Building

```
Flutter Apps (Driver + Rider)
         ↓
Go Backend — Fiber (modular monolith)
         ↓
┌────────────────────────────────────┐
│       Country Config Layer         │
│   NL: EUR, rules, compliance       │
│   UK: GBP, rules, compliance       │
│   NG: NGN, rules, compliance       │
└────────────────────────────────────┘
         ↓                ↓
Supabase (Postgres)    Redis (per region)
         ↓                ↓
PostGIS (zones)        GEO matching
         ↓
Firebase FCM (notifications)
```

### Go Backend Internal Structure

```
cmd/
  main.go
internal/
  handler/          ← HTTP handlers (thin, no logic)
  service/
    ride_service/
    driver_service/
    matching_service/
    notification_service/
    config_service/
  repository/       ← Supabase/Postgres queries
  cache/            ← Redis layer
  middleware/
    auth/
    region/         ← detect country from request
  config/           ← country config loader
  queue/            ← job queue (Redis-based)
```

---

## PART 3 — EXECUTION PLAN (A TO Z)

### PHASE 0 — PREPARE (Do This First, No Risk)

**Goal:** Set up tooling and safety nets before touching anything live.

---

#### STEP 0.1 — Enable Database Backups (Supabase)
- Go to Supabase Dashboard → Project Settings → Database
- Confirm Point-in-Time Recovery (PITR) is ON
- Take a manual snapshot before any migration
- **Zero risk. Do this today.**

---

#### STEP 0.2 — Set Up API Versioning in Go (Before Writing Any Routes)
Every endpoint must be versioned from day one:
```
/api/v1/rides        ← current app uses this forever
/api/v2/rides        ← new backend logic, new app versions
```
Rule: Old app versions on v1 must NEVER break.  
Implement this as a router group in Fiber before writing a single handler.

---

#### STEP 0.3 — Create Country Config System in `app_config`

Add rows to `app_config` table (NO schema change needed — it's already key/value):

```sql
-- Run these INSERTs (safe, additive only)
INSERT INTO app_config (key, value) VALUES
('country_config.NL', '{
  "currency": "EUR",
  "currency_symbol": "€",
  "weekly_fee": 30,
  "min_earning_before_fee": 100,
  "matching_radius_km": 5,
  "compliance_type": "NL",
  "required_docs": ["kvk", "chauffeurspas", "rijbewijs", "vog", "taxidiploma"]
}'),
('country_config.UK', '{
  "currency": "GBP",
  "currency_symbol": "£",
  "weekly_fee": 30,
  "min_earning_before_fee": 100,
  "matching_radius_km": 5,
  "compliance_type": "UK",
  "required_docs": ["dvla", "pco_license", "insurance"]
}'),
('country_config.NG', '{
  "currency": "NGN",
  "currency_symbol": "₦",
  "weekly_fee": 5000,
  "min_earning_before_fee": 20000,
  "matching_radius_km": 7,
  "compliance_type": "NG",
  "required_docs": ["driver_license", "vehicle_inspection", "insurance"]
}'),
('feature_flags', '{
  "use_go_matching": false,
  "use_redis_locations": false,
  "force_update_min_version": "1.0.0"
}');
```

This gives you remote config immediately. Zero app update needed. Turn features on/off from here.

---

### PHASE 1 — DATABASE MIGRATIONS (Zero-Downtime, Additive Only)

**Rule:** NEVER drop or rename existing columns. Only ADD new columns. Old app versions keep working.

---

#### STEP 1.1 — Add `country_code` to `cities` table

```sql
ALTER TABLE cities ADD COLUMN IF NOT EXISTS country_code TEXT NOT NULL DEFAULT 'NL';
ALTER TABLE cities ADD COLUMN IF NOT EXISTS timezone TEXT NOT NULL DEFAULT 'Europe/Amsterdam';
ALTER TABLE cities ADD COLUMN IF NOT EXISTS currency TEXT NOT NULL DEFAULT 'EUR';

CREATE INDEX IF NOT EXISTS idx_cities_country_code ON cities (country_code);
```

Then update existing cities:
```sql
UPDATE cities SET country_code = 'NL', timezone = 'Europe/Amsterdam', currency = 'EUR'
WHERE country_code = 'NL'; -- all existing cities are NL
```

---

#### STEP 1.2 — Add `country_code` to `drivers` table

```sql
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS country_code TEXT NOT NULL DEFAULT 'NL';

CREATE INDEX IF NOT EXISTS idx_drivers_country_code ON drivers (country_code);
CREATE INDEX IF NOT EXISTS idx_drivers_country_status ON drivers (country_code, status);
```

All existing drivers are NL. Default is safe.

---

#### STEP 1.3 — Add `country_code` + `currency` to `ride_requests`

```sql
ALTER TABLE ride_requests ADD COLUMN IF NOT EXISTS country_code TEXT NOT NULL DEFAULT 'NL';
ALTER TABLE ride_requests ADD COLUMN IF NOT EXISTS currency TEXT NOT NULL DEFAULT 'EUR';

CREATE INDEX IF NOT EXISTS idx_ride_requests_country_code ON ride_requests (country_code);
```

---

#### STEP 1.4 — Add `country_code` + `currency` to `rides`

```sql
ALTER TABLE rides ADD COLUMN IF NOT EXISTS country_code TEXT NOT NULL DEFAULT 'NL';
ALTER TABLE rides ADD COLUMN IF NOT EXISTS currency TEXT NOT NULL DEFAULT 'EUR';

CREATE INDEX IF NOT EXISTS idx_rides_country_code ON rides (country_code);
```

---

#### STEP 1.5 — Add `country_code` to `bubble_zones`

```sql
ALTER TABLE bubble_zones ADD COLUMN IF NOT EXISTS country_code TEXT;

-- Populate from city relationship
UPDATE bubble_zones bz
SET country_code = c.country_code
FROM cities c
WHERE bz.city_id = c.id;

CREATE INDEX IF NOT EXISTS idx_bubble_zones_country ON bubble_zones (country_code);
```

---

#### STEP 1.6 — Add `country_code` to `driver_locations`

```sql
ALTER TABLE driver_locations ADD COLUMN IF NOT EXISTS country_code TEXT NOT NULL DEFAULT 'NL';

CREATE INDEX IF NOT EXISTS idx_driver_locations_country ON driver_locations (country_code);
```

This is the table that feeds matching. Country-scoping it is critical.

---

#### STEP 1.7 — Add `country_code` to `receipts` and `driver_payment_events`

```sql
ALTER TABLE receipts ADD COLUMN IF NOT EXISTS country_code TEXT NOT NULL DEFAULT 'NL';
ALTER TABLE receipts ADD COLUMN IF NOT EXISTS currency TEXT NOT NULL DEFAULT 'EUR';

ALTER TABLE driver_payment_events ADD COLUMN IF NOT EXISTS country_code TEXT NOT NULL DEFAULT 'NL';
ALTER TABLE driver_payment_events ADD COLUMN IF NOT EXISTS currency TEXT NOT NULL DEFAULT 'EUR';
```

---

#### STEP 1.8 — Add `country_code` to `driver_trust_scores` and `driver_shift_sessions`

```sql
ALTER TABLE driver_trust_scores ADD COLUMN IF NOT EXISTS country_code TEXT NOT NULL DEFAULT 'NL';
ALTER TABLE driver_shift_sessions ADD COLUMN IF NOT EXISTS country_code TEXT NOT NULL DEFAULT 'NL';
```

---

#### STEP 1.9 — Add Performance Indexes (Critical)

These are the queries that run on every ride request. They MUST have indexes:

```sql
-- Driver matching query (runs thousands of times per minute at scale)
CREATE INDEX IF NOT EXISTS idx_driver_locations_country_available
  ON driver_locations (country_code, updated_at DESC)
  WHERE driver_id IS NOT NULL;

-- Ride request lookup by city
CREATE INDEX IF NOT EXISTS idx_ride_requests_pickup_city
  ON ride_requests (pickup_city_id, status, created_at DESC);

-- Driver status lookup by country
CREATE INDEX IF NOT EXISTS idx_drivers_country_status_active
  ON drivers (country_code, status)
  WHERE status IN ('available', 'on_ride');

-- Zone-based driver lookup
CREATE INDEX IF NOT EXISTS idx_driver_locations_zone
  ON driver_locations (zone_id, country_code)
  WHERE zone_id IS NOT NULL;
```

---

### PHASE 2 — BUILD GO BACKEND

**Goal:** Insert a Go layer between Flutter and Supabase. Users don't notice. Everything improves.

---

#### STEP 2.1 — Initialize Go Project

```bash
mkdir heycaby-backend
cd heycaby-backend
go mod init github.com/heycaby/backend
go get github.com/gofiber/fiber/v2
go get github.com/supabase-community/supabase-go
go get github.com/redis/go-redis/v9
go get github.com/golang-jwt/jwt/v5
```

---

#### STEP 2.2 — Build Country Config Service (First Service to Build)

```go
// internal/config/country_config.go
type CountryConfig struct {
    Currency              string   `json:"currency"`
    CurrencySymbol        string   `json:"currency_symbol"`
    WeeklyFee             float64  `json:"weekly_fee"`
    MinEarningBeforeFee   float64  `json:"min_earning_before_fee"`
    MatchingRadiusKm      float64  `json:"matching_radius_km"`
    ComplianceType        string   `json:"compliance_type"`
    RequiredDocs          []string `json:"required_docs"`
}
```

Load from `app_config` table. Cache in memory. Refresh every 5 minutes.  
This is the brain of your country logic. Everything reads from this.

---

#### STEP 2.3 — Build Region Detection Middleware

```go
// internal/middleware/region/region.go
// Detect country from:
// 1. JWT claim (driver/rider already has country_code stored)
// 2. city_id → look up cities.country_code
// 3. IP geolocation (fallback only)
// 4. Request header X-Country-Code (for testing)
```

Every request gets a `country_code` injected into context before it hits a handler.

---

#### STEP 2.4 — Build Auth Middleware (Keep Supabase Auth)

Do NOT replace Supabase Auth. It works. Just validate the JWT in Go:

```go
// internal/middleware/auth/auth.go
// Validate Supabase JWT using the project JWT secret
// Extract user_id, role (driver|rider) into context
// Pass through to handlers
```

Users authenticate with Supabase → Go backend validates the token → proceeds.  
Zero impact on current users.

---

#### STEP 2.5 — Build Repository Layer (Supabase Queries)

```go
// internal/repository/driver_repository.go
// internal/repository/ride_repository.go
// internal/repository/zone_repository.go

// All queries MUST include country_code filter
// Example:
func (r *DriverRepository) GetAvailableDrivers(ctx context.Context, countryCode string, zoneID string) ([]Driver, error) {
    // SELECT * FROM drivers WHERE country_code = $1 AND zone_id = $2 AND status = 'available'
}
```

---

#### STEP 2.6 — Build the Matching Service

This is the most important service. Currently done in Postgres functions (`fn_get_nearby_drivers_by_category`). Move to Go + Redis.

```go
// internal/service/matching_service/matching.go

type MatchingService struct {
    redis  *redis.Client  // region-specific Redis
    repo   *DriverRepository
    config *CountryConfig
}

func (m *MatchingService) FindDrivers(ctx context.Context, req RideRequest) ([]Driver, error) {
    countryCode := req.CountryCode
    
    // 1. Query Redis GEO for drivers within radius
    drivers := m.redis.GeoRadius(ctx, "drivers:"+countryCode, req.PickupLng, req.PickupLat, &redis.GeoRadiusQuery{
        Radius: m.config.MatchingRadiusKm,
        Unit:   "km",
    })
    
    // 2. Filter by availability, vehicle category, acceptance rate
    // 3. Rank by distance, rating, acceptance rate
    // 4. Return top N candidates
}
```

**Ride Locking (prevent double assignment):**
```go
func (m *MatchingService) LockRide(ctx context.Context, rideID string, driverID string) (bool, error) {
    key := "ride_lock:" + rideID
    // SET ride_lock:{rideID} {driverID} NX EX 30
    return m.redis.SetNX(ctx, key, driverID, 30*time.Second).Result()
}
```

---

#### STEP 2.7 — Build Ride Service

```go
// internal/service/ride_service/ride_service.go
// Handles: create ride, accept, start, complete, cancel
// Every action writes to Supabase (permanent) AND Redis (real-time state)
// country_code is ALWAYS written with every ride record
// currency is read from CountryConfig[ride.CountryCode].Currency
```

---

#### STEP 2.8 — Build Driver Location Service

```go
// internal/service/driver_service/location.go

// Driver goes online → write to BOTH Redis AND Supabase
func (s *DriverService) UpdateLocation(ctx context.Context, driverID, countryCode string, lat, lng float64) error {
    // Redis: for matching (fast, ephemeral)
    s.redis.GeoAdd(ctx, "drivers:"+countryCode, &redis.GeoLocation{
        Name:      driverID,
        Longitude: lng,
        Latitude:  lat,
    })
    s.redis.Expire(ctx, "drivers:"+countryCode+":"+driverID, 2*time.Minute)
    
    // Supabase: for audit trail and analytics (async, don't block response)
    go s.repo.UpsertDriverLocation(ctx, driverID, countryCode, lat, lng)
    
    return nil
}
```

---

#### STEP 2.9 — Build Feature Flag Middleware

```go
// internal/middleware/flags/flags.go
// Read feature_flags from app_config (cached)
// Example: if use_go_matching == false → pass through to Supabase function
//          if use_go_matching == true  → use Go matching service
// This lets you flip features without app updates or redeployments
```

---

### PHASE 3 — REDIS SETUP (Per Region)

**Goal:** Move all real-time state (driver locations, ride locks, active matching) out of Postgres into Redis.

---

#### STEP 3.1 — Redis Data Model

```
Key                              Value                    TTL
────────────────────────────────────────────────────────────────
drivers:NL                       GEO sorted set            —
drivers:UK                       GEO sorted set            —
drivers:NL:{driver_id}:online    "1"                      2 min (heartbeat)
drivers:NL:{driver_id}:status    "available"|"on_ride"    2 min
ride_lock:{ride_id}              {driver_id}              30 sec
ride_state:{ride_id}             JSON blob                24 hr
session:{rider_id}               JSON session data        1 hr
```

---

#### STEP 3.2 — Redis Deployment (Phase 1)

Start with a single Redis instance on Railway/Render, with logical separation via key prefixes:
- `NL:*` for Netherlands
- `UK:*` for UK

When you have meaningful UK traffic → split into two separate Redis instances.

```
Phase 1: redis-eu (NL + UK via key prefix)
Phase 2: redis-nl + redis-uk (separate instances)
Phase 3: redis-nl + redis-uk + redis-africa (separate servers in different regions)
```

---

#### STEP 3.3 — Driver Heartbeat System

Drivers must ping every 30 seconds to stay "online" in Redis:
```
POST /api/v1/driver/heartbeat
Body: { lat: 51.92, lng: 4.48, heading: 180 }
```

Go backend:
1. Refreshes Redis GEO position
2. Refreshes TTL (2 min expiry = driver missing 4 pings = auto offline)
3. Async writes to `driver_locations` table in Supabase
4. Returns any pending ride requests for driver

This replaces the current Supabase Realtime approach for location.

---

### PHASE 4 — TRAFFIC MIGRATION (Zero Downtime)

**Goal:** Move traffic from Flutter → Supabase to Flutter → Go Backend. Users never notice.

---

#### STEP 4.1 — Deploy Go Backend (Dark, No Traffic)

Deploy to Railway. Configure:
```
Environment:
  SUPABASE_URL=https://fvrprxguoternoxnyhoj.supabase.co
  SUPABASE_SERVICE_KEY=...
  REDIS_URL=...
  JWT_SECRET=... (from Supabase project settings)
  
PORT=8080
```

Run for 48 hours with internal testing only. Zero user traffic.

---

#### STEP 4.2 — Use Feature Flags to Route Traffic

In `app_config`, set:
```json
{
  "use_go_matching": false,
  "use_go_driver_locations": false,
  "go_backend_url": "https://api.heycaby.nl"
}
```

Flutter app reads this config on startup. When `use_go_matching` flips to `true`, it starts sending matching requests to Go backend. No app update needed.

**Rollout order:**
1. `use_go_driver_locations: true` → lowest risk, locations only
2. `use_go_matching: true` → matching engine switches to Go + Redis
3. `use_go_ride_service: true` → full ride lifecycle through Go
4. Supabase PostgREST access deprecated for core flows

---

#### STEP 4.3 — Parallel Write Period

During migration, write to BOTH Supabase (old) and Go backend (new):
- If Go backend fails → fall back to direct Supabase (Flutter already knows how)
- Monitor error rates in Go backend logs
- When error rate < 0.1% for 7 days → cut over fully

---

#### STEP 4.4 — Force Update System

Add minimum version check to Go backend:
```
GET /api/v1/config → returns { "min_version": "1.0.5", ... }
```

Flutter checks on launch. If current version < min_version → show update screen.  
This lets you eventually deprecate direct Supabase access from old app versions.

---

### PHASE 5 — MULTI-COUNTRY LAUNCH (UK + Beyond)

**Goal:** Launch UK without touching NL infrastructure.

---

#### STEP 5.1 — Add UK Cities to `cities` Table

```sql
INSERT INTO cities (id, name, slug, center_lat, center_lng, country_code, timezone, currency, is_active)
VALUES
  (gen_random_uuid(), 'London', 'london', 51.5074, -0.1278, 'UK', 'Europe/London', 'GBP', true),
  (gen_random_uuid(), 'Manchester', 'manchester', 53.4808, -2.2426, 'UK', 'Europe/London', 'GBP', false);
```

NL cities remain untouched.

---

#### STEP 5.2 — Add UK Zones (`bubble_zones`)

Same zone structure as NL, but tagged with `country_code = 'UK'`.  
Zone matching will only query zones matching the rider's country.

---

#### STEP 5.3 — UK Driver Onboarding

UK compliance requirements differ from NL (DVLA, PCO license vs KVK, chauffeurspas).

In `app_config`, `country_config.UK.required_docs` controls what documents are required.  
Driver onboarding flow reads this config — no code change in app needed if you build it correctly.

For UK, `kvk_number` stays NULL on `drivers` table (it's optional by default).  
New UK-specific doc types go into the `driver_verifications` table as new `verification_type` values.

---

#### STEP 5.4 — UK Payments

Since riders pay drivers directly: no payment infrastructure change needed for UK launch.  
Receipts table already has `currency` column (after Step 1.7).  
`rate_currency` on drivers ensures UK drivers invoice in GBP.

---

### PHASE 6 — PERFORMANCE HARDENING

---

#### STEP 6.1 — Migrate Heavy Supabase Functions to Go

Functions to migrate out of Postgres (currently running all business logic in DB):

| Supabase Function | Move To | Priority |
|---|---|---|
| `fn_get_nearby_drivers_by_category` | Go MatchingService + Redis | HIGH |
| `fn_scan_radar_matches` | Go MatchingService | HIGH |
| `fn_seed_ride_matching_batch` | Go RideService | HIGH |
| `fn_soft_reserve_ride` | Go + Redis atomic lock | HIGH |
| `fn_expire_ride_requests` | Go queue job | MEDIUM |
| `fn_generate_power_cards` | Go background job | MEDIUM |
| `fn_driver_finance_metrics` | Go analytics service | LOW |
| `fn_price_guidance` | Go PricingService | MEDIUM |
| `fn_estimate_trip_category_prices` | Go PricingService | MEDIUM |

Functions to KEEP in Postgres (they're fine there):
- `handle_new_user` (trigger)
- `fn_update_driver_avg_rating` (trigger)
- `recalculate_driver_rating` (trigger)
- `trg_create_onboarding_steps` (trigger)
- All `updated_at` triggers

---

#### STEP 6.2 — Database Query Optimization

These queries need `EXPLAIN ANALYZE` review before scale:

```sql
-- Check for sequential scans on these tables
EXPLAIN ANALYZE SELECT * FROM driver_locations WHERE country_code = 'NL' AND zone_id = '...';
EXPLAIN ANALYZE SELECT * FROM drivers WHERE status = 'available' AND country_code = 'NL';
EXPLAIN ANALYZE SELECT * FROM ride_requests WHERE status = 'searching' AND pickup_city_id = '...';
```

All three must use index scans. If not → add composite indexes.

---

#### STEP 6.3 — Connection Pooling

Add PgBouncer in front of Supabase:
- Supabase provides built-in connection pooling via port 6543 (Supavisor)
- Go backend must connect via Supavisor, not direct port 5432
- Set pool mode: `transaction` (correct for Go's connection model)

```
SUPABASE_DB_URL=postgresql://postgres.fvrprxguoternoxnyhoj:password@aws-0-eu-west-1.pooler.supabase.com:6543/postgres
```

---

#### STEP 6.4 — Observability (Logs, Metrics, Alerts)

Build in from day one:

```go
// Every request must log:
// - country_code
// - user_id
// - duration_ms
// - status_code
// - ride_id (if applicable)

// Structured JSON logs → ship to Grafana / Logtail / Axiom
```

Set alerts on:
- Matching latency > 2 seconds
- Redis connection failures
- Ride lock conflicts > 1% of requests
- Driver location update failures

---

### PHASE 7 — DEPLOYMENT SCALING

---

#### STEP 7.1 — Phase 1 Deployment (Launch)

```
Railway (or Render):
  - 1 Go backend instance
  - 1 Redis instance (eu-west)
  - Supabase (existing, eu-west-1)

Domain:
  api.heycaby.nl → Go backend
  db.heycaby.nl  → Supabase (internal use only)
```

Cost: ~$50-100/month.

---

#### STEP 7.2 — Phase 2 Deployment (Growth)

```
Railway with auto-scaling:
  - 2-4 Go backend instances (load balanced)
  - Redis Cluster (NL + UK namespaced)
  - Supabase Pro plan (more connections, PITR backup)

Or migrate to:
  - AWS ECS (eu-west-1) for Go backend
  - AWS ElastiCache (Redis)
  - Supabase remains
```

---

#### STEP 7.3 — Phase 3 Deployment (Global)

```
EU Region (Netherlands):
  - Go backend on AWS eu-west-1
  - Redis cluster eu-west-1
  - Supabase eu-west-1 (primary)

UK Region (London):
  - Go backend on AWS eu-west-2
  - Redis cluster eu-west-2
  - Supabase read replica

Africa Region (future):
  - Go backend on AWS af-south-1
  - Redis cluster af-south-1
  - Supabase read replica

DNS:
  - Cloudflare Geo-routing
  - api.heycaby.nl/uk → UK backend
  - api.heycaby.nl/nl → NL backend
  - api.heycaby.nl    → nearest region
```

---

## PART 4 — WHAT NEVER CHANGES (KEEP THESE)

- Supabase Auth — it works, keep it
- RLS policies — keep all of them
- `bubble_zones` + PostGIS — solid, keep it
- All `updated_at` and audit triggers — keep them
- `driver_trust_scores` system — excellent, keep it
- `notification_campaigns` lifecycle — production-grade, keep it
- `driver_verifications` document model — extend it for new countries, don't rebuild
- `app_config` key-value system — extend it heavily
- `vehicle_category_config` + base rates — extend for new countries

---

## PART 5 — RULES TO NEVER BREAK

1. **NEVER use database for live driver location** — Redis only
2. **NEVER query drivers without `country_code` filter** — NL and UK must never mix
3. **NEVER hardcode currency or pricing** — always read from CountryConfig
4. **NEVER break `/api/v1/` endpoints** — old app versions live there
5. **NEVER run matching queries against Postgres at scale** — Redis GEO only
6. **NEVER deploy a schema change without a rollback plan**
7. **NEVER store country-specific compliance logic in Flutter** — backend decides, app displays

---

## PART 6 — EXECUTION CHECKLIST (IN ORDER)

Audit status legend:
- `[x]` Done (implemented and verified in live DB and/or codebase)
- `[~]` Partial (implemented but not complete per target design)
- `[ ]` Missing / not started

Last audit refresh: 2026-04-28 (repo + Supabase MCP)

### Safe to start today (no risk to live users):
- [ ] Step 0.1 — Enable PITR backup on Supabase
- [x] Step 0.3 — Add country configs to `app_config` (live verified via MCP)
- [x] Step 2.1 — Initialize Go project (`backend/go.mod`, `backend/cmd/main.go`)
- [x] Step 2.2 — Build CountryConfig service (`backend/internal/config/country_config.go`)
- [~] Step 2.3 — Build Region middleware (JWT + header + NL default done; city/IP fallback not yet implemented)

### Week 1-2 (database migrations, additive only):
- [x] Step 1.1 — Add `country_code` to `cities` (live verified)
- [x] Step 1.2 — Add `country_code` to `drivers` (live verified)
- [x] Step 1.3 — Add `country_code` + `currency` to `ride_requests` (live verified)
- [x] Step 1.4 — Add `country_code` + `currency` to `rides` (live verified)
- [x] Step 1.5 — Add `country_code` to `bubble_zones` (live verified)
- [x] Step 1.6 — Add `country_code` to `driver_locations` (live verified)
- [x] Step 1.7 — Add `country_code` + `currency` to `receipts` and `driver_payment_events` (live verified)
- [x] Step 1.8 — Add `country_code` to `driver_trust_scores` and `driver_shift_sessions` (live verified)
- [x] Step 1.9 — Add performance indexes (live applied + verified on 2026-04-28; see migration `20260428175500_scale_add_remaining_perf_indexes_v2.sql`)

### Week 2-4 (Go backend build):
- [x] Step 2.4 — Auth middleware (`backend/internal/middleware/auth/auth.go`)
- [x] Step 2.5 — Repository layer (`backend/internal/repository/*`)
- [~] Step 2.6 — Matching service (Redis GEO + fallback done; full ranking/lock orchestration pending)
- [~] Step 2.7 — Ride service (basic create/get/cancel done; full lifecycle pending)
- [~] Step 2.8 — Driver location service (heartbeat writes DB/Redis; pending-ride return + full async pattern pending)
- [x] Step 2.9 — Feature flag middleware (`backend/internal/middleware/flags/flags.go`)

### Week 4-6 (Redis + deployment):
- [~] Step 3.1 — Deploy Redis (runtime supports Redis; environment deployment status not fully documented in repo)
- [~] Step 3.2 — Implement Redis data model (drivers GEO, status, online TTL, ride lock done; `ride_state` + `session` keys pending)
- [x] Step 3.3 — Driver heartbeat system (`POST /api/v1/driver/heartbeat` implemented)
- [ ] Step 4.1 — Deploy Go backend (dark)

### Week 6-8 (traffic migration):
- [ ] Step 4.2 — Feature flag rollout (locations first)
- [ ] Step 4.3 — Parallel write period
- [ ] Step 6.1 — Migrate heavy Postgres functions to Go

### When ready for UK:
- [ ] Step 5.1 — Add UK cities
- [ ] Step 5.2 — Add UK zones
- [ ] Step 5.3 — UK driver onboarding config
- [ ] Step 5.4 — UK receipts with GBP currency

---

## PART 6B — DEDUPED EXECUTION BOARD (PHASES 4-7)

Rule for this board: before starting any item, first check Part 6 checklist and existing migrations/services to avoid duplicate work.

| Step | Status | Owner | Depends on | Next action (single source of truth) | Duplicate guard |
|---|---|---|---|---|---|
| 4.1 Deploy Go backend (dark) | [ ] | Backend + DevOps | 2.1-2.9 partial | Deploy current `backend/cmd/main.go` as internal-only service, no app traffic; run 48h health checks (`/health`) | Do not create a second backend repo/service; use existing `backend/` |
| 4.2 Feature-flag traffic rollout | [ ] | Backend + Mobile | 4.1 | Add/confirm `go_backend_url` and `use_go_driver_locations` in `feature_flags` payload path, then rollout locations first | Reuse existing `feature_flags` row in `app_config`; do not create duplicate config keys |
| 4.3 Parallel write period | [ ] | Backend | 4.2 | Implement dual-write guard in ride/location critical paths, with fallback to existing Supabase behavior | Reuse current repository layer; do not add parallel duplicate repository clients |
| 4.4 Force update system | [~] | Backend + Mobile | 4.1 | Backend already returns min version field on `/api/v1/config`; wire strict client enforcement screen and version compare | Do not add another config endpoint; keep `/api/v1/config` as source |
| 5.1 Add UK cities | [ ] | Data/DB | 1.1 complete | Add one migration for UK city seeds only (no NL edits) | Check `cities.slug` and existing UK rows first to avoid duplicate inserts |
| 5.2 Add UK zones | [ ] | Data/Geo | 5.1 | Add UK `bubble_zones` seed migration with `country_code='UK'` and city link | Check existing `bubble_zones` by `city_id,name` before inserts |
| 5.3 UK onboarding config | [~] | Backend + Ops | 0.3 complete | UK config row exists; implement backend/runtime mapping for UK verification types and app display contract | Reuse `country_config.UK.required_docs`; do not add a second UK config key |
| 5.4 UK payments | [~] | Backend + Mobile | 1.7 complete | Currency columns exist; validate GBP flow end-to-end in receipt creation/read paths | Reuse existing `currency` columns; no new payment schema unless gap found |
| 6.1 Migrate heavy DB functions to Go | [ ] | Backend | 2.6/2.7 completion | Migrate in priority order: `fn_get_nearby_drivers_by_category`, `fn_scan_radar_matches`, `fn_seed_ride_matching_batch`, `fn_soft_reserve_ride` | Before each migration, check if logic already implemented in `matching_service`/`ride_service` |
| 6.2 Query optimization (`EXPLAIN ANALYZE`) | [ ] | DB | 1.9 complete | Run explain on hot queries and capture plans in a dated report section in this doc | Reuse existing indexes first; only add new index if plan shows seq scan/regression |
| 6.3 Supavisor pooling | [ ] | DevOps + Backend | 4.1 | Switch backend DB connection strategy to Supavisor (`:6543`) where direct SQL connection is introduced | Do not add raw `5432` direct production connections |
| 6.4 Observability | [~] | Backend + Ops | 4.1 | Upgrade from basic request logs to structured JSON with required fields + alerts | Extend current logger middleware; do not introduce parallel logging stacks |
| 7.1 Phase 1 deployment | [ ] | DevOps | 4.1 | Lock single-region baseline (EU) with one Redis + one Go service and clear runbook | Reuse same domain/API base; no duplicate public API hosts |
| 7.2 Phase 2 growth | [ ] | DevOps | 7.1 | Define autoscaling thresholds and Redis sizing policy | Reuse same service names and dashboards to preserve history |
| 7.3 Phase 3 global | [ ] | Architecture + DevOps | 7.2 | Add region split plan with explicit routing rules and data consistency notes | Do not fork schemas per region; keep schema/migrations unified |

---

### No-Duplicate Preflight (Run Before Every New Task)

1. Check Part 6 status line for the step (`[x]`, `[~]`, `[ ]`).
2. Search for existing migration/service before writing anything new.
3. If partial exists, extend that asset; do not create a parallel implementation.
4. Only create a new migration/key/endpoint when no existing one can be safely extended.
5. Record completion evidence path in this doc immediately after execution.

---

## PART 7 — SUMMARY

| Dimension | Today | After This Plan |
|-----------|-------|-----------------|
| Countries | NL only (hardcoded) | NL + UK + any country via config |
| Matching | Postgres functions | Go + Redis GEO |
| Location | Supabase Realtime | Redis (2-min TTL, heartbeat) |
| Currencies | EUR only (implicit) | Any currency per country |
| Config | 5 rows in app_config | Full country config system |
| Backend | None (Flutter → Supabase direct) | Go modular monolith |
| API versioning | None | /v1/ frozen, /v2/ evolving |
| Matching speed | ~3-5 seconds (PG query) | <500ms (Redis GEO) |
| Concurrent drivers | ~200 before slowdown | 50,000+ per region |
| User disruption | — | Zero (additive migrations + feature flags) |

---

*This plan is designed to be executed incrementally. Every step is reversible or additive. Live users are never impacted. The database migrations are non-destructive. The Go backend is introduced behind feature flags. The result is a system that can scale from Rotterdam to the world without rebuilding.*
