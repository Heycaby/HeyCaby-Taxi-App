# HeyCaby Duplicate and Realtime Stabilization Audit

Status: **IN PROGRESS — overall release verdict remains NO-GO**  
Production Supabase: `fvrprxguoternoxnyhoj`  
Last updated: 2026-07-14 (Europe/Amsterdam)

This document is the release evidence record required by the CTO duplicate,
Realtime, and synchronization audit. The authoritative domain map is
`docs/domains/registry.yaml`. Product and compatibility decisions that are not
yet approved remain in `docs/domains/COMPATIBILITY_DECISION_LOG.md`.
The repository-owned Admin surface and its external-consumer gap are recorded
in `docs/domains/ADMIN_CONTRACT_AUDIT.md`.

No staging backend is used. All remote evidence below comes from production.

## 1. Executive summary

The shared-ride/family-tracking path was traced from the Rider UI through the
token RPC, Supabase table, public Edge projection, Vercel route, and rendered
browser. A production defect was confirmed: `/track/<token>` was rewritten to a
legacy Vercel application, but the returned Next.js asset URLs resolved against
the current domain and did not hydrate. Viewers remained on `Loading ride...`
indefinitely, including for invalid or expired tokens.

The route is now owned and deployed from `apps/marketing`, the canonical data
projection remains the production `get-shared-ride` Edge Function, and both
`heycaby.nl` and `www.heycaby.nl` point to the verified production deployment.
Invalid and expired links now terminate in a clear state. A real moving-trip
two-phone acceptance test is still required; no customer ride was modified to
manufacture that evidence.

The production dispatch inventory also exposed a confirmed command-boundary
regression: the public three-argument `fn_seed_ride_matching_batch` contained a
second copy of dispatch-v3 instead of routing `booking_mode='terug'` to the Taxi
Terug matcher. Six internal/scheduled `SECURITY DEFINER` helpers were directly
callable by `anon` and/or `authenticated`. Migration
`20260714060013:canonical_dispatch_seed_boundary` restored one auth-bound
booking-mode router while keeping both released RPC signatures.

## 2. Codebase duplicate inventory

| Domain | Duplicate/conflict | Classification | Canonical path | Action |
|---|---|---|---|---|
| Shared ride tracking | Source-controlled `get-shared-ride` plus external `rydtap-web-app` viewer | Conflicting implementation | Supabase Edge projection + `apps/marketing/app/track/[token]` | Removed `/track` legacy rewrite; internalized viewer |
| Shared ride token creation | Historical token-only authorization versus later auth-bound function | Legacy security conflict | `fn_rider_create_share_token(uuid,text)` auth-bound RPC | Replaced in corrective migration; signature retained for released clients |
| Shared ride state | `ride_requests.share_*` mirror plus `ride_shares` | Intentional compatibility projection | `ride_shares` owns token lifecycle | Mirror trigger retained; not treated as command authority |
| Dispatch seeding | Public canonical name and `fn_seed_ride_matching_batch_dispatch_v3` each contained independent dispatch-v3 implementations | Conflicting implementation | Auth-bound `fn_seed_ride_matching_batch` booking-mode router | Router restored; dispatch-v3 and Taxi Terug helpers made service-only |
| Dispatch compatibility | `fn_seed_ride_matching_batch_legacy` remains as the feature-flag fallback | Legacy compatibility path | Canonical router selects current implementation; backend config may select legacy internally | Function retained for rollback, direct Data API execution removed |
| Dispatch jobs/diagnostics | Wave advance, scheduled seed, and invite diagnostic RPCs were client-callable | Exposed internal commands | `pg_cron`, backend functions, and service role | `anon`/`authenticated` execution revoked without dropping functions |
| Driver ride boards | Shell-mounted Scheduled/Today and Taxi Terug listeners each opened a broad `ride_requests` channel; Today also refreshed through a second filtered handler on the same channel | Exact duplicate delivery/invalidation | `DriverScheduledRidesRealtimeListener` owns one board invalidation channel | Consolidated Taxi Terug refresh into the shared board listener; removed duplicate Today handler and second widget |
| Shared tracking API routing | Broad `beforeFiles` `/api/*` compatibility rewrite shadowed the source-controlled `/api/shared-ride` route | Conflicting implementation | Local `/api/shared-ride`; legacy API only as fallback | Moved legacy rewrite to `fallback`, smoke-tested both paths |
| Shared tracking token transport | Viewer and proxy placed the capability token in query strings recorded by infrastructure logs | Security/privacy conflict | POST JSON body through Vercel and Edge | New calls use POST; GET retained temporarily only for loaded-bundle compatibility |
| Shared tracking terminal handling | Edge location query ran whenever `driver_id` existed, even when tracking was inactive; null/404 browser state continued polling | Conflicting lifecycle/privacy logic | Backend `tracking_active` gates location; only loaded non-terminal projections poll | Fixed Edge gate and browser scheduler; added contract tests |
| Incoming ride delivery | Webhook payload expiry was checked while building intent, but delivery did not re-fetch invite/ride liveness immediately before notification insertion and provider send | Conflicting stale-event path | `incomingRideGate` + FCM/APNs provider expiry | Added authoritative double gate, earliest-deadline transport expiry, and suppression reason logs |
| Driver foreground offer presentation | Foreground FCM delivery could invoke the CallKit presentation path while notification taps used the backend-validating coordinator | Conflicting client path / prohibited transport semantics | `DriverIncomingRideCoordinator.openIncomingRide` | Foreground and tap paths now re-fetch the exact invite and ride; normal taxi offers do not use CallKit/VoIP semantics |
| Driver background offer presentation | Background FCM still converted normal ride offers into CallKit calls, bypassing exact-invite validation | Conflicting client path / prohibited transport semantics | Standard FCM notification + `DriverIncomingRideCoordinator` | Removed the CallKit service/scope/package and Android phone-call/full-screen permissions; background handler now only initializes Firebase |
| Taxi Terug offer increase | Shared Rider boost command rejected `booking_mode='terug'`, optimistically changed Flutter state before backend success, and produced neither a dedicated delivery event nor board refresh | Missing backend authority and delivery path | `fn_rider_boost_marketplace_offer` + `driver-agent` + canonical Driver Taxi Terug providers | Backend now locks and calculates old/new/delta, updates one fare snapshot, audits/enqueues once, gates each delivery against live state/eligibility, and Driver clients invalidate canonical projections |
| Marketplace cancellation | Rider called the cancellation RPC and then independently expired `ride_bids` in Flutter | Exact duplicate business mutation | `fn_rider_cancel_open_ride` + `trg_expire_marketplace_bids_on_terminal_ride` | Removed direct Flutter bid update; backend transaction owns ride and bid terminal state |
| Rider booking creation | Rider constructed and inserted the initial `ride_requests` row directly, including lifecycle, geography, identity, audience, and fare projections | Frontend business command and retry-duplication risk | `fn_rider_create_ride(jsonb)` | Current Rider calls one actor-bound, field-limited, idempotent backend command; legacy INSERT policy remains solely for released-app compatibility |
| Accept-time fare snapshot | Driver Flutter calculated its active tariff after acceptance and directly updated `ride_requests.offered_fare`, `quoted_fare`, and `estimated_fare` best-effort | Conflicting client business mutation | `accept_fare_snapshot_authority` backend trigger | Moved the identical formula into the atomic acceptance transition, preserved existing quotes, added audit monitoring, and removed the Flutter write |
| Ride chat send | Rider chat, Driver chat, and Rider pings each inserted `messages` directly; retries had no stable key and Driver/Rider reconnect did not always re-fetch canonical history | Conflicting client commands / reliability gap | `fn_send_ride_message` + ordered canonical query | Migrated all three current callers, added sender-scoped idempotency, conversation binding, optimistic reconciliation, and reconnect recovery |
| Chat moderation identity | Three released `SECURITY DEFINER` moderation RPCs trusted caller-supplied participant IDs and were executable by anonymous/public roles | Legacy compatibility security conflict | Authenticated actor derived by `private.fn_ride_chat_actor` | Preserved signatures/grants for compatibility but bound every operation to `auth.uid()`; anonymous calls fail closed |
| Chat push retries | Repeated message webhooks could create more than one push intent because notifications lacked a stable source event | Duplicate-delivery risk | Message row ID as `source_event_id` | Driver Agent v59 correlates both directions; a partial unique index suppresses retry duplicates |
| Rider lifecycle delivery | App-global `RiderLiveActivityScope`, Active Ride, Searching, Marketplace Matching, and Taxi Terug tracking independently listened to `ride_requests`; Active Ride and Taxi Terug also added snapshot polling | Exact duplicate listeners and fetch paths | `RiderLiveActivityScope` + `RiderRideLifecycleEngine` | One app-global filtered channel and fallback poll now hydrate a full canonical record consumed by every Rider lifecycle surface; subscribe/reconnect explicitly rehydrates backend truth |
| Driver on-my-way projection | Active Ride polled `fn_ride_ping_timeline` every 12 seconds and reinterpreted audit events in Flutter, alongside lifecycle snapshot refresh from FCM/Realtime/poll | Duplicate read/resolver path | `fn_rider_ride_snapshot` projects `driver_on_my_way` from `ride_audit_log` | Removed the service/timer; FCM-triggered and five-second recovery hydration now update the same engine record |
| Driver profile commands | Nine released `SECURITY DEFINER` RPCs trusted caller-supplied `p_user_id` and exposed their implementation bodies directly | Legacy compatibility security conflict | Auth-bound public wrappers + private retained implementations | Preserved every signature/default; valid authenticated/service calls continue, cross-user calls fail and write `private.domain_security_events` |
| Internal maintenance, billing, lifecycle, notification, radar, fare, and Shift Handover helpers | Production ACL drift made backend-only functions directly callable by `anon` and `authenticated` | Exposed duplicate command paths | Owner-context SQL, cron, or service-role Edge callers only | Caller inventory completed; restored service-only grants without dropping functions; Rider/Driver-facing commands remain authenticated |
| Rider lifecycle cron authentication | The production cron command embedded its webhook credential inline; the first Vault boundary then sent `rider_agent_webhook_secret` while the Edge Function preferred a separately managed `LIFECYCLE_DISPATCH_SECRET`, producing four consecutive production `401` responses | Secret exposure and conflicting secret authorities | `private.fn_invoke_rider_lifecycle_dispatch` + `fn_rider_agent_webhook_secret` + Vault | Cron metadata contains no secret; lifecycle Edge v25 resolves the service-only Vault RPC first, retains environment secrets only as compatibility fallbacks, and exposes an authenticated non-mutating dry-run probe for monitoring |

