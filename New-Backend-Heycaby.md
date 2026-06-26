# HEYCABBY V1 PRODUCTION ARCHITECTURE SPECIFICATION

## Product & Engineering Strategy

### Objective

Version 1 of HeyCabby runs on **Flutter, Supabase, Mapbox, and Vercel.** No Go backend, no Redis, no AWS.

This isn't a smaller version of the "real" architecture. It's the correct architecture for zero production drivers and zero production ride volume — built so nothing has to be ripped out when volume shows up, and detailed enough that an engineering team can build directly against it without guessing at the gaps.

This is a specification, not a decision memo — it's the document the team builds against. Each revision has closed a real class of gap: the first pass had the right philosophy but no mechanism for atomicity; the second added idempotency, the offer model, the audit log, and monitoring. This pass adds the operational layer underneath all of that — presence vs. availability, heartbeats, notification delivery, security, multi-tenancy, feature flags, background jobs — and closes with the chapter that ties it together: **System Invariants**, the rules that are never allowed to break.

---

## Launch scope & growth targets (Netherlands V1)

| Item | Decision |
|---|---|
| **Market** | Netherlands only at launch — no multi-country production traffic yet |
| **Launch cities** | **Rotterdam**, **Amsterdam**, **Utrecht**, **Den Haag** |
| **Driver goal** | **~1,000 active drivers within 6 months** of launch |
| **Rider goal** | Grow with driver supply in the four cities (hundreds of concurrent riders is the realistic V1 ceiling) |
| **Infrastructure target** | This document's stack: **Flutter + Supabase + Mapbox + Vercel** — no Go/Redis/AWS in production until metrics justify it |

**Scale verdict:** 1,000 online drivers across four Dutch cities is **well within** what Supabase Postgres + Realtime + Edge Functions can handle when indexes, RLS, and dispatch RPCs are implemented as specified below. This is not a “small stack for a small idea” — it is the **correct** stack for NL launch through roughly **2,000–5,000** drivers before re-evaluating Go or Redis.

All numeric defaults in this document (€1 platform fee, €60 lock, 20s offer timeout, etc.) are **NL defaults** sourced from `market_config` / `country_config.NL`, not hardcoded literals.

---

## The Vision, Unchanged

HeyCabby is a SaaS platform for independent taxi drivers, not a taxi company.

- Drivers own their customers.
- Drivers get paid directly by riders — HeyCabby never touches fare money.
- HeyCabby charges a flat software usage fee per completed ride.
- **Platform settlement is independent from rider payment.** HeyCabby's billing relationship is with the driver (software fee); the rider's payment relationship is with the driver directly. These two money flows never touch the same ledger, and V1 deliberately does not implement rider→platform payment processing — there's nothing to build there.

Everything below exists to serve that model correctly, not to add features.

---

## V1 Production Stack

| Layer | Technology | Why |
|---|---|---|
| Rider app | Flutter | Single codebase, iOS + Android |
| Driver app | Flutter | Same |
| Backend, auth, business logic | Supabase (Postgres + RLS + Edge Functions + Realtime) | One system of record, one bill |
| Geospatial driver search | **Postgres + PostGIS extension** | Cheaper and faster in-database than an API round-trip — it's a filter, not a routing problem |
| Address autocomplete, geocoding, routing, road-aware ETA, navigation | **Mapbox** | Real-world road networks, traffic-aware ETA, address coverage — exactly what Postgres can't do |
| Hosting / deploy | Vercel | Admin dashboard + marketing site only |

PostGIS handles "which of these 10,000 driver rows are within 2km of this point" as a cheap in-database filter. Mapbox handles everything that needs an actual map of the real world. They solve different problems; using both isn't redundant.

**Version 1 is intentionally implemented using Flutter, Supabase, Mapbox, and Vercel only.** The architecture has been designed so that services such as Go, Redis, or other infrastructure can be introduced incrementally when production metrics — see Monitoring Thresholds, below — demonstrate a clear need.

---

## The Server Boundary

**Flutter → Server → Database.** Whether the server is Supabase today or a Go service tomorrow shouldn't change the principle: any decision that can change who gets paid, who gets a ride, or who gets locked out lives behind the server boundary, never on the client. For V1, Supabase *is* that server.

Supabase owns:
- Auth, driver/rider profiles
- Dispatch and ride lifecycle (now two separate state machines — see below)
- Driver presence and availability (now two separate fields — see below)
- Platform fee ledger and wallet balance
- All RLS policies
- The notification pipeline
- The audit log
- Feature flags and background jobs

---

## Dispatch vs. Ride Lifecycle — Two State Machines, Not One

The previous version had a single ride-status chain doing two jobs: finding a driver, and then running the trip. Split them. This is what makes reassignment, driver swaps, or a future "driver cancels mid-search" case easy to add later without restructuring the schema.

**Dispatch state machine** (lives entirely on the `rides` row until a driver is locked in):
```
searching → offering → assigned → dispatch_complete
```

