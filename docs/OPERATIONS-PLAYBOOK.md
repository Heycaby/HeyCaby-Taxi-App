# Operations Playbook

**Status:** Canonical support + incident manual  
**Audience:** Support, ops, on-call engineering, founders  
**Not:** Code architecture (see [ENGINEERING-BIBLE.md](./ENGINEERING-BIBLE.md)) or ride states (see [RIDE_STATE_MACHINE.md](../apps/driver/docs/RIDE_STATE_MACHINE.md))

**Last updated:** 2026-05-19

---

## Purpose

When a driver (or rider) reports a problem, support and engineering follow **the same steps**. No guessing.

Every procedure includes:

1. **Triage questions** (30 seconds)  
2. **Expected correct behavior** (from RIDE_STATE_MACHINE)  
3. **Diagnostic steps** (app + SQL + logs)  
4. **Resolution** (driver action vs backend fix vs eng ticket)  
5. **Close-out** (mark ticket, audit note if needed)

---

## Quick reference

| Driver says | Section |
|-------------|---------|
| "Passenger cancelled but I still see the ride" | [§1 Rider cancelled, ghost ride](#1-rider-cancelled-ghost-ride-on-driver) |
| "Ride disappeared" | [§2 Ride disappeared mid-trip](#2-ride-disappeared-mid-trip) |
| "Navigation won't open" | [§3 Navigation won't open](#3-navigation-wont-open) |
| "I'm online but no requests" | [§4 Online but no ride offers](#4-online-but-no-ride-offers) |
| "App shows offline after I went online" | [§5 Status mismatch offline vs server](#5-status-mismatch-offline-vs-server) |
| "Billing locked / can't go online" | [§6 Billing locked](#6-billing-locked) |
| "Paid but still blocked" | [§7 Payment made, still blocked](#7-payment-made-still-blocked) |
| "Logged in on two phones" | [§8 Duplicate session](#8-duplicate-session) |
| "No-show button greyed out" | [§9 No-show not available](#9-no-show-not-available) |
| "Missed ride / no sound" | [§10 Missed offer / no alert](#10-missed-offer--no-alert) |
| "Earnings wrong today" | [§11 Earnings mismatch](#11-earnings-mismatch) |
| "Documents / verification stuck" | [§12 Compliance / Veriff stuck](#12-compliance--veriff-stuck) |

---

## Diagnostic primitives

### A. Identify driver

Collect:

- Driver phone / email  
- `driver_id` (UUID) — from Supabase `drivers.user_id` = auth user  
- App version + iOS version  
- Approximate time (UTC)

```sql
-- By email (auth.users)
SELECT d.id AS driver_id, d.status, d.current_shift_id,
       d.shift_started_at, d.shift_rides_today, d.shift_earnings_today,
       d.profile_status, d.country_code
FROM public.drivers d
JOIN auth.users u ON u.id = d.user_id
WHERE u.email ILIKE '%DRIVER_EMAIL%';
```

### B. Active ride

```sql
SELECT id, status, driver_id, pickup_address, destination_address,
       created_at, updated_at, cancelled_at, cancel_reason
FROM public.ride_requests
WHERE driver_id = 'DRIVER_UUID'
  AND status NOT IN ('completed', 'closed', 'cancelled')
ORDER BY updated_at DESC
LIMIT 5;
```

### C. Ride audit trail

```sql
SELECT occurred_at, event_type, actor_id, metadata
FROM public.ride_audit_log
WHERE ride_id = 'RIDE_UUID'
ORDER BY occurred_at;
```

*(Table name per migration `20260520120000` — verify column names in env.)*

### D. Recent notifications (driver)

```sql
SELECT id, category, title, created_at, read_at, data
FROM public.notifications
WHERE user_id = 'DRIVER_USER_UUID'
ORDER BY created_at DESC
LIMIT 20;
```

### E. Location freshness

```sql
SELECT driver_id, lat, lng, updated_at, current_zone_id, country_code
FROM public.driver_locations
WHERE driver_id = 'DRIVER_UUID';
```

**Healthy:** `updated_at` within last **30 seconds** while driver claims online.

### F. Connectivity events (M14)

```sql
SELECT event_type, layer, occurred_at, metadata
FROM public.driver_connectivity_events
WHERE driver_id = 'DRIVER_UUID'
ORDER BY occurred_at DESC
LIMIT 30;
```

### G. Billing eligibility

```sql
SELECT public.fn_driver_can_accept_rides('DRIVER_UUID'::uuid);
SELECT public.fn_driver_billing_summary('DRIVER_UUID'::uuid);
```

### H. Logs

- **Client:** Ask driver for screen recording; check device time sync  
- **Backend:** Supabase logs, driver-agent edge function, Go API `/api/driver/*`  
- **APM:** Datadog (if configured) — filter `driver_id`, `ride_request_id`

---

## Incident procedures

### 1. Rider cancelled, ghost ride on driver

**Report:** *"Passenger cancelled but I still see the ride / map / navigation."*

**Expected (after Program 3C):** Full-screen modal → ride cleared → home → online.

**Current gap:** SnackBar only; local Riverpod may retain `activeRideId`.

#### Triage

1. Is driver still on `/driver/ride/active|pickup|progress`?  
2. When did rider cancel (driver local time)?  
3. Did driver see any notification?

#### Diagnose

```sql
SELECT id, status, updated_at FROM public.ride_requests WHERE id = 'RIDE_UUID';
```

If `status = 'cancelled'` but driver app shows active → **client state desync**.

Check push:

```sql
SELECT * FROM public.notifications
WHERE data->>'ride_request_id' = 'RIDE_UUID'
  AND category = 'ride_phase'
ORDER BY created_at DESC LIMIT 3;
```

#### Resolution

**Immediate (support script):**

1. Ask driver to **force-quit app** and reopen (after 3B: should auto-clear).  
2. If still stuck: toggle **Offline → Online** on home sheet.  
3. If still stuck: **logout and login** (last resort).

**Engineering (if recurring):**

- Ticket: Program 3C — rider cancel modal + `clearActiveRide()` on `ride_phase`  
- Priority: **P0**

#### Close-out

- Note `ride_id`, `driver_id`, whether notification row exists  
- Tag: `ghost-ride`, `rider-cancel`

---

### 2. Ride disappeared mid-trip

**Report:** *"Ride vanished / app went to home / I lost the passenger."*

#### Triage

- Phone reboot? App crash? Accidental back swipe?  
- Billing block mid-shift?

#### Diagnose

```sql
-- Ride terminal state?
SELECT id, status, driver_id, updated_at FROM public.ride_requests WHERE id = 'RIDE_UUID';

-- Driver status
SELECT status, current_shift_id FROM public.drivers WHERE id = 'DRIVER_UUID';
```

| SQL result | Likely cause |
|------------|--------------|
| `cancelled` | Rider or system cancel — see §1 |
| `completed` | Trip ended server-side |
| Still `in_progress` / `driver_arrived` | **Client lost state** — Program 3B |
| `drivers.status = offline` | Driver went offline or session ended |

#### Resolution

**If ride still active in DB:**

1. Until 3B ships: support cannot restore UI — escalate eng with ride_id  
2. After 3B: driver reopens app → should land on correct ride screen  
3. **Do not** manually change `ride_requests.status` without eng + audit entry

**If ride cancelled/completed:**

1. Explain terminal state to driver  
2. Confirm earnings on `driver_finance` / today rides list

#### Close-out

- Request app version; check `ride_audit_log` for last transition

---

### 3. Navigation won't open

**Report:** *"Navigate button does nothing / Maps won't open."*

#### Triage

- Waze or Google installed?  
- Which screen (active trip vs in-progress vs hotspots)?  
- Pickup coords missing?

#### Diagnose

```sql
SELECT pickup_lat, pickup_lng, destination_lat, destination_lng, pickup_address
FROM public.ride_requests WHERE id = 'RIDE_UUID';
```

If lat/lng **NULL** → data issue; navigation cannot work.

#### Resolution

| Cause | Action |
|-------|--------|
| No coords | Driver uses address manually; file data bug |
| Google Maps not installed | Install Google Maps or Waze; use web fallback URL |
| iOS permission | Settings → HeyCaby → allow relevant permissions |
| In-progress screen | **Known gap** — nav only on active trip until Program 3D |

**Workaround:** Copy address from ride screen → open Waze manually → paste/search.

#### Close-out

- Tag: `navigation`, `3D`

---

### 4. Online but no ride offers

**Report:** *"I'm online hours, no requests."*

#### Triage

1. Confirm driver **sees** Online (green) on map pill  
2. Zone / city correct?  
3. Billing blocked?  
4. Documents approved?

#### Diagnose

```sql
SELECT d.status, d.profile_status,
       (SELECT updated_at FROM driver_locations dl WHERE dl.driver_id = d.id) AS loc_updated
FROM drivers d WHERE d.id = 'DRIVER_UUID';

SELECT public.fn_driver_can_accept_rides('DRIVER_UUID'::uuid);
```

```sql
-- Recent invites
SELECT * FROM ride_request_invites
WHERE driver_id = 'DRIVER_UUID'
ORDER BY created_at DESC LIMIT 10;
```

#### Resolution

| Finding | Action |
|---------|--------|
| `drivers.status != 'available'` | Toggle online; check break state |
| Stale `driver_locations` | **Program 3A** — GPS not uploading; restart app, check location permission Always |
| `fn_driver_can_accept_rides` false | See §6 billing or documents |
| Invites exist but no UI | Realtime/FCM issue — Program 3C |
| No invites in DB | Dispatch/market issue — not support-fixable; ops |

---

### 5. Status mismatch (offline vs server)

**Report:** *"App says offline but I was online / opposite."*

**Root cause (known):** Cold start hydrates auth but not `drivers.status` (Program 3B).

#### Diagnose

```sql
SELECT status, shift_started_at, current_shift_id FROM drivers WHERE id = 'DRIVER_UUID';
```

Compare to app UI.

#### Resolution

1. Ask driver to toggle to intended state once  
2. After 3B: reinstall not required — bootstrap should sync  
3. If server says `available` but no GPS rows → see §4

---

### 6. Billing locked

**Report:** *"Can't go online / can't accept — billing."*

#### Triage

- Platform fee model (weekly threshold €60 NL)?  
- Mollie vs Apple IAP?

#### Diagnose

```sql
SELECT public.fn_driver_billing_summary('DRIVER_UUID'::uuid);
SELECT public.fn_driver_can_accept_rides('DRIVER_UUID'::uuid);
```

In app: `/driver/billing` screen state.

#### Resolution

1. Direct driver to **Billing** in app (drawer or runtime gate link)  
2. Explain: HeyCaby charges **platform subscription**, not ride commission  
3. After payment webhook: ask driver to pull-to-refresh or toggle offline/online  
4. If webhook delayed >15 min: check Mollie/IAP ledger — eng ticket

**Support must not** manually set billing flags in DB.

---

### 7. Payment made, still blocked

#### Diagnose

```sql
SELECT * FROM public.billing_ledger
WHERE driver_id = 'DRIVER_UUID'
ORDER BY created_at DESC LIMIT 10;
```

Check `fn_driver_platform_health` if exposed.

#### Resolution

1. Wait 5 min for webhook  
2. Force app restart  
3. If ledger shows payment but RPC still blocks → **P0 eng** — eligibility cache bug

---

### 8. Duplicate session

**Report:** *"Other phone / logged in elsewhere / weird behavior."*

**Current:** No client detection (Program 3E).

#### Resolution (today)

1. Ask driver to **logout all devices**: logout on each phone  
2. Login on primary device only  
3. Change password if suspicious  

#### Future (3E)

Server emits `session_revoked` → force logout modal.

---

### 9. No-show not available

**Report:** *"Can't report no-show."*

**Rule:** Button enabled after **300 seconds** wait at pickup (`at_pickup_screen.dart`).

#### Resolution

1. Confirm driver tapped **I've arrived** first  
2. Wait 5 minutes on pickup screen  
3. If still disabled: verify `ride_requests.status = 'driver_arrived'`

---

### 10. Missed offer / no alert

#### Triage

- Phone on silent?  
- App in background?  
- Focus mode / DND?

#### Diagnose

- Foreground + online: should use **realtime** + sound  
- Background: depends on FCM (Program 3C gap)

```sql
SELECT * FROM ride_request_invites
WHERE driver_id = 'DRIVER_UUID' AND created_at > now() - interval '1 day'
ORDER BY created_at DESC;
```

#### Resolution

1. Settings → HeyCaby → Notifications ON  
2. Preferences → ride ringtone  
3. Keep app foreground until 3C ships background offer UX  
4. Check invite existed → if yes, FCM/realtime bug

---

### 11. Earnings mismatch

#### Diagnose

```sql
SELECT shift_rides_today, shift_earnings_today FROM drivers WHERE id = 'DRIVER_UUID';

SELECT id, status, driver_earnings_cents, completed_at
FROM ride_requests
WHERE driver_id = 'DRIVER_UUID'
  AND completed_at::date = CURRENT_DATE;
```

Compare to app Finance / today rides.

#### Resolution

1. Manual rides: confirm logged via manual entry  
2. Pending vs completed status  
3. Eng if cents null on completed rows (known hotfix migration history)

---

### 12. Compliance / Veriff stuck

#### Diagnose

```sql
SELECT profile_status, veriff_status FROM drivers WHERE id = 'DRIVER_UUID';
```

App: `/driver/documents`, readiness checklist.

#### Resolution

1. Complete Veriff flow in app  
2. Wait for webhook (up to 24h)  
3. Escalate if `profile_status` stuck >48h with submitted docs

---

## Escalation matrix

| Severity | Examples | Response |
|----------|----------|----------|
| **S1 Critical** | Active ride orphan; payment double-charge; safety | Eng immediate + founder |
| **S2 High** | Ghost ride; billing blocked wrongly; no GPS 1h online | Eng same day |
| **S3 Medium** | Nav won't open; missed offer; UI confusion | Support script + ticket |
| **S4 Low** | How-to, preferences, community | Support only |

---

## Engineering ticket template

```
Title: [P0|P1] Program 3X — short description
Driver ID:
Ride ID:
App version:
Steps:
SQL output:
Expected (RIDE_STATE_MACHINE §):
Actual:
Recording: Y/N
```

---

## Support macros (customer-facing — NL)

**Rider cancelled (until 3C fix):**  
*"De rit is geannuleerd door de passagier. Sluit de app volledig af en open opnieuw. Ga daarna weer online via de schuifregelaar. Je bent weer beschikbaar voor nieuwe ritten."*

**Billing:**  
*"HeyCaby rekent geen commissie op ritten. Dit is het platformabonnement. Open Facturatie in het menu om te betalen."*

**Navigation workaround:**  
*"Tap op Navigeren op het ophaalscherm. Als dat niet werkt, open Waze handmatig en zoek op het ophaaladres op het scherm."*

---

## Playbook maintenance

| When | Action |
|------|--------|
| New incident type in production | Add section within 48h |
| Program 3A–3E closes a gap | Update "Current gap" notes to ✅ |
| Launch simulation finds failure | New procedure + roadmap item |

**Owners:** Product + eng on-call rotate monthly review.

---

## Related documents

| Doc | Link |
|-----|------|
| Launch program order | [HEYCABY-LAUNCH-ROADMAP.md](./HEYCABY-LAUNCH-ROADMAP.md) |
| Ride states & recovery spec | [RIDE_STATE_MACHINE.md](../apps/driver/docs/RIDE_STATE_MACHINE.md) |
| TRB / deploy gates | [TECHNICAL-REVIEW-BOARD.md](./TECHNICAL-REVIEW-BOARD.md) |
| Platform programs | [PLATFORM-PLAYBOOK.md](./PLATFORM-PLAYBOOK.md) |

---

*Support empathy + SQL truth + clear eng handoff = drivers trust HeyCaby on a 12-hour shift.*