The complete repository inventory for all other domains remains in progress.
No similarly named implementation will be removed without caller proof.

## 3. Remote Supabase duplicate inventory

Production evidence on 2026-07-14:

- `ride_shares`: 3 historical rows, 0 active unexpired rows, 0 duplicate active
  rides at audit time.
- One trigger on `ride_shares`:
  `trg_ride_shares_sync_to_ride_requests`.
- One deployed public projection: Edge Function `get-shared-ride`, version 30.
- `driver_locations` and `ride_requests` are members of
  `supabase_realtime`; `ride_shares` is intentionally not public Realtime
  authority for anonymous viewers.
- Public viewing is capability-token based through the Edge Function; the
  service-role key is never sent to the browser.
- `ride_requests`, `ride_request_invites`, `ride_bids`, `ride_swaps`,
  `messages`, `notifications`, and `driver_locations` are each present once in
  `supabase_realtime`. `conversations`, `return_mode_events`, and support tables
  are not currently publication members; their consumers and required event
  surface remain under audit.
- Production retained one enabled invite-to-agent trigger,
  `driver_agent_on_ride_request_invites`, and one ride-insert matcher trigger,
  `ride_request_start_matching`. Similar names were not treated as duplicates
  without comparing event and function behavior.
- Before migration `20260714060013`, production exposed the internal
  `fn_seed_ride_matching_batch_dispatch_v3`,
  `fn_seed_ride_matching_batch_legacy`,
  `fn_seed_taxi_terug_matching_batch`, `fn_advance_ride_matching_waves`,
  `fn_seed_due_scheduled_ride_matching`, and
  `fn_accept_invite_diagnostic` through public API roles. They remain installed
  but are now service-only.
- The invite table has exactly three intentional triggers: one `BEFORE INSERT`
  cohort/expiry guard, one `AFTER INSERT` driver-agent webhook, and one audit
  trigger. Their event responsibilities do not overlap. The webhook URL is the
  production project URL and its Vault secret is configured.
- `messages` is present exactly once in `supabase_realtime` and has one enabled
  delivery trigger, `driver_agent_on_messages`. Before the Chat migration all
  24 production messages lacked `conversation_id`; all were safely backfilled
  to the unique conversation for their ride. There were no duplicate
  `(recipient, source_event_id)` Chat notifications before the new unique
  index was created.

## 4. Canonical implementation selected for each domain

Shared ride tracking:

- Owner: Rider Experience.
- State: `ride_shares`, `ride_requests`, `driver_locations`.
- Command: `fn_rider_create_share_token(uuid,text)`.
- Public projection: `get-shared-ride`.
- Rider caller: `ActiveRideScreen._shareRide`.
- Web consumer: `SharedRideTracker`.
- Registry entry: `shared_ride_tracking` in `docs/domains/registry.yaml`.

Other domains are defined in `docs/domains/registry.yaml`; their duplicate and
runtime-proof sections are not yet complete in this audit.

Dispatch:

- Owner: Marketplace Backend.
- State: `ride_requests`, `ride_request_invites`, and `ride_audit_log`.
- Public command boundary: `fn_seed_ride_matching_batch` with the released
  `(uuid,integer)` and `(uuid,integer,integer)` signatures.
- Routing: `booking_mode='terug'` invokes
  `fn_seed_taxi_terug_matching_batch`; other modes invoke
  `fn_seed_ride_matching_batch_dispatch_v3`.
- Authorization: authenticated callers must resolve to the ride's
  `rider_identity_id`; direct SQL/cron and service-role orchestration remain
  supported.
- Rider callers:
  `SearchingScreen._startRealtime` and
  `seedMarketplaceDriverInvites` in `marketplace_offers_provider.dart`.
