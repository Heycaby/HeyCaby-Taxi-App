# HeyCaby Rider App — Supabase Schema Sync

> **Consumer inventory, not business-rule authority.** The canonical domain
> ownership and source-of-truth map is
> [`docs/HEYCABY_DOMAIN_SOURCE_OF_TRUTH_AUDIT.md`](../../docs/HEYCABY_DOMAIN_SOURCE_OF_TRUTH_AUDIT.md),
> with machine-readable contracts in
> [`docs/domains/registry.yaml`](../../docs/domains/registry.yaml). If this file
> conflicts with either source, the domain registry and audit win.

This document lists every Supabase table and column the **rider app** reads or writes. Keep backend schema and RLS in sync with this.

**Client:** All rider code uses `HeyCabySupabase.client` (from `heycaby_api`). Never use `Supabase.instance.client` in rider lib.

**Local-only (not Supabase):** The address search screen stores up to **10 recent places on device** (`SharedPreferences`, `local_recent_addresses_provider.dart`) so typing can match recents before calling Mapbox. This is **separate** from **saved places** (`saved_addresses` with types like `home`/`work`) and from **server-backed** recent rows (`saved_addresses.type = 'recent'` via `recent_destinations_provider.dart`).

**Airport shortcut:** `AirportBookingScreen` sets destination from static Benelux airport coordinates in `constants/benelux_airports.dart` (no extra Mapbox call for the list). Pickup still comes from home reverse-geocode or `/search` when missing.

---

## Tables Used by Rider App

### 1. `ride_requests`

**Used in:** `ride_request_provider.dart` through the canonical
`fn_rider_create_ride(jsonb)` command, plus authorized read projections.

| Column / usage | Type / notes |
|----------------|---------------|
| `pickup_coords` | PostGIS geography — `POINT(lng lat)` |
| `destination_coords` | PostGIS geography — `POINT(lng lat)` |
| `pickup_address` | text |
| `destination_address` | text |
| `status` | text — backend command owns initial `'pending'` state |
| `rider_token` | text, optional |
| `rider_identity_id` | uuid, optional |
| `pickup_contact_name` | text, optional |
| `scheduled_pickup_at` | timestamptz (ISO8601), optional |
| `booking_mode` | text — `instant` \| `marketplace` \| `scheduled` (from `BookingNotifier`) |
| `vehicle_category` | text — `standard` \| `comfort` \| `taxibus` \| `wheelchair` (default `standard`) |
| `pet_friendly` | boolean — matching filter vs `drivers.accepts_pets` |
| `payment_methods` | array of text — rider payment screen ids: `cash`, `pin`, `tikkie` (omit if column missing in your project) |

**Flow:** "Find my driver" → `fn_rider_create_ride` validates actor/session,
input fields, route estimates, audience and fare snapshot, then inserts one
idempotent row. Database triggers start canonical matching. One app-global
`RiderLiveActivityScope` channel delivers lifecycle invalidation and
`fn_rider_ride_snapshot` rehydrates authoritative state.

### RPCs (matching)

| Name | Called by | Purpose |
|------|-----------|---------|
| `fn_seed_ride_matching_batch(p_ride_request_id, p_batch_size, p_window_seconds)` | DB trigger + rider `SearchingScreen` timer | Closest eligible drivers get `ride_request_invites` rows |
| `fn_driver_accept_ride_invite(p_ride_request_id)` | Driver app (`DriverApi.acceptRide`) | Atomic assign: `ride_requests.status = assigned`, `driver_id` set, other invites superseded |

### `ride_request_invites`

Drivers receive **Realtime** `INSERT` events (enable replication for this table in Supabase). RLS: authenticated drivers `SELECT` their own rows.

### `drivers` (read)

**Used in:** `nearby_supply_service.dart` — `select id, vehicle_category` for drivers returned from `driver_locations` (supply cards). If RLS blocks reads, supply falls back to hash-based category per driver.

---

### 2. `rider_identities`

**Used in:** `ride_request_provider`, `home_screen` (home address), `email_modal`, `home_address_modal`, `recent_destinations_provider`

| Column | Usage |
|--------|--------|
| `id` | Lookup by `id` (identity id from secure storage) |
| `user_id` | Optional link to `auth.users.id`; used in recent_destinations for lookup |
| `home_address`, `home_lat`, `home_lng` | Home address (home_screen, modals) |
| Updated via `heycaby_api` secure storage + upsert/update for email, booking name, home |