**Ride lifecycle** (takes over once dispatch is done):
```
assigned → driver_en_route → arrived → onboard → completed → closed
```

`dispatch_complete` and `assigned` are the same moment — the handoff point. Before it, all mutations are about *finding* a driver (offers, expiry, re-broadcast). After it, all mutations are about *running* the trip. Keeping them as two named machines, even on the same table, means a developer reading the code always knows which problem they're solving.

---

## Driver Presence vs. Driver Availability

"Driver online" was one boolean doing the job of two unrelated concepts. Split them into two columns:

**Presence** — is the driver's app connected at all:
```
offline → online → disconnected
```

**Availability** — can this specific driver receive a ride right now:
```
available → busy → paused → locked → suspended
```

A driver can be `online` (presence) and `busy` (availability) at the same time — mid-trip, connected, just not eligible for a new offer. Collapsing these into one field is what leads to bugs like "driver appears offline but is actually just on a ride." They're independent axes; model them as two columns.

---

## Driver Heartbeat

Presence shouldn't be a flag the driver app sets once and forgets — it should be continuously proven.

```
Driver app → heartbeat ping every 5–10s → server
```

If no heartbeat arrives for a threshold (suggest 30s — a few missed beats, not just one flaky ping): the server flips presence to `offline` automatically, via a scheduled function checking `last_heartbeat_at`. This is what prevents **ghost drivers** — a driver whose app crashed or lost connection but who still shows as online and keeps receiving (and missing) offers, frustrating riders and wasting dispatch cycles.

---

## Driver Session — Distinct from Presence

Presence answers "is the driver connected right now?" That's not the same question as "which authenticated session is allowed to act on this driver's behalf?" — and conflating them breaks down the moment a driver has two devices, gets force-logged-out, or has a phone stolen.

```
Session: started → active → expired → logged_out
```

A `driver_sessions` table (`session_id`, `driver_id`, `device_id`, `started_at`, `last_refreshed_at`, `status`) tracks this independently of presence. Concretely, this is what answers questions presence alone can't:

- **Multiple devices** — a driver logs in on a new phone; does the old session stay valid? (No — starting a new session expires the prior one for that driver, unless explicitly supporting multi-device.)
- **Forced logout** — admin or driver remotely ends a session; presence may still show "online" for a few seconds until the next heartbeat fails, but the session itself is already `logged_out` and the server rejects further RPCs from it immediately.
- **Token refresh** — a session's JWT refresh extends `last_refreshed_at`; presence doesn't need to be touched.
- **Stolen phone** — the legitimate driver logs out their session remotely from a second device; the stolen phone's session is immediately invalid even if it's still pinging heartbeats.

Every mutating RPC checks session status, not just presence — a driver with valid presence but an expired/logged-out session must not be able to accept rides.

---

## Driver Matching: The Full Eligibility Pipeline

```
Driver online (presence)
    ↓
GPS fresh (location updated within last 2 minutes)
    ↓
Verified (KYC / documents)
    ↓
Vehicle approved
    ↓
Within driver's configured pickup radius
    ↓
Within rider's search radius
    ↓
Correct vehicle category
    ↓
City / service zone match
    ↓
Not locked (billing)
    ↓
Available (not busy/paused/suspended)
    ↓
ETA ranked (PostGIS first-pass, Mapbox re-rank)
    ↓
Offer sent (with TTL)
```

The addition that matters most here: **GPS Fresh**. A driver whose last location ping is two minutes old might be parked, might have closed the app, might be anywhere — sending them a ride request based on stale coordinates produces an offer the rider waits on for a driver who was never really there. Filter on `location_updated_at` before anything else geographic.

```sql
select driver_id,
       st_distance(location, ride_pickup_point) as distance_m
from driver_locations dl
join drivers d using (driver_id)
where d.presence = 'online'
  and d.availability = 'available'
  and dl.location_updated_at > now() - interval '2 minutes'
  and d.is_verified = true
  and d.vehicle_approved = true
  and d.vehicle_type = p_required_vehicle_type
  and d.city_id = p_ride_city_id
  and st_dwithin(dl.location, ride_pickup_point, p_search_radius_m)
order by distance_m asc
limit 10;
```

---

## Rider Search Timeout — Fully Defined

"90 seconds, then no driver" left the actual wave behavior to whoever implemented it. Define the waves explicitly so every developer builds the same thing:

```
Wave 1: offer sent to top candidates → 20s timeout
    ↓ (no acceptance)
Wave 2: offer sent to next candidates → 20s timeout
    ↓ (no acceptance)
Wave 3: offer sent to next candidates → 20s timeout
    ↓ (no acceptance)
Expand search radius
    ↓
Wave 4: offer sent within expanded radius → 30s timeout
    ↓ (no acceptance)
Fail gracefully → rider notified "No driver found"
```

Total worst case: ~90 seconds, matching the original target, but now with a defined shape instead of just a ceiling.

---

## Ride Offers — Dedicated Data Model