- Internal callers: `ride_request_start_matching`,
  `fn_advance_ride_matching_waves`, and
  `fn_seed_due_scheduled_ride_matching`.

## 5. Functions, triggers, and Edge Functions retained

- Retained `fn_rider_create_share_token(uuid,text)` as the stable released-app
  signature. `p_rider_token` is accepted for compatibility but never used as an
  authorization credential.
- Retained `sync_ride_request_share_from_ride_shares()` and
  `trg_ride_shares_sync_to_ride_requests` as a read projection for old clients.
- Retained `get-shared-ride` as the sole public backend projection and deployed
  source-controlled version 30 with `verify_jwt=false`; the 24-hex capability
  token is the endpoint credential.
- Retained both released `fn_seed_ride_matching_batch` signatures. The
  three-argument function is the canonical auth-bound router; the older integer
  overload delegates to it.
- Retained dispatch-v3, Taxi Terug, and legacy implementations as service-only
  implementation details so cron/stored dependencies and rollback remain safe.
- Retained `driver-agent` as the single invite notification delivery service
  and deployed version 58. `invite_gate.ts` re-fetches the exact invite/ride or
  Taxi Terug offer state before notification persistence and immediately before
  each provider send.
- Retained the released `fn_rider_boost_marketplace_offer(uuid,numeric)`
  signature. The backend now supports both marketplace and Taxi Terug while
  preserving ownership checks and authenticated compatibility.

## 6. Legacy paths disabled or removed

- Removed the `/track/:path*` rewrite to
  `https://rydtap-web-app.vercel.app/track/:path*` from
  `apps/marketing/next.config.ts`.
- Preserved `/api/:path*` compatibility routing to the legacy web backend.
- Changed legacy `/api/:path*` routing from `beforeFiles` to `fallback`, so the
  local canonical `/api/shared-ride` route wins while unimplemented mobile API
  paths retain their existing backend.
- No RPC signature, grant needed by authenticated released Rider clients, or
  database table was removed.
- Removed `flutter_callkit_incoming`, the Driver CallKit service/scope, and
  Android `USE_FULL_SCREEN_INTENT`/`FOREGROUND_SERVICE_PHONE_CALL` permissions
  from normal taxi offers. Ride requests remain ordinary FCM/APNs alerts.
- Removed direct `anon`/`authenticated` execution from internal dispatch
  implementations, wave/scheduled job commands, and invite diagnostics. No
  function was dropped; authenticated Rider access to the canonical signatures
  is preserved.

## 7. Realtime publication audit

- Shared-link viewers re-fetch the canonical Edge projection every four
  seconds while a ride is non-terminal.
- Browser resume and network reconnect trigger an immediate re-fetch.
- Polls are serialized; overlapping requests are suppressed.
- Only a successfully loaded non-terminal projection schedules another poll;
  invalid/expired links and initial offline failures do not create a background
  polling loop.
- The web viewer never treats Realtime delivery as stored truth.
- `driver_locations` and `ride_requests` remain in `supabase_realtime` for
  authenticated Rider/Driver consumers.
- Production publication membership was enumerated directly from
  `pg_publication_tables`; Postgres prevents duplicate relation membership in a
  single publication, and no duplicate relevant entry was found.
- Driver shell board delivery now uses one `ride_requests` subscription for
  Scheduled, Today, and Taxi Terug invalidation. The callback only invalidates
  Riverpod providers, which re-fetch canonical backend projections; it does not
  treat the Realtime payload as authoritative list state.
- Exact invite delivery remains a separate driver-filtered
  `ride_request_invites` subscription because it owns modal/ringtone behavior,
  not list counts. All channels unsubscribe on rebinding/disposal, and the
  global resync generation recreates them after reconnect/app resume.
- Rider lifecycle delivery now has one app-global filtered `ride_requests`
  channel and one five-second fallback poller. Each update and each
  `subscribed`/reconnect state triggers `fn_rider_ride_snapshot`; the lifecycle
  engine publishes that full canonical projection to Active Ride, Live
  Activity, widgets, route, waiting, fare, and navigation consumers. The
  Active Ride, Searching, Marketplace Matching, and Taxi Terug tracking no
  longer open independent ride channels; Active Ride's 10-second and Taxi
  Terug's 5-second snapshot polls were removed.

This design deliberately avoids granting anonymous Realtime SELECT access to
precise trip or driver-location tables. A future move to private Realtime
Broadcast requires a scoped short-lived viewer credential and load evidence.

## 8. Ride acceptance race audit

The production command uses a row lock, validates the exact live invite and
Driver eligibility, assigns once, closes competitors, audits the outcome, and
returns stable loser errors. `scripts/load_accept_race.py` now calls the
canonical Supabase RPC directly with two or more distinct Driver sessions; it
no longer targets the retired Go endpoint, races one Driver repeatedly, or
service-role-resets a ride. It is production-ref locked and refuses to run
without explicit confirmation that the ride/invites are disposable fixtures.
Full current-production concurrency output must still be attached here before
the overall audit can be marked complete.

Production migrations
`20260714084930:driver_accept_runtime_eligibility` and
`20260714084941:driver_accept_runtime_recheck` close the final static contract
gap. `fn_driver_accept_ride_invite` now rejects a server-expired ride even when
an old invite is inside the diagnostic grace window; requires the winning
invite itself to remain `pending` with `expires_at > now()`; and, inside the
same locked transaction, rechecks canonical readiness, online status,
compliance suspension, an existing queued Taxi Terug reservation, vehicle
class, and pet compatibility. Billing, tariff, GPS freshness, and payment
compatibility retain their dedicated stable error codes. Taxi Terug browse may
renew an expired invite only while the ride remains live, and the renewed
invite is capped by the ride's own expiry.

Scheduled acceptance is deliberately a separate open authenticated marketplace,
not an exact-invite flow. Production migrations
`20260714090052:driver_accept_ride_fit_eligibility` and
`20260714090109:scheduled_accept_authority` now source-control its
`security_invoker` catalog and make `fn_driver_accept_scheduled_ride` use the
same backend readiness/compliance/vehicle/accessibility projection. The
scheduled command locks the ride, requires a future non-expired pickup, keeps
the existing billing/tariff/GPS/payment and overlap checks, writes stable
rejection audits, assigns once, closes any matching invites, and uses the
canonical Rider notification helper. It intentionally does not require the
Driver to be online now or reject an unrelated queued Taxi Terug ride, because
the work is future-dated and schedule overlap remains the time authority.

## 9. Taxi Terug update audit

The canonical dispatch router selects the Taxi Terug matcher from backend
`booking_mode`; Flutter does not choose a matching implementation. Production
migration `20260714063927:taxi_terug_offer_boost_realtime_delivery` extends the
released Rider boost command without changing its signature.

- The RPC binds to `auth.uid()`, verifies ride ownership, locks the ride, and
  rejects assigned, terminal, expired, same-fare, lower-fare, and invalid-fare
  requests.
- Postgres calculates the authoritative previous fare, new fare, and increase;
  updates every fare snapshot column atomically; writes one correlated
  `taxi_terug.offer_increased` audit event; and enqueues one event through the
  shared Vault-backed driver-agent transport helper.