**Note:** Rider identity id and token come from app flow (e.g. onboarding) and are stored in secure storage; they are sent with `ride_requests` and chat `sender_id`.

#### TAF — invite codes & attribution (`invite_codes` via RPC)

**Share / copy in the Rider app:** `rider_invite_url_provider.dart` exposes **`riderInviteShareUrl`** (`heycaby_api`), which is **`kAppPublicSiteRoot`** only (plain homepage from `APP_PUBLIC_WEB_ORIGIN`; no `/invite`, `/i/…`, or query). Personal codes are **not** embedded in the shared URL.

**Still used for:** web `/i/{code}` deep links, universal-link attribution (`RiderInviteAttributionScope`), and the “friends invited” gauge via `fn_my_invited_friends_count`.

| Supabase object | Purpose |
|-----------------|---------|
| Table `invite_codes` | 7-character `code` mapped to `rider_identity_id` or `driver_id` (no direct client `SELECT`; RLS relies on `SECURITY DEFINER` RPCs) |
| `fn_ensure_rider_invite_code()` | **authenticated** — returns existing code or inserts one; used where the app or web needs a **code** (not the in-app TAF share URL) |
| `fn_lookup_invite_code(p_code text)` | **anon, authenticated** — JSON with `rider_identity_id` / `driver_id` for web `/i/{code}` landing |
| Table `rider_invite_signups` | One row per **invitee** rider identity attributed to an inviter’s short code (no direct client `SELECT`; RPC-only). |
| `fn_my_invited_friends_count()` | **authenticated** — count of riders who joined via your `/i/{code}` (TAF “friends invited” gauge). |
| `fn_record_rider_invite_attribution(p_invite_code text)` | **authenticated** — invitee calls once after opening an invite link; idempotent; skips self and non-rider codes. |

**Deploy:** apply `supabase/migrations/20260408120000_invite_short_codes.sql`, then `supabase/migrations/20260409120000_rider_invite_signups.sql`. The rider app stores a pending `/i/{code}` from universal links (`RiderInviteAttributionScope`) and flushes it after sign-in.

---

### 3. `driver_locations`

**Used in:** `home_screen` (nearby count + bounds query), `driver_tracking_provider` (realtime + fetch by ride)

| Column | Usage |
|--------|--------|
| `lat`, `lng` | Numbers — used in queries and for map position |
| `driver_id` | uuid |
| `ride_id` | uuid — ride_request id when driver is assigned |
| `updated_at` | timestamptz |
| `heading` | optional number (driver bearing) |
| `status` | home_screen filters `.eq('status', 'online_available')` |

**Home screen:** Counts rows in bounding box (lat/lng ± delta).  
**Vehicle category (supply cards):** `nearby_supply_service.dart` selects `driver_id, lat, lng, updated_at` with the same `status = online_available` filter and a pickup-centered bbox (see `NearbySupplyService.searchRadiusKm`).  
**Active ride:** `driver_tracking_provider` subscribes to updates where `ride_id` = current `rideRequestId` and fetches initial location.

---

### 4. `rides`

**Used in:** `ride_history_provider.dart`

| Column | Usage |
|--------|--------|
| `id` | Primary key |
| `rider_id` | uuid — rider app uses `auth.currentUser?.id` for filter |
| `status` | Filter: active = pending/assigned/arrived/in_progress; bidding = marketplace; completed; cancelled |
| `pickup_address`, `destination_address` | text |
| `fare` | number, optional |
| `created_at`, `completed_at` | timestamptz |
| `driver_id` | Optional join for driver name/photo |

**Query:** `.eq('rider_id', userId).order('created_at', ascending: false)` with optional `.inFilter('status', ...)` or `.eq('status', ...)`.

---

### 5. `chat_messages`

**Used in:** `chat_provider.dart` (select, insert, realtime, update is_read)

| Column | Usage |
|--------|--------|
| `id` | uuid |
| `ride_id` | uuid — in rider app this is `rideRequestId` (ride_requests.id) |
| `sender_id` | uuid, required — rider sends `riderIdentityId ?? auth.uid` |
| `sender_type` | text — rider sends `'rider'` |
| `message` | text |
| `is_read` | boolean, default false |
| `created_at` | timestamptz |

**Realtime:** Subscription on `ride_id` for INSERT.

---

### 6. `ride_ratings`

**Used in:** `rating_screen.dart` (insert)