Offers are referenced throughout this document — expiry, waves, cancellation — but they need their own table, not transient state stuffed into the `rides` row. A ride can fan out to multiple drivers across multiple waves, and each of those attempts is a fact worth keeping on its own record.

```sql
create table ride_offers (
  id uuid primary key default gen_random_uuid(),
  ride_id uuid not null references rides(id),
  driver_id uuid not null references drivers(id),
  wave integer not null,                 -- which search wave this offer belongs to
  status text not null check (status in (
    'sent', 'accepted', 'declined', 'expired', 'cancelled'
  )),
  sent_at timestamptz not null default now(),
  expires_at timestamptz not null,
  responded_at timestamptz
);
```

One row per (ride, driver, wave) — not one row per ride. This is what makes a set of questions answerable directly, rather than reconstructed from logs:

- Which drivers received this ride, and in what order?
- Who saw it and ignored it, versus who actively declined?
- Which wave actually produced the acceptance?
- Why did a particular rider wait 40 seconds — which waves fired, and when?

`status = 'cancelled'` is the row state written the moment another driver's offer is accepted (see Notification Pipeline) — distinct from `'expired'`, which is a timeout with no winner yet. Keeping these separate is what lets analytics later distinguish "drivers who lost the race" from "drivers who simply didn't respond."

---

## Notification Pipeline

Notifications deserve their own section because a stale one — a push that arrives after the ride has already been offered to someone else — actively confuses drivers. The pipeline:

```
Ride created
    ↓
Driver selected (by the eligibility pipeline)
    ↓
Push notification sent + Realtime channel update sent together
    ↓
Driver accepts  →  cancel notification sent to every other driver in that wave
    ↓
Offer marked closed
```

The critical rule: **the moment one driver accepts, every other outstanding offer in that ride's current wave gets an explicit cancel push**, not just a silent expiry. A driver staring at an offer that's already gone is a worse experience than one that visibly disappears.

---

## Failure Recovery

The document so far describes the happy path. Production systems are judged by what happens when something goes wrong halfway through — these are the unhappy paths V1 explicitly defines rather than leaves to chance:

**Driver accepts, then the app crashes or loses connection:**
```
Driver accepts → ride row updated (server-side, already committed)
    ↓
App crashes / connection drops
    ↓
Driver reconnects (or relaunches app)
    ↓
Client fetches current ride state from the server (not from local cache)
    ↓
Ride is restored exactly as the server has it — driver resumes from truth, not memory
```
Because acceptance is committed server-side inside the atomic RPC, a crash *after* acceptance never loses or duplicates the assignment — the client is just re-reading state it doesn't have to reconstruct.

**Realtime channel disconnects mid-ride:**
```
Realtime disconnected
    ↓
Client detects drop, attempts reconnect (exponential backoff)
    ↓
On reconnect: resubscribe to the relevant channel(s)
    ↓
Immediately fetch latest ride/offer state via a regular query
    ↓
Reconcile — Realtime gives you the next change, not the state you missed
```
The rule that makes this safe: **Realtime is a notification mechanism, never the source of truth.** Any client that reconnects must re-fetch state directly rather than assume it caught every event it missed while disconnected.

---

## API Versioning

RPCs and Edge Functions will change shape over time; old app versions in the field shouldn't break the moment a new one ships.

```
RPC v1 → RPC v2 → v1 deprecated (still callable, logged) → v1 removed
```

Practically: version RPC function names explicitly when a breaking change is needed (`accept_ride_v2`, not a silently changed `accept_ride`), keep the old version live and logged for a defined deprecation window, and only drop it once telemetry shows no client is still calling it.

---

## Audit Log

Unchanged in design from the prior revision — every state transition, insert-only, immutable:

```sql
create table ride_audit_log (
  id uuid primary key default gen_random_uuid(),
  ride_id uuid not null references rides(id),
  event text not null,
  actor_id uuid,
  occurred_at timestamptz not null default now(),
  metadata jsonb
);
```

**Invariant, made explicit here because it now matters across more state machines than before: every dispatch-state transition and every ride-lifecycle transition writes a row.** Two state machines, one shared log — that's what makes a support timeline read as one coherent story instead of two disconnected ones.

**Event naming convention:** every `event` value in the audit log (and every notification/analytics event downstream of it) follows `noun.verb` — `ride.created`, `offer.sent`, `offer.accepted`, `offer.expired`, `driver.arrived`, `trip.started`, `trip.completed`, `billing.locked`. Picking this convention once, early, is what keeps analytics queries and dashboards consistent as the event list grows — `select * where event like 'offer.%'` should always work.

---

## Platform Billing — Immutable Ledger, Now With a Reason Code

Same model as before — €1 platform fee per completed ride, rider pays driver directly, ledger is immutable, corrections via reversing entries — with one addition: every ledger row carries a **reason**, so the ledger is self-explanatory months later without needing to reconstruct context.