- The Rider app adopts the returned backend fare only after success. Taxi Terug
  no longer calls the generic invite seeder after boosting.
- Driver-agent version 58 re-fetches current ride mode/status/assignment,
  expiry, fare, invite audience, and `fn_terugtaxi_qualify` eligibility. It
  suppresses delayed, superseded, or terminal events before notification
  insertion and again before every provider send.
- Delivery is idempotent per source event and Driver. The dedicated alert shows
  the increase and new total; Android/iOS receive a badge. Foreground, tap, and
  polled-notification paths invalidate the canonical Taxi Terug post providers
  and open `/driver/taxi-thru`.
- The existing broad Driver board Realtime subscription invalidates Taxi Terug
  projections on the fare-row update, so active Driver lists refresh even when
  a device is not in the push audience.

Actual offer-to-device timing on two physical phones remains a release-evidence
gate; no live customer ride was altered to manufacture that measurement.

## 10. Notification pipeline audit

Backend expiry hardening is deployed; physical delivery evidence remains in
progress. Canonical intent and delivery ownership is registered under
`notifications`.

- Before invite creation: production trigger
  `trg_lock_dispatch_invite_cohort` rejects non-pending or expired rides. The
  current dispatch-v3 and Taxi Terug seeders also lock and validate the ride.
- Before notification creation: `buildAgentNotification` rejects expired or
  non-pending invite webhook records; `incomingRideGate` then re-fetches the
  exact invite and ride before inserting `notifications`.
- Immediately before transport: `incomingRideGate` runs again for each device.
- Provider expiry: Android FCM receives TTL; FCM/APNs and direct APNs receive
  `apns-expiration`, using the earlier current invite/ride deadline.
- Exact routing: payloads include `ride_invite_id`, `ride_request_id`, and
  backend expiry. APNs uses invite collapse ID and ride thread ID.
- Invalid transport rows: an APNs-only row is no longer skipped; a permanently
  invalid direct APNs token may fall back once to its valid FCM registration.
- Privacy: full provider response bodies are neither logged nor persisted;
  stable provider error codes remain available for monitoring.
- Delayed/terminal events are suppressed with structured ride, invite, and
  driver correlation fields.

Shared tracking does not send a notification by itself; the Rider explicitly
shares the capability URL through the OS share sheet.

## 11. Lock-screen alert audit

Backend/provider/client routing is hardened. Foreground delivery and
notification taps now both call `DriverIncomingRideCoordinator`, which
re-fetches invite status, expiry, recipient, and ride status before rendering.
An expired tap resolves to the existing "This ride is no longer available"
flow. Normal taxi offers no longer invoke the CallKit presentation path.
The CallKit package, service, scope, and phone-call/full-screen Android
permissions have been removed, so background normal offers cannot silently
re-enter that path.

Physical Rider/Driver device evidence in foreground, background, another app,
and lock screen remains mandatory and cannot be replaced by simulator or static
analysis.

## 12. Chat and ping audit

The production Chat write boundary is now `fn_send_ride_message`. It accepts
only authenticated ride participants, derives sender type and ID in Postgres,
checks the canonical ride lifecycle and block state, binds the unique
conversation, validates text/ping content, and inserts once for a
sender-scoped idempotency key. Reusing a key with different content returns
`idempotency_conflict`; successful retries return the original message row and
do not emit a second audit event.

Current Rider chat, Driver chat, and the Active Ride Rider ping surface all use
the shared `HeyCabyRideChatMessages` client. Optimistic rows are reconciled
with the returned canonical row. A failed or uncertain send restores the text
and preserves its retry key. Both chat screens sort by `(created_at,id)`,
deduplicate by message ID, and re-fetch the full authorized list whenever the
Realtime channel reaches `subscribed`, covering initial connect and reconnect.
Realtime remains delivery only, never state authority.

Rider unread counts are derived from the same canonical `chatProvider`
message projection. The former second Rider `messages` subscription and
separate unread snapshot query were removed; read acknowledgement remains a
backend write and updates the canonical in-memory projection after success.

`driver_agent_on_messages` remains the single push trigger. Driver Agent v59
copies the message row ID into both `message_id` and `source_event_id` for
Rider-to-Driver and Driver-to-Rider notifications. The database unique index
on recipient plus source event turns webhook retries into a safe
`duplicate_source_event` outcome.

The legacy moderation RPC signatures and effective grants remain frozen for
released clients, but all three now derive the actor from `auth.uid()` and the
ride. Caller-supplied identity forgery and anonymous calls fail closed. Message
RLS permits only participant reads, block-aware compatibility inserts, and
recipient acknowledgement; full content/sender mutation is not granted.

Automated and synthetic production evidence is complete. Real two-device
foreground/background, offline restart, Driver swap, cancellation/post-ride,
and lock-screen deep-link behavior still require physical-device execution.

Driver-to-Rider operational pings remain authoritative audit events. Migration
`20260714073821:rider_snapshot_ping_projection` adds the latest on-my-way audit
timestamp and boolean to `fn_rider_ride_snapshot`; it does not create a second
ping table or Flutter rule. Foreground FCM immediately refreshes that snapshot,
and the single five-second lifecycle poll recovers a missed push. The former
12-second `fn_ride_ping_timeline` Active Ride poller and service were removed.

Payment/Live Activity status normalization is complete. Rider Agent version 11
recognizes the canonical database `payment_status='confirmed'` and legacy
`paid` directly, rather than relying on the notification category to repair the
state. Its webhook/manual delivery boundary now fails closed when the secret is
missing and rejects missing/wrong secrets. Provider acceptance, rejection, and
permanently invalid tokens are counted separately; `push_sent_at` is written
only after FCM accepts at least one delivery, and provider bodies are not logged
or persisted.

### Admin contract audit

The repository-owned Admin/Fleet surface uses canonical RPCs rather than direct
protected-state writes. Production migration
`20260714065613:admin_shift_handover_audit_hardening` adds correlated denied and
before/after events to the only uncovered mutation,
`fn_admin_shift_handover_allowlist_set`. The Driver Readiness Admin mutation
already used server-owned role metadata and wrote denied/changed audit events.
The production contract test passes.

The standalone Admin application is not present in this monorepo, so ride,
refund, Platform Balance, restriction, report, support, and Taxi Terug Admin
consumer behavior remains unverified. The three legacy Shift Handover RPCs keep
their anonymous grants under the explicit compatibility freeze; their internal
authorization denies anonymous operations. See
`docs/domains/ADMIN_CONTRACT_AUDIT.md`.

## 13. Performance measurements

Shared tracking launch target:

- Viewer refresh cadence: 4 seconds while non-terminal.
- Edge timeout in the Vercel proxy: 8 seconds.
- Driver location is labeled stale by the backend after 90 seconds.
- Payloads use `Cache-Control: no-store`; no precise location is cached.

Actual moving-trip p50/p95 measurements remain pending because there was no
active production share at verification time.

Chat uses `messages_ride_created_id_idx (ride_request_id,created_at,id)` for
ordered recovery and `messages_sender_idempotency_uidx` for retry lookup. With
only 24 rows, production correctly chose a sequential scan; the index is
available as volume grows. Post-migration advisors report no `auth_rls_initplan`
finding for any of the three `messages` policies.