| Column | Usage |
|--------|--------|
| `ride_id` | uuid — rider sends `rideRequestProvider.rideRequestId` (if your schema uses ride_requests.id here, keep it; otherwise use the completed ride id from `rides`) |
| `rating` | integer 1–5 |
| `feedback` | text, optional |
| `tags` | text[] (e.g. quick feedback tags) |

---

### 7. `ride_reports`

**Used in:** `report_screen.dart` (insert)

| Column | Usage |
|--------|--------|
| `ride_id` | uuid — rider sends `rideRequestProvider.rideRequestId` |
| `reason` | text |
| `details` | text, optional |
| `status` | text — rider sends `'pending'` |

---

### 8. `favorite_drivers`

**Used in:** `favorites_provider.dart` (select, insert, delete)

| Column | Usage |
|--------|--------|
| `id` | uuid |
| `rider_id` | uuid — `auth.currentUser?.id` |
| `driver_id` | uuid — FK to drivers |
| `created_at` | timestamptz |

**Select:** Join to `drivers` for name, photo_url, rating, total_rides.

---

### 9. `saved_addresses`

**Used in:** `saved_addresses_provider.dart`, `recent_destinations_provider.dart`, `saved_addresses_sheet.dart`, `search_quick_picks_section.dart`

| Column | Usage |
|--------|--------|
| `id` | uuid |
| `rider_identity_id` | uuid |
| `type` | text — e.g. `'home'`, `'work'`, `'gym'`, `'custom'`, `'recent'` (multiple rows per type allowed, e.g. several homes with different labels) |
| `label` | text |
| `full_address` | text |
| `latitude`, `longitude` | numbers |
| `used_at` | timestamptz — set for `type = 'recent'` when recording trips |
| `created_at`, `updated_at` | timestamptz |

**Queries:** List all by `rider_identity_id` for the saved-places UI. Recent list: `type = 'recent'` ordered by `used_at` desc. No unique constraint on `(rider_identity_id, type)` — migration `20260403200000_saved_addresses_multi_per_type_and_used_at.sql`.

---

## Realtime Subscriptions (Rider)

| Channel | Table | Filter | Used in |
|---------|--------|--------|--------|
| `rider_ride_lifecycle_engine:$id` | ride_requests | id | app-global lifecycle engine; Searching, Marketplace, Taxi Terug and Active Ride consume its projection |
| `messages:$rideId` | messages | ride_request_id | canonical chat provider; unread state derives from this projection |
| driver tracking scope | driver_locations | authorized ride projection | driver position updates |

---

## Auth

- **Favorites, ride history, recent destinations:** use `HeyCabySupabase.client.auth.currentUser?.id` as `rider_id` / `user_id` where applicable.
- **Ride creation, chat sender:** use `rider_identity_id` and `rider_token` from `riderIdentityProvider` (secure storage); chat `sender_id` = identity id or auth uid.

---

## Frontend–backend sync (wiring)

- **Ride flow:** `RideRequestNotifier.createRide()` calls
  `fn_rider_create_ride`; `RiderLiveActivityScope` owns the single
  `ride_requests` lifecycle subscription and refreshes
  `fn_rider_ride_snapshot`. Screens render the shared engine projection.
- **Identity:** All rider code uses `HeyCabySupabase.client` (from `heycaby_api`). Rider identity comes from secure storage (`rider_identity_provider`); `saveBookingName` / `saveEmail` update both storage and `rider_identities` in Supabase. Home address is read/updated in `rider_identities` from `HomeScreen` / `HomeAddressModal`.
- **Chat:** `ChatNotifier` reads **`messages`** and sends through the
  actor-bound, idempotent `fn_send_ride_message` command. Realtime is delivery
  only; reconnect always re-fetches canonical ordered history.
- **Account deletion (App Store):** RPC `fn_delete_rider_account(p_session_token)` — token is the same value stored as `rider_token` in secure storage. Requires `rider_sessions.session_token` → `rider_identity_id` on the backend.
- **Recent destinations:** Use `saved_addresses` by `rider_identity_id`. Identity is resolved from auth (`user_id` → `rider_identities.id`) or, when not logged in, from `riderIdentityProvider` (progressive identity).
- **Ride history / favorites:** Use `rides` and `favorite_drivers` with `rider_id` = `auth.currentUser?.id`. Favorites join to `drivers` (alias `driver` or `drivers` supported).
- **Driver location:** Initial fetch uses `maybeSingle()` so missing row (e.g. driver not assigned yet) does not throw.

Keep this file updated when adding or changing any rider Supabase usage.