```sql
create table billing_ledger (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references drivers(id),
  amount numeric not null,
  reason text not null check (reason in (
    'ride_fee', 'manual_adjustment', 'promotion', 'refund', 'settlement', 'credit'
  )),
  ride_id uuid references rides(id),
  created_at timestamptz not null default now()
);
```

Lock/unlock mechanics are unchanged from the prior revision: `is_locked` set by trigger at €60 outstanding, checked inside `accept_ride`, cleared automatically by a trigger on confirmed settlement — no manual admin step.

---

## Driver Location History

`driver_locations` (current position, used for dispatch) and `driver_location_history` (where they've been) are different tables with different lifespans. The eligibility pipeline only ever reads current location; history exists for disputes, fraud detection, and analytics that ask "where was this driver at 3pm yesterday" — a question the current-location table can't answer.

```sql
create table driver_location_history (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references drivers(id),
  location geography(Point, 4326) not null,
  recorded_at timestamptz not null default now()
);
```

Retention for this table specifically: keep detailed pings for 7 days, downsample or drop after that (see Data Retention, below) — full-resolution history older than a week has cost without corresponding value at V1 volume.

---

## Database Index Strategy

PostGIS and the eligibility pipeline only perform if the underlying indexes exist. Minimum index set for V1:

```sql
create index on driver_locations using gist (location);              -- geography index, powers ST_DWithin
create index on rides (status);
create index on rides (assigned_driver_id);
create index on drivers (city_id);
create index on driver_locations (driver_id);
create index on billing_ledger (driver_id);
create index on ride_offers (ride_id, wave, status);
create index on ride_audit_log (ride_id, occurred_at);
```

Without the GiST geography index specifically, every `ST_DWithin` call degrades to a full table scan the moment the driver table grows past a trivial size — this is the one index that isn't optional even at launch.

---

## Data Retention

| Data | Retention | Then |
|---|---|---|
| `driver_locations` (current) | Live, overwritten continuously | N/A |
| `driver_location_history` | 7 days full resolution | Delete or downsample |
| Completed/closed rides | 7 years | Archive to cold storage |
| `ride_audit_log` | Never modified | Archived (not deleted) after a defined retention window |
| `billing_ledger` | Never deleted | Permanent — it's the financial record |

The 7-year figure for ride history isn't arbitrary — it tracks typical financial/tax record-keeping expectations and should be confirmed against actual Dutch (and future market) requirements before launch. This section exists mainly so retention is a deliberate decision rather than "whatever Postgres happens to keep by default," which matters both for storage cost and for GDPR — driver and rider personal data tied to old rides needs a defined deletion or anonymization point, not indefinite retention by accident.

---

## Configuration Layer

Feature flags, pricing, tenant boundaries, and service zones have been described separately throughout this document — but they're really one concept wearing different hats: **nothing market-specific should be hardcoded.** Unify them into a single configuration hierarchy:

```
Platform Configuration
    ↓
Country
    ↓
City
    ↓
Zone
    ↓
Feature Flags
    ↓
Pricing
    ↓
Dispatch Rules
    ↓
Billing Rules
```

Concretely, a `market_config` table (keyed by `tenant_id` + `city_id`) holds the values that the rest of this document treats as constants — platform fee, outstanding limit, offer timeout, search radius — so that launching a second market is a configuration row, not a code change:

```
Rotterdam               London
platform_fee: €1        platform_fee: £1.20
outstanding_limit: €60  outstanding_limit: £80
offer_timeout: 20s      offer_timeout: 15s
search_radius: 5km      search_radius: 5km
```

Every place in this document that states a specific number — €1 platform fee, €60 lock threshold, 20s offer timeout, 2-minute GPS freshness — should be read as "the V1 default for the Netherlands," sourced from this config layer, not literals buried in application code.

---

## Security

A short section, but a necessary one — these are baseline, not aspirational:

- **JWT validation** on every request — Supabase handles this at the Postgres/Edge Function layer by default; don't bypass it with a service-role key from client code.
- **RLS enforced on every table**, no exceptions for "internal" tables — a driver's query should be physically incapable of returning another driver's data, not just discouraged from asking.
- **Rate limiting / API throttling** on ride creation and offer-accept endpoints specifically — these are the two highest-value targets for abuse (fake ride spam, accept-flooding).
- **Driver authorization** — every mutating RPC checks that the calling driver_id matches the authenticated session, not just that *some* driver is authenticated.
- **Admin authorization** — admin actions (manual ledger adjustments, manual unlocks) go through a separate role with its own RLS policies, never the driver/rider role with elevated flags.

---

## Multi-Tenancy

Launching Netherlands-only, but defining the boundary now is what makes UK or Nigeria a configuration change later instead of a migration.

Add a `tenant_id` (or `market_id`) early, even though for V1 it maps one-to-one with `country_code`. Every ride, driver, and ledger row carries it. The eligibility pipeline's "city / service zone match" step becomes "tenant + city match." This costs almost nothing now and avoids a retrofit the day a second market launches.

---

## Admin Architecture

This document has focused on riders and drivers, but every taxi platform eventually needs an operating model for the people running it — and the backend needs to be *built* to support that, even if the admin UI itself isn't V1's priority. Define the surface now so the data model doesn't have to be retrofitted later:

- **Live rides view** — every ride currently in `searching`/`offering`/`assigned`/in-progress, queryable in real time
- **Live drivers view** — presence, availability, and location, filterable by city/zone
- **Driver verification** — approve/reject KYC and vehicle documents (feeds `is_verified`, `vehicle_approved`)
- **Driver suspension** — sets `availability = suspended`, distinct from billing lock, with its own reason/audit trail
- **Rider reports** — a queue of rider-submitted issues, linked to `ride_id`
- **Manual ledger adjustments and unlocks** — always via the `manual_adjustment` reason code on `billing_ledger`, never a raw `UPDATE`
- **Billing overview** — aggregate view over the ledger, by driver and by market
- **Audit viewer** — a read interface over `ride_audit_log`, filterable by event prefix (`offer.*`, `billing.*`)
- **Ride replay** — reconstructing a single ride's full timeline from the audit log, for support and disputes

None of this needs to ship as a polished dashboard for V1 — but every action above maps to an existing table, RLS-gated admin role, or audit event already specified in this document. The point is that admin capability is a query and a role, not a separate system bolted on afterward.

---

## Event Bus (Conceptual, for Today; Literal, Eventually)

The audit log, Realtime, notifications, and background jobs are all already event-driven — this document just hasn't named the pattern. Worth doing now, even cheaply, because it's what makes a future migration to Go (or anything else) a swap of *implementation*, not a rewrite of *thinking*.

```
trip.completed
    ↓
billing (fee created)
    ↓
audit log (event recorded)
    ↓
notification (rider/driver informed)
    ↓
analytics (metrics updated)
    ↓
driver wallet (balance updated)
```

For V1, this fans out via Postgres triggers and Edge Functions reacting to row changes — there's no message broker, and there doesn't need to be one yet. The discipline worth adopting now: each downstream effect of an event is its own handler, not one large function doing six things in sequence. That's what lets a literal event bus (Postgres `LISTEN/NOTIFY`, or eventually something external) get introduced later without touching the handlers themselves.

---

## Fraud & Trust (Future Subsystem, Named Now)

Not built for V1, but worth naming as a subsystem the architecture has room for, rather than discovering the need for it under pressure later:

- Fake GPS detection (location jumps inconsistent with physically possible travel)
- Impossible-travel detection (a ride's pickup/dropoff pattern that couldn't have happened in the elapsed time)
- Duplicate account detection
- Excessive cancellation patterns (rider or driver)
- Ride abuse (fake rides, GPS spoofing to farm incentives)
- Driver and rider fraud more generally

The audit log and `ride_audit_log` event stream already specified in this document are what a future Trust & Safety subsystem would consume — this isn't a new data model, it's a new reader of data that already exists.

---

## Feature Flags

Every feature with real operational risk should launch behind a flag, checked server-side, so rollout doesn't require a redeploy:

```
marketplace_mode        → ON
scheduled_rides          → OFF
dynamic_pricing          → OFF
corporate_accounts       → OFF
expanded_search_radius   → OFF
```

Store these in a simple `feature_flags` table (`key`, `enabled`, `tenant_id` for per-market rollout), read by Edge Functions and RPCs at decision time — not baked into Flutter as a build-time constant.

---

## Background Jobs

The scheduled functions referenced throughout this document, collected in one place so nothing gets missed in implementation:

- Expire offers past `expires_at`
- Advance dispatch waves (search timeout sequence)
- Mark drivers offline after missed heartbeats
- Unlock drivers after confirmed settlement
- Clean stale `driver_locations` rows
- Retry failed push notifications
- Archive completed/closed rides past a retention window

---

## Monitoring

Unchanged in substance from the prior revision — these are the numbers that turn "do we need a fifth vendor" into an evidence-based call instead of a guess:

- Ride request success rate
- Average matching time (request → assigned)
- Driver acceptance rate (accepted ÷ sent offers)
- Offer timeout/expiry rate, per wave
- Online driver count and available driver count, tracked separately
- Heartbeat miss rate (proxy for ghost-driver frequency)
- Failed dispatches (exhausted all waves, no driver)
- Billing failures / lock events
- Realtime channel latency
- RPC execution time, especially `accept_ride`
- Database lock contention on `rides`
- Failed notification deliveries

**Thresholds, not just metrics** — a number without a target doesn't tell you when to act:

| Metric | Target |
|---|---|
| Average dispatch time (request → assigned) | < 3 seconds |
| Heartbeat delay before presence flips offline | < 30 seconds |
| Offer delivery (push + Realtime) | < 2 seconds |
| RPC execution time (`accept_ride` and similar) | < 200 ms |
| Driver acceptance rate | > 70% (investigate below this) |
| Failed dispatch rate (no driver found) | < 5% |

These are starting targets, not laws of physics — but having them in writing means a regression is visible the moment it happens, instead of being a vague feeling that "matching seems slower lately."

---

## System Invariants

The rules that must always be true. Any future code change that violates one of these is, by definition, a bug — not a judgment call.

1. One ride can have at most one assigned driver.
2. A completed ride can never return to `searching`.
3. Riders never pay HeyCabby directly for taxi fares.
4. Platform fees are generated only after a ride is completed.
5. Ledger entries are immutable — corrections only via reversing entries.
6. Every dispatch and ride-lifecycle state transition writes an audit log row.
7. Drivers with stale GPS (>2 minutes) cannot receive new offers.
8. A locked driver cannot accept new rides but may finish an active trip.
9. Every mutating API request is idempotent.
10. Business rules execute server-side, never in Flutter.
11. Presence and availability are independent fields — neither can be inferred from the other.
12. The moment one driver accepts an offer, every other outstanding offer in that wave is explicitly cancelled, not left to expire silently.
13. A valid presence/heartbeat does not authorize action — only a session with `active` status can.
14. Reconnecting clients always re-fetch state from the server; Realtime is a notification mechanism, never the source of truth.

---

## Operational Readiness Checklist

Every production release passes this before it ships — a deployment that skips items here is a deployment made on hope rather than verification:

- [ ] Database migrations tested against a staging copy of production data
- [ ] RLS policies verified for every affected table (driver sees only driver-scoped data, etc.)
- [ ] RPC compatibility verified — old app versions still work against new RPC versions (see API Versioning)
- [ ] Feature flags reviewed — anything risky launches `OFF` by default
- [ ] Billing logic tested — fee creation, lock threshold, unlock-on-payment, reversing entries
- [ ] Ride assignment concurrency tested — simulate two drivers accepting the same ride simultaneously
- [ ] Push notifications tested end-to-end, including the cancel-on-accept path
- [ ] Rollback plan prepared and actually rehearsed, not just written down
- [ ] Monitoring alerts enabled for the thresholds defined above
- [ ] Backup verified — a restore has actually been tested, not just a backup file confirmed to exist

---

## Success Criteria

V1 succeeds if:
- Ride booking works reliably, with dispatch and ride lifecycle cleanly separated
- Ride assignment is provably atomic and idempotent
- Every state transition is captured in the audit log, with a consistent event naming convention
- Ghost drivers are structurally impossible (heartbeat-enforced presence) and session hijacking/stale sessions can't authorize actions
- Platform billing is accurate, immutable, reason-coded, with automatic unlock
- Security baseline (RLS, JWT, rate limiting, authorization) holds under real traffic
- Failure recovery is defined, not improvised — crashes and reconnects restore from server state, never assumed local state
- Database indexes support the query patterns the eligibility pipeline actually runs
- Data retention is a deliberate decision, not a default
- Monitoring has real thresholds, not just dashboards
- Configuration (pricing, limits, timeouts, radii) lives in a config table per market, not in code
- The admin surface (verification, suspension, manual adjustments, ride replay) maps cleanly onto existing tables and roles
- Infrastructure stays focused: Flutter, Supabase, Mapbox, Vercel — no fifth vendor without monitoring evidence

Only after these hold up under real drivers and real rides does a new vendor get evaluated on evidence, not anticipation.

---

## Engineering Principle

Don't optimize for a million rides before the first one is dispatched correctly.

Four vendors, each doing the one thing it's actually good at. Two state machines where there used to be one. A history that can be trusted because nothing in it can be quietly edited. A list of invariants that turns "is this a bug" into a lookup instead of a debate.

That's HeyCabby V1.

---

## What Comes Next

This document is the architecture specification — it should stop growing unless implementation surfaces a real gap. The next layer of detail belongs in three companion documents, not in this one:

1. **Database Specification** — every table, column, index, trigger, RPC, and RLS policy, fully enumerated.
2. **API Specification** — every RPC and Edge Function, with request/response shapes and error codes.
3. **QA & Smoke Test Specification** — concurrency tests, billing tests, failure-recovery simulations, and the operational readiness checklist above turned into executable test cases.

Together, those three plus this document form the complete engineering blueprint. From here, the work shifts from designing the system to building and validating it.

---

## Engineering Review (HeyCaby codebase alignment)

*Last updated from live **HEYCABY-TAXI** Supabase project (`fvrprxguoternoxnyhoj`, eu-west-1) via Supabase MCP — May 2026.*

### Verdict

This spec is the **right target**. Production today is **pre-launch** (4 drivers, 46 ride requests, 0 live locations). You are **~55% aligned** on data and matching primitives; **~25% aligned** on billing/go-online; **Go on AWS is still wired** and is the main thing to remove from the critical path.

**Yes — this stack works for 1k drivers in 6 months in NL**, provided you finish the gaps below and stop operating two backends.

---

### Launch cities (database — already correct)

All four launch cities exist in `public.cities` with `country_code = 'NL'` and `is_active = true`:

- Rotterdam  
- Amsterdam  
- Utrecht  
- Den Haag  

No schema change required for city activation — focus on **dispatch radius**, **zone coverage** (`bubble_zones`, 123 rows), and **driver onboarding** in those markets.

---

### Where we stand now (production Supabase)

| Area | Current state | Spec target |
|---|---|---|
| **Drivers** | 4 rows, all `status = offline` | 1,000 active across 4 cities |
| **Ride volume** | 46 `ride_requests` (41 cancelled, 5 pending); 0 completed production trips | Reliable dispatch + lifecycle |
| **Live GPS** | `driver_locations`: 0 rows; lat/lng columns (no `geography` Point yet) | PostGIS / fresh GPS filter |
| **PostGIS** | Extension **installed** (3.3.7) | Use for nearby-driver queries + GiST index |
| **pg_cron** | Active: `mark_idle_drivers_offline` (10m), referral + lifecycle jobs | Add offer expiry, wave advance, heartbeat offline |
| **Atomic accept** | `fn_driver_accept_ride_invite` ✓ | Keep; add billing lock + idempotency keys |
| **Offers / waves** | `ride_request_invites` table exists (`batch_no`, `expires_at`, `status`) — **0 rows** | Align with spec `ride_offers` model + 4-wave job |
| **Matching** | `fn_seed_ride_matching_batch`, `trg_ride_request_after_insert_matching`, `fn_get_nearby_drivers` | Formalize wave timeouts in config + cron |
| **Ride table** | `ride_requests` is the real table (rich schema); empty `rides` table | Treat `ride_requests` as V1 `rides` — **do not fork** |
| **Driver status** | Single enum: `available` / `on_ride` / `offline` / `on_break` | Split **presence** + **availability** (+ `locked` for billing) |
| **Platform billing** | `platform_fee_cents` on `ride_requests`; `driver_payment_events` (Mollie); subscription fields on `drivers` | **`billing_ledger`** + €1/ride accrual + €60 lock |
| **Audit log** | Not present | `ride_audit_log` + triggers on all transitions |
| **Market config** | `app_config`: `country_config.NL`, `feature_flags`, `search_config` | Add `market_config` or extend `country_config.NL` with fee/limit/timeout keys |
| **Config API** | `get_driver_rest_api_base_url` → Go API | Replace with Supabase RPC boot config; **remove Go dependency** |
| **Edge Functions** | 17 active (`send-push`, Veriff, founding driver, support chat, etc.) | Add settlement webhooks / wave dispatcher if needed |
| **Go API (AWS)** | `driver_rest_api_base_url` in `app_config`; Flutter `DriverApi` still calls `/api/v1/driver/*` for status, billing, location, ride steps | **Decommission from production** per cutover checklist |
| **Security** | RLS on most tables; **`founding_contract_links`** and **`launch_regions`** have RLS disabled — fix before launch | RLS on every app table |

---

### What already works (keep, don't rewrite)

1. **Rider booking path** — largely Supabase RPCs (`ride_request_provider`, pricing RPCs).  
2. **Driver accept** — `fn_driver_accept_ride_invite` (atomic).  
3. **Manual street rides** — `fn_driver_create_manual_ride`.  
4. **NL geography** — cities, zones, `country_code` on drivers and ride_requests.  
5. **Push pipeline** — `send-push` Edge Function + `push_devices` (5 tokens).  
6. **Compliance / Veriff** — Edge Functions + rich `drivers` compliance columns.  
7. **Feature flags** — `app_config.feature_flags` (server-readable today).

---

### What must change (priority order)

#### P0 — Launch blockers

| # | Change | Why |
|---|---|---|
| 1 | **`billing_ledger`** + trigger on trip complete (+€1 `ride_fee`) + **€60 outstanding lock** checked in `fn_driver_accept_ride_invite` | Core business model; replaces Go/Mollie subscription gate for V1 |
| 2 | **Retire Go from driver critical path** — migrate `setStatus`, `readiness`, `location`, ride lifecycle to RPCs; clear or null `driver_rest_api_base_url` after cutover | Two backends caused 403/deploy pain; spec says Supabase-only |
| 3 | **Presence + availability** on `drivers` (or side table) + **heartbeat RPC** every 5–10s; tighten `mark_idle_drivers_offline` to ~30s | Ghost drivers break dispatch trust |
| 4 | **Wire `ride_request_invites`** to matching batch + **wave cron** (expire offers, advance waves, cancel-on-accept pushes via `send-push`) | Spec dispatch model; table exists but unused |
| 5 | **`ride_audit_log`** + triggers | Support, disputes, invariant #6 |
| 6 | **RLS** on `founding_contract_links` and `launch_regions` | Security advisor flagged before public launch |

#### P1 — Before 1k drivers

| # | Change | Why |
|---|---|---|
| 7 | **`driver_locations`**: add `geography(Point,4326)` + GiST index (or migrate query path in `get_nearby_drivers` to PostGIS) | Spec eligibility pipeline at scale |
| 8 | **`market_config`** keys: `platform_fee_cents`, `outstanding_limit_cents`, `offer_timeout_seconds`, `search_radius_m` per city | Rotterdam vs Amsterdam tuning without deploys |
| 9 | **Boot config RPC** for Flutter (replace `/api/v1/config` from Go) | Single config source |
| 10 | **Rate limits** on ride create + accept RPCs | Security section |
| 11 | **Driver `user_metadata.user_type = driver`** on signup + JWT role for any legacy paths | Prevents 403 class bugs |

#### P2 — Nice to have for V1, required before multi-city EU

| # | Change |
|---|---|
| 12 | `driver_location_history` (7-day retention) |
| 13 | `driver_sessions` for device revocation (if multi-device becomes a support issue) |
| 14 | Admin read APIs over audit log + live rides view |
| 15 | Apple / Mollie settlement Edge Function for platform fee paydown (€60 unlock) |

---

### Go API cutover checklist (Flutter `DriverApi` → Supabase)

| Go endpoint today | V1 replacement |
|---|---|
| `POST /api/v1/driver/status` | `fn_driver_set_status` RPC |
| `GET /api/v1/driver/readiness` | `fn_driver_readiness` RPC (returns checklist JSON) |
| `POST /api/driver/location` | `fn_driver_heartbeat` RPC (location + presence) |
| `POST /api/driver/ride/arrived|start|complete` | RPCs on `ride_requests` status transitions |
| Billing / payments | `billing_ledger` + settlement RPC + Mollie/IAP webhook Edge Function |
| `GET /api/v1/config` | `fn_get_boot_config` RPC reading `app_config` + `market_config` |

Keep Go code in repo for future matching engine; **do not route production apps to it** until monitoring thresholds are hit.

---

### Schema mapping (don't greenfield)

| Spec name | Use existing |
|---|---|
| `rides` | **`ride_requests`** (primary; 80+ columns, production data) |
| `ride_offers` | **`ride_request_invites`** (extend `batch_no` → `wave`, align status enum) |
| `market_config` | Extend **`app_config.country_config.NL`** or new table keyed by `city_id` |
| `feature_flags` | **`app_config.feature_flags`** (+ per-tenant rows later) |

---

### Scale check: 1,000 drivers × 4 cities in 6 months

| Load (rough) | Supabase V1 capacity |
|---|---|
| ~200–400 drivers online peak per city | Postgres + PostGIS: fine with GiST + eligibility filters |
| Location ping every 5s (~200 writes/s at 1k online) | Upsert `driver_locations`; batch if needed later |
| Realtime subscriptions per ride | Channel per ride/driver, not global broadcast |
| ~5–15k completed rides/month at maturity | Ledger append-only; trivial for Postgres |
| Push on offer + cancel-on-accept | Existing `send-push` + `push_devices` |

**When to re-evaluate Go/Redis:** sustained **>3s dispatch p95**, **>200ms accept RPC p95**, or **>2,000 concurrently online drivers** — per monitoring thresholds in this doc.

---

### Gaps from prior review (still valid)

1. **Dispatch wave orchestrator** — pick `pg_cron` + RPC (already have `pg_cron`); add jobs for offer expiry and wave advance.  
2. **Apple platform-fee settlement** — companion product/legal note for iOS paydown of outstanding fees.  
3. **`driver_sessions`** — only if single-device / stolen-phone revocation is a launch requirement; else defer.  
4. **Mapbox re-rank** — PostGIS distance first; Mapbox ETA in phase 1.5.

### Recommended implementation order

1. `billing_ledger` + lock at €60 + accept guard  
2. Presence / availability / heartbeat (replace single `drivers.status` semantics)  
3. `ride_request_invites` waves + cron + cancel-on-accept push  
4. `ride_audit_log`  
5. `market_config` / NL config keys for four launch cities  
6. Flutter → RPC-only; remove `DriverApi` Dio calls for production  
7. Turn off `driver_rest_api_base_url` → Go  

### Risk if ignored

Running **Supabase + Go** while building this spec **doubles operational cost and failure modes** (auth 403, ECS deploys, split billing truth). For NL launch with 1k-driver ambition, **one production brain: Supabase**.

---

## CTO execution audit (2026-05-20)

Full backend audit per V1 execution prompt (Supabase MCP + codebase review, **no deploys**):

**[HEYCABY-V1-BACKEND-CTO-AUDIT-REPORT.md](./HEYCABY-V1-BACKEND-CTO-AUDIT-REPORT.md)**

Summary: **~52% architecture compliance** · **~70% production health** · **Not ready for TestFlight/App Store** until billing ledger, dispatch waves, and Go strangler complete · **Stack is correct for 1k NL drivers** after consolidation.

**Execution:** [HEYCABY-V1-MIGRATION-ROADMAP.md](./HEYCABY-V1-MIGRATION-ROADMAP.md)