Rider lifecycle polling was reduced from simultaneous 5- and 10-second
snapshot loops to one five-second app-global recovery loop. Realtime updates
and reconnects still trigger immediate full snapshot hydration; payload rows
are never treated as complete authority.

## 14. Security findings

Fixed:

- Bearer `rider_token` is no longer accepted as share-token creation authority.
- `anon` cannot execute `fn_rider_create_share_token`; `authenticated` can.
- A partial unique index enforces one active share per ride.
- The RPC locks the ride before token reuse/creation and deactivates expired
  active rows so an expired link cannot poison later shares.
- The Edge Function rejects malformed tokens before database lookup.
- Terminal rides do not expose live driver coordinates.
- New viewer/proxy requests carry the share capability in a POST JSON body, so
  Vercel and Supabase request URLs no longer record it. GET remains accepted
  temporarily for an already-loaded pre-rollout browser bundle.
- Public and proxy responses are non-cacheable and use `no-referrer`/
  `nosniff` headers.
- Tracking pages are `noindex, nofollow, noarchive`.
- Cross-rider dispatch seeding is rejected with stable error `forbidden`.
- Client-controlled dispatch fan-out and invite-window parameters are bounded
  server-side while preserving released parameter shapes.
- Six internal/scheduled dispatch `SECURITY DEFINER` functions are no longer
  directly executable by `anon` or `authenticated`; service-role and direct
  database job execution remain available.
- Incoming-ride delivery no longer trusts a delayed webhook payload at send
  time, and provider response bodies are no longer written to Edge logs or
  `agent_logs`.
- Chat sends bind actor, ride, conversation, lifecycle, and block state in one
  backend command. Retry keys cannot duplicate rows or audit events.
- Released Chat moderation functions no longer trust caller-supplied actor
  identity; anonymous probes return `unauthorized` without mutation.
- Chat push intent retries are unique by recipient and message source event.
- Eleven billing/maintenance/lifecycle functions are service-only again, and
  Driver power-card commands bind `p_driver_id` to the authenticated Driver.
- Nine released Driver profile RPC signatures now delegate to retained private
  implementations only after one canonical actor check; eighteen adjacent
  implementation helpers are service-only.
- Ten lifecycle/notification client commands retain authenticated access while
  nine owner-context/cron/Edge helpers no longer expose a direct client path.

Post-hardening production advisor baseline on 2026-07-14 is 480 security
notices, down from 576 before the caller-safe grant/actor migrations and up by
one intentional authenticated canonical booking command from the 479
pre-booking baseline. The remaining 218 authenticated and 144 anonymous
`SECURITY DEFINER` notices
still require signature-by-signature caller review; they are not blanket
revocation candidates. The remaining non-function inventory is 101 anonymous
access-policy notices, 8 permissive write policies, 7 intentionally policyless
service tables, and the 2 PostGIS/platform-owned notices.

Advisor items unrelated to this change remain classified separately. In
particular, `spatial_ref_sys`/PostGIS is a platform-extension ownership issue,
not a shared-tracking migration target.

## 15. Changes applied

- Production migration:
  `20260714054208:shared_ride_tracking_reliability`.
- Production RLS optimization migration:
  `20260714055038:shared_ride_tracking_rls_initplan`.
- Production dispatch authority migration:
  `20260714060013:canonical_dispatch_seed_boundary`.
- Production accept-fare authority migration:
  `20260714070835:accept_fare_snapshot_authority`.
- Production Chat authority migrations:
  `20260714072357:ride_chat_command_and_actor_binding` and
  `20260714072951:ride_chat_rls_initplan`.
- Production Rider ping projection migration:
  `20260714073821:rider_snapshot_ping_projection`.
- Production internal RPC and power-card hardening migration:
  `20260714074731:internal_rpc_grant_and_power_card_hardening`.
- Production Driver profile actor/private-implementation migration:
  `20260714075308:driver_profile_actor_and_internal_helper_boundary`.
- Production lifecycle/notification command-boundary migration:
  `20260714075642:lifecycle_notification_internal_grant_boundary`.
- Production Rider lifecycle cron Vault-boundary migration:
  `20260714081532:rider_lifecycle_cron_vault_boundary`.
- Production Rider booking command migration:
  `20260714082656:rider_create_ride_command_authority`.
- Production Driver acceptance eligibility migrations:
  `20260714084930:driver_accept_runtime_eligibility` and
  `20260714084941:driver_accept_runtime_recheck`.
- Production shared ride-fit and scheduled acceptance migrations:
  `20260714090052:driver_accept_ride_fit_eligibility` and
  `20260714090109:scheduled_accept_authority`.
- Local corrective migration:
  `supabase/migrations/20260714053712_shared_ride_tracking_reliability.sql`.
- Local RLS optimization migration:
  `supabase/migrations/20260714054950_shared_ride_tracking_rls_initplan.sql`.
- Local dispatch authority migration:
  `supabase/migrations/20260714055826_canonical_dispatch_seed_boundary.sql`.
- Production Edge Function: `get-shared-ride` version 30.
- Production Edge Function: `driver-agent` version 59
  (`b81166586ece6970f9e48494d921d5ebea51635c0b46789d37e71fa3db9378c2`).
- Production Vercel deployment:
  `dpl_24bRMEBid6myPaSshDUszah7MLcN`.
- Live aliases:
  `https://heycaby.nl` and `https://www.heycaby.nl`.
- Rider source now routes Active Ride lifecycle presentation through
  `RiderRideLifecycleEngine` and `riderRideBackendRecordProvider`; no backend
  or production schema change was required for this client consolidation.

## 16. Tests and evidence

Passed:

- Rollback-only production SQL validation returned
  `shared_ride_tracking_passed`.
- Post-deploy SQL verification confirmed migration history, the partial unique
  index, `anon_execute=false`, and `authenticated_execute=true`.
- Production Edge invalid-format token: HTTP 404, JSON `not_found`, no-store.
- Production Edge unknown valid-format token: HTTP 404, JSON `not_found`,
  no-store.
- Production `https://www.heycaby.nl/track/<token>` rendered successfully
  through Vercel (HTTP 200) and an unknown valid-format token resolved to the
  localized expired/unavailable state with privacy copy and no browser console
  errors. Both GET compatibility and current POST proxy paths returned a
  privacy-safe 404, `Cache-Control: no-store`, `Referrer-Policy: no-referrer`,
  `X-Content-Type-Options: nosniff`, and a correlation ID. The production
  catalog had zero active unexpired share tokens, so no customer trip was used
  for testing.
- After the acceptance migrations, the production share contract was
  re-smoked: all 3 Node contract tests passed; `/track/<unknown-token>` returned
  HTTP 200 in 1.276 s; the POST proxy returned privacy-safe HTTP 404 in 2.706 s
  with no-store/no-referrer/nosniff headers and correlation ID
  `dd8b1c33-dd33-47a5-9043-3056c24e24ec`. Production still had zero active
  trackable or otherwise unexpired shares, so moving-location proof remains a
  physical-fixture requirement rather than a synthetic customer-data test.
