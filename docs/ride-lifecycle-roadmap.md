# Ride Lifecycle Roadmap (CTO Phase 2)

> **Rule:** Do not build Phase 2B+ until Phase 2A matrix is 100% green on staging with log evidence.

## Architecture target

```
Driver Action → RPC → Supabase → driver-agent → APNs Live Activity Push → ActivityKit → Lock Screen
```

Until APNs push ships, client path:

```
Trigger (realtime / FCM / poll / resume)
        ↓
refreshRideState()  — RiderRideLifecycleEngine
        ↓
RiderNotifyLiveActivity.createOrUpdateActivity()  ← only ActivityKit entry
```

---

## Phase 2A — Prove lifecycle matrix (NOW)

**Goal:** Every driver action produces RPC → DB → Realtime → Notification → Lifecycle Engine → Widget.

### Backend proof

Migration: `20260710100000_ride_lifecycle_matrix_audit.sql`

```sql
SELECT jsonb_pretty(fn_ride_lifecycle_matrix_audit('<ride_id>'));
```

Or:

```bash
chmod +x scripts/staging_ride_lifecycle_audit.sh
./scripts/staging_ride_lifecycle_audit.sh --latest-completed
./scripts/staging_ride_lifecycle_audit.sh <ride_id>
```

### Client proof (device logs)

Grep Xcode console for:

| Log prefix | Matrix column |
|------------|---------------|
| `[LifecycleProof] … channel=lifecycle_engine` | Ride Lifecycle Engine |
| `[LifecycleProof] … channel=widget` | Widget (ActivityKit) |
| `[RideLifecycleEngine] refreshRideState` | Engine refresh source |

### Full test script (two phones)

1. Rider books → lock phone  
2. Driver: Accept → On my way → (wait nearby) → Arrived → wait 10s → Start → Complete  
3. Driver: collect payment  
4. Rider: confirm payment → rate → favorite (optional)  
5. Run `fn_ride_lifecycle_matrix_audit` on ride id  
6. All **required** steps must show `"green": true` and `"all_required_green": true`

### Staging sample (2026-07-09)

Ride `3a030e7e-70fd-435e-8fea-f21098493de8` — completed full loop with payment + rating.  
Note: driver skipped explicit **on my way** (accepted → nearby → arrived). Matrix marks `driver_on_way` as optional when later steps completed.

---

## Phase 2B — APNs Live Activity push

**Prerequisite:** Phase 2A green.

1. Capture ActivityKit push token from `live_activities` plugin on rider device  
2. Store token on `rider_identities` (or ride-scoped table)  
3. Extend `driver-agent` on `ride_requests` UPDATE → build payload → APNs `pushType: liveactivity`  
4. Reuse payload shape + `rideVersion` from client engine  
5. Verify widget updates with app **force-quit**

---

## Phase 2C — Canonical `ride_events` stream

**Prerequisite:** Phase 2B staging pass.

Foundation already started:

- `ride_events` **VIEW** maps `ride_audit_log` → canonical event types  
- Target: dedicated `ride_events` **table** with trigger on `fn_ride_audit_append`  
- Consumers: widgets, Rider UI, Driver UI, analytics, admin, support

Canonical types:

`ride_created`, `driver_invited`, `driver_accepted`, `driver_on_way`, `driver_nearby`, `driver_arrived`, `ride_started`, `ride_completed`, `payment_confirmed`, `receipt_created`, `ride_rated`, `driver_favorited`

---

## Phase 2D — Remove 5s poll

**Prerequisite:** Phase 2B verified on suspended/killed app.

Remove `Timer.periodic(5s)` from `RiderLiveActivityScope`. Keep app-resume refresh as safety net only.

---

## Rename: RideLifecycleEngine

| Old | New |
|-----|-----|
| `RiderRideStateEngine` | `RiderRideLifecycleEngine` |
| `riderRideStateEngineProvider` | `riderRideLifecycleEngineProvider` |
| `rider_ride_state_engine.dart` | `rider_ride_lifecycle_engine.dart` |

Legacy aliases deprecated in `rider_ride_lifecycle_engine.dart` for one release cycle.

---

*Last updated: 2026-07-10*