- `npm run build`: Next.js production build and TypeScript passed.
- Vercel production build: passed; `/track/[token]` and `/api/shared-ride`
  emitted as dynamic routes.
- Browser smoke on `https://www.heycaby.nl/track/<unknown-token>` rendered a
  terminal unavailable message instead of an infinite spinner, with no console
  warnings/errors.
- Mobile viewport 390x844: `scrollWidth == clientWidth == 390`.
- Post-cutover `/api/manifest/rider` and `/support` returned HTTP 200.
- Vercel production runtime-error scan for `/api/shared-ride` over the first
  24-hour deployment window returned no error clusters.
- Supabase Edge version-30 logs show `POST /functions/v1/get-shared-ride`
  without a token query parameter, confirming capability-safe transport to the
  production function. The final Vercel smoke correlation ID
  `0bcd6165-a488-4fbd-b2f0-784afe7c5b5d` reached the canonical POST route and
  returned JSON 404 for the unknown test token.
- Rollback-only production dispatch validation returned
  `canonical_dispatch_seed_boundary_passed` before deployment.
- Post-deploy production SQL test
  `supabase/tests/canonical_dispatch_seed_boundary_test.sql` passed.
- Production grant verification confirmed only the two canonical released
  signatures remain executable by `authenticated`; all six internal helpers
  are service-only and `anon` can execute none of them.
- Transactional production authorization probes proved an owning Rider is
  admitted and a different authenticated Rider receives `forbidden`; both
  probes rolled back.
- Post-migration security advisor output removed the anonymous/authenticated
  findings for all internal dispatch helpers. The remaining warning is the
  intentional authenticated canonical wrapper, whose ownership checks were
  exercised above.
- `npm test` in `apps/marketing` passed three shared-ride architecture guards:
  POST-body capability transport, active-only location/polling, and local API
  precedence before the legacy fallback.
- Final `npm run build` and `vercel build --prod` passed before deployment
  `dpl_24bRMEBid6myPaSshDUszah7MLcN`.
- Final live POST `/api/shared-ride` returned JSON 404 with a correlation ID;
  `/api/manifest/rider` still returned HTTP 200 through compatibility fallback.
- Final Vercel runtime-error scan for `/api/shared-ride` returned no clusters.
- `flutter test test/driver_realtime_board_authority_test.dart --no-pub` passed,
  proving one shell-mounted `ride_requests` board subscription and retained
  reconnect/invite paths.
- Targeted Driver analysis for the consolidated listener and shell passed with
  no issues.
- Previously red Driver visual gates now pass:
  `rate_control_light`, `platform_balance_light`, and the compact-phone/larger-
  text overflow regression for both surfaces.
- Final current-worktree rerun passed all 72 Rider tests and all 166 Driver
  tests (including visual goldens), Rider/Driver Flutter analysis with no
  issues, monorepo boundary checks, domain-authority checks, `git diff
  --check`, and all three shared-ride web contracts. Production shared-route
  smoke returned HTTP 200 for the viewer page and privacy-safe JSON 404 from
  both the Vercel proxy and Edge Function for a guaranteed-invalid token. The
  viewer and API responses remain `no-store`; the API also returns
  `Referrer-Policy: no-referrer` and `X-Content-Type-Options: nosniff`.
- `deno check` passed for the complete `driver-agent` entrypoint and the invite
  expiry contract suite.
- `deno test --allow-read
  supabase/functions/driver-agent/invite_expiry_test.ts` passed nine tests:
  expired/non-pending intent suppression, exact IDs/server expiry, terminal
  delivery gating, earliest authoritative deadline, live Taxi Terug delivery,
  terminal/assigned/superseded Taxi Terug suppression, provider TTL/expiry,
  and bidirectional Chat message/source-event correlation.
- `flutter test test/driver_fcm_payload_test.dart --no-pub` passed seven tests,
  including the shared foreground/tap backend-validation path and absence of a
  direct `showIncomingRide` CallKit call, plus Taxi Terug provider invalidation
  and canonical deep-link routing.
- `flutter test test/taxi_terug_offer_boost_authority_test.dart --no-pub`
  passed, proving Flutter adopts returned backend truth and does not re-seed
  Taxi Terug through the generic dispatch path.
- The proposed Taxi Terug migration and
  `supabase/tests/taxi_terug_offer_boost_test.sql` passed in an isolated
  PostgreSQL 16 database: grants, locking, atomic snapshots, audit correlation,
  idempotency, positive boost, same/lower-fare rejection, and terminal-state
  rejection.
- Production migration `20260714063927` applied successfully. Post-deploy SQL
  verified anonymous denial, authenticated compatibility, private-helper
  denial, the idempotency index, canonical trigger transport, and terminal
  `ride_not_boostable` behavior without changing a customer ride.
- Production `driver-agent` version 58 is active, SHA-256
  `1be2d2867f22c869efa88d206140425851bf4677b30ac4c28d9e38d31bb9fd01`.
  Unauthenticated smoke returned HTTP 401 with request ID
  `019f5f5a-e788-767a-bb8f-fca4e4e4f603`; Vault-authenticated request `38251`
  returned HTTP 200 and safely suppressed a nonexistent ride as
  `taxi_terug_offer_not_live`.
- `deno check` passed for Rider Agent, and its eight pure tests passed: canonical
  confirmed completion, legacy paid compatibility, unpaid payment-pending, and
  missing/wrong/exact webhook-secret behavior, stable FCM rejection codes, and
  provider-acceptance-gated `push_sent_at`.
- Production Rider Agent version 11 is active, SHA-256
  `48440fa8860bbc4cf33cc47b17cf7bdff6d5c6965c57adab327b9a4907cbabfd`.
  Unauthenticated manual-delivery smoke returned HTTP 401 with request ID
  `019f5f63-5348-767f-9d58-196e3ed11b5f`; Vault-authenticated request `38272`
  passed authentication and returned the expected 404 for the nonexistent
  synthetic notification without modifying customer state.
- The final Admin Shift Handover migration passed isolated authorized,
  idempotent, removal, denied, and correlation tests. Production migration
  `20260714065613` is applied; `admin_domain_contract_test.sql` passed, and a
  rollback-only denial smoke observed its correlated audit event without
  touching Fleet or Driver state.
- `supabase/migrations/20260714070835_accept_fare_snapshot_authority.sql` and
  `supabase/tests/accept_fare_snapshot_authority_test.sql` passed in an isolated
  PostgreSQL 16 database. The test proves private grants, trigger enablement,
  existing-quote precedence, active-profile ordering, exact tariff formula,
  and success/missing-input monitoring.
- Production migration `20260714070835` is applied. The read-only production
  smoke returned `trigger_enabled=true`, `client_execute_revoked=true`,
  `existing_quote_preserved=true`, `active_tariff_formula_matches=true`, and
  `trigger_logs_success_and_missing=true`; post-deploy advisors reported no
  finding for the new private functions or trigger.
- `flutter test test/driver_accept_authority_test.dart --no-pub` and targeted
  Driver analysis passed, proving the incoming-offer screen calls only
  `fn_driver_accept_ride_invite` and no longer performs a fare-table update.
- `supabase/tests/driver_accept_runtime_eligibility_harness.sql` passed in an
  isolated PostgreSQL 16 database. It proves eligible, offline, not-ready,
  suspended, already-queued, wrong-vehicle, and pet-incompatible outcomes plus
  client denial for the internal helper.
- `supabase/tests/driver_accept_runtime_recheck_compile.sql` compiled the full
  acceptance migration in isolated PostgreSQL 16 and verified the row lock,
  server-expiry rejection, runtime helper, competitor closure, and grants.
- Production read-only smoke verified both migrations, `locks_ride=true`,
  `rejects_expired_ride=true`, `rechecks_runtime=true`,
  `requires_pending_invite=true`, `requires_live_invite=true`,
  `closes_competitors=true`, `notifies_rider=true`, and `audits=true`.
  Anonymous acceptance and both client-role helper grants are denied; the
  authenticated accept command remains callable. No current pending expired
  ride/invite or historical non-scheduled acceptance after ride expiry was
  found. Security advisors remain 480 (the authenticated accept command is an
  intentional actor-bound definer RPC); performance advisors remain 350.
- The expanded eligibility harness also proves that an offline Driver is
  allowed to reserve future scheduled work while live acceptance remains
  online-only, and that legacy electric, wheelchair, and pet filters are
  enforced by backend truth. `scheduled_accept_authority_compile.sql` passed
  the locked/future/expiry/ride-fit/overlap/notify/audit/grant and
  `security_invoker` view checks in isolated PostgreSQL 16.
- Production scheduled-accept smoke returned `locks_ride=true`,
  `requires_future_pickup=true`, `checks_expiry=true`,
  `rechecks_ride_fit=true`, `checks_overlap=true`,
  `canonical_rider_notify=true`, `audits_rejections=true`, and
  `view_security_invoker=true`. The unauthenticated command failed closed as
  `not_a_driver`; anonymous command and both client-role helper grants are
  denied. Production had zero pending or accepted scheduled rides during the
  rollout, so no customer state was touched. Advisor totals remain security
  480 and performance 350; the authenticated scheduled command notice is an
  intentional actor-bound command boundary.
- `python3 -B scripts/load_accept_race.py --help` passes, and the corrected
  competing-Driver harness fails closed without `--fixture-confirmed`. A live
  run remains pending because no approved disposable production ride with two
  eligible Driver invites was available.
- Production unauthenticated `driver-agent` smoke returned HTTP 401 with Edge
  request ID `019f5f4a-85b8-725b-adba-9f3ee93d4180`.
- Production Vault-authenticated webhook smoke request `38249` returned HTTP
  200, `skipped=true`, `reason=invite_missing`, without inserting a fabricated
  notification. Edge logs identify active deployment version 57 and a 2012 ms
  execution.
- `supabase/tests/ride_chat_command_and_actor_binding_harness.sql` passed in an
  isolated PostgreSQL 16 database after both Chat migrations. It proves
  authenticated-only send authority, private resolver grants, participant
  identity binding, unique conversation association, exactly-once retry and
  audit behavior, idempotency conflict rejection, outsider rejection, block
  enforcement, anonymous moderation denial, one Realtime publication, one
  delivery trigger, and statement-cached RLS identity.
- `flutter test test/ride_chat_authority_test.dart --no-pub` passed in both
  Rider and Driver, and
  `packages/heycaby_api/test/ride_chat_messages_test.dart` passed 100 unique
  URL-safe 128-bit retry-key checks. Targeted Flutter analysis passed with no
  errors or warnings after the package import correction.
- Production migrations `20260714072357` and `20260714072951` are applied.
  Read-only smoke verified `missing_conversation_count=0`, exactly one enabled
  Chat trigger/publication, authenticated-only send execution, private actor
  resolver denial, block-aware RLS, unique idempotency and notification
  indexes, and zero correlated notification duplicates. Anonymous send/report
  probes returned `unauthorized` without mutation. The performance advisor has
  no remaining `auth_rls_initplan` finding for `messages`.
- Production Driver Agent version 59 is active, SHA-256
  `b81166586ece6970f9e48494d921d5ebea51635c0b46789d37e71fa3db9378c2`.
  A forged webhook returned HTTP 401. Vault-authenticated synthetic request
  `38281` returned HTTP 200 with `category=chat`, `skipped=true`, and
  `reason=missing_driver`; no customer or notification row was created.
- `flutter test test/rider_lifecycle_listener_authority_test.dart
  test/rider_ride_state_version_test.dart
  test/live_ride_activity_payload_test.dart --no-pub` passed 20 tests. Targeted
  analysis passed with no issues. The authority test proves one lifecycle
  channel/poller owner, canonical snapshot fetch, engine record publication,
  and reconnect hydration; version and Live Activity tests prove stale and
  duplicate backend versions remain suppressed.
- `supabase/tests/rider_snapshot_ping_projection_harness.sql` passed in
  disposable PostgreSQL 16, proving latest-event selection, no-ping behavior,
  private-base reuse, unchanged released grants, and private-helper denial.
  Production read-only smoke found both historical fixtures and returned exact
  expected true/timestamp and false/null projections. Migration
  `20260714073821` is applied; no customer row was modified.
- The Rider lifecycle/journey suite passed 24 tests after removing
  `RiderRidePingService` and its 12-second timer. Targeted analysis found no
  issue, and the authority test proves the engine publication revision includes
  `driver_on_my_way_at`, so a ping can update UI even when the ride row's own
  `updated_at` is unchanged.
- `supabase/tests/internal_rpc_grant_and_power_card_hardening_harness.sql`
  passed in disposable PostgreSQL 16. Production smoke verified all 11
  internal RPCs deny both client roles and retain service access; both
  power-card commands are anonymous-denied and actor-bound.
- `supabase/tests/driver_profile_actor_and_internal_helper_boundary_harness.sql`
  passed signature, grant, valid-call, cross-user denial, and audit behavior.
  Production smoke verified 9 public wrappers, 9 private retained
  implementations, and 18 service-only helpers.
- `supabase/tests/lifecycle_notification_internal_grant_boundary_harness.sql`
  passed. Production smoke verified 10 authenticated client commands and 9
  service-only helpers. Security advisor notices fell 576 → 552 → 507 → 479
  across these three migrations.
- `supabase/tests/rider_lifecycle_cron_vault_boundary_harness.sql` passed in
  disposable PostgreSQL 16, including forward and rollback checks. Production
  read-only verification proves the cron schedule is unchanged, its command
  calls only the private boundary, no webhook URL or credential remains in the
  job metadata, both client roles are denied, and `service_role` retains
  execution.
- Production Edge logs exposed four consecutive lifecycle-cron `401`
  responses at 08:20, 08:40, 09:00, and 09:20 UTC after the first Vault
  cutover.
  `supabase/functions/rider-lifecycle-dispatch/auth.ts` now makes the
  service-role-only `fn_rider_agent_webhook_secret` result authoritative and
  keeps `RIDER_AGENT_WEBHOOK_SECRET` / `LIFECYCLE_DISPATCH_SECRET` only as
  compatibility fallbacks. The function was deployed directly to production
  as version 25. Four Deno secret-resolution tests pass, the full function
  type-check passes after correcting its Supabase client type, and production
  pg_net dry-run request `38289` returned HTTP 200 with
  `{"success":true,"mode":"dry_run"}` without claiming a job or sending a
  notification. Request `38288` returned 401 before the Vault-authority fix,
  proving the smoke detects the original drift.
- `supabase/tests/rider_create_ride_command_authority_harness.sql` passed in
  isolated PostgreSQL 16. It proves valid canonical projection, identical
  retry deduplication, changed-payload conflict, cross-user session denial,
  grants, and transactional rollback. Production read-only smoke verified the
  exact migration, two additive columns, partial unique index, authenticated
  and service execution, anonymous denial, and an unauthenticated
  `unauthorized` response without mutation. Rider authority tests prove no
  direct `ride_requests` insert remains in the current app.

Pending:

- Create a real active Rider trip, share the link to a second physical phone,
  move the Driver device, and verify map position/status updates through
  completion and cancellation.
- Measure refresh and location-age timings with production correlation IDs.
- Confirm the next naturally scheduled lifecycle cron invocation remains HTTP
  200; the immediate authenticated dry-run already proves current secret
  alignment without customer notification side effects.

## 17. Remaining compatibility risks

- Released Rider apps continue to build `https://heycaby.nl/track/<token>`;
  this path is preserved and now source-controlled.
- The RPC parameter list is unchanged.
- The public website still proxies `/api/*` to the legacy web backend.
- Product decisions in `docs/domains/COMPATIBILITY_DECISION_LOG.md` remain
  pending and block unrelated legacy RPC/grant removal.
- The legacy dispatch body remains installed behind backend configuration as a
  rollback/compatibility implementation, but is not a direct client command.
- Released app versions may still insert `messages` directly. That path is
  retained behind participant/status/block RLS until minimum Rider and Driver
  versions are approved; current source uses only `fn_send_ride_message`.
- Released Chat moderation signatures and anonymous grants remain temporarily
  installed under the same decision freeze. Their bodies are now auth-bound
  and anonymous calls fail closed; revoke only after caller/version evidence.
- `fn_rider_ride_snapshot(uuid,text)` retains its released anonymous grant
  because currently deployed Rider compatibility uses token authorization in
  the private base. The advisor warning is accepted compatibility risk until
  minimum Rider version/anonymous receipt decisions are approved; the wrapper
  does not bypass the private base authorization.

## 18. Staging verdict

Not applicable. HeyCaby no longer uses staging; no staging project was queried,
migrated, or deployed.

## 19. Production verdict

Shared tracking infrastructure and invalid/expired behavior: **GO**.  
Shared tracking real moving-trip behavior: **CONDITIONAL — physical smoke test
pending**.  
Full duplicate/realtime stabilization program: **NO-GO — remaining sections
are not yet fully evidenced**.

Incoming-ride backend expiry and routing contract: **GO**. Physical lock-screen
delivery and audible custom-sound behavior: **CONDITIONAL — two-phone device
smoke pending**.

Taxi Terug boost authority and suppression contract: **GO**. Physical
offer-to-notification timing: **CONDITIONAL — two-phone device smoke pending**.

Chat command, retry, conversation, reconnect, and push-correlation contracts:
**GO**. Physical background/lock-screen and offline two-device delivery:
**CONDITIONAL — device smoke pending**.

Rider lifecycle listener and on-my-way projection contracts: **GO**. Physical
foreground ping-to-UI timing: **CONDITIONAL — two-device measurement pending**.

### Final acceptance matrix

| CTO acceptance item | Current evidence | Verdict |
|---|---|---|
| Rider creates a ride once | `fn_rider_create_ride` SQL harness proves identical retry deduplication and changed-payload conflict; current Rider has no direct insert | **GO — automated** |
| Eligible Drivers see it immediately | Canonical dispatch router and one Driver board invalidation channel are deployed | **CONDITIONAL — physical timing pending** |
| Locked Driver receives audible native alert | Expiry/TTL/payload/client routing contracts pass and CallKit misuse is removed | **CONDITIONAL — locked-device test pending** |
| First valid Driver acceptance wins atomically | Exact invite acceptance locks the ride and now rechecks server expiry, a strictly live invite, billing, tariff, GPS, payment and mutable runtime eligibility; competing-Driver race harness exists | **CONDITIONAL — current-production concurrent evidence pending** |
| Losing Drivers cannot accept | Competing invites close in the atomic command and stable race errors are defined | **CONDITIONAL — current-production concurrent evidence pending** |
| Rider sees Driver Found immediately | One lifecycle engine hydrates Realtime/push/poll delivery into all Rider surfaces | **CONDITIONAL — two-device timing pending** |
| Expired rides never produce usable late alerts | Intent, notification, provider-send and client-open gates revalidate expiry; the production accept RPC now also rejects expired rides and non-live invites without grace acceptance | **GO — automated/synthetic** |
| Taxi Terug increase appears once with correct difference | Locked backend boost, correlated idempotent delivery and Driver invalidation tests pass | **CONDITIONAL — two-device timing pending** |
| Rider/Driver chat and pings work both ways | Actor-bound idempotent Chat, ordered reconnect, push correlation and ping snapshot tests pass | **CONDITIONAL — two-device background/offline test pending** |
| Counts match actual lists | Driver boards share one canonical invalidation owner and re-fetch backend lists | **CONDITIONAL — live list/count measurement pending** |
| Reconnect restores current state without duplicates | Rider lifecycle and Chat rehydrate on `subscribed`; Driver global resync recreates scoped channels | **GO — automated** |
| No unintended duplicate trigger, notification, or lifecycle path remains | Production trigger/publication inventory and repository authority tests cover changed domains | **CONDITIONAL — full external Admin/device evidence pending** |
| No P0/P1 synchronization defect remains | Live and scheduled acceptance now share backend ride-fit truth; no known code/DB P0/P1 remains in audited paths, but physical and concurrent gates are still missing | **NO-GO until pending evidence is attached** |

Rollback for the web cutover:

```text
vercel alias set rydtap-web-dz7k5fi20-qbs-projects-2b124455.vercel.app heycaby.nl
vercel alias set rydtap-web-dz7k5fi20-qbs-projects-2b124455.vercel.app www.heycaby.nl
```

Database rollback is forward-only: add a corrective migration restoring the
previous function definition and dropping
`ride_shares_one_active_per_ride_idx`; never edit an applied migration.
For dispatch rollback, add a corrective migration restoring the previous
three-argument function body and grants from the pre-change production
definition. Do not drop the retained dispatch-v3 or legacy helpers.
For invite-delivery rollback, redeploy `driver-agent` version 56 from Supabase
function history with `verify_jwt=false`; then repeat the unauthenticated and
Vault-authenticated webhook smokes. Rollback removes the expiry hardening and
is justified only for a confirmed delivery regression.

## 20. Apple submission verdict

**NO-GO for the complete platform audit.** Shared tracking is materially safer
and the public route is functional, but physical lock-screen invite, active
moving-trip share, chat/ping, Taxi Terug live update, reconnect, and concurrent
acceptance evidence are still required.
