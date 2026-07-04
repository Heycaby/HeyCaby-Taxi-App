# Rider Booking Flow Audit

Date: 2026-06-30

Scope: code and read-only Supabase inspection only. No production behavior was changed.

## 1. Executive Summary

The Rider booking flow is already Supabase-first. Normal, airport, marketplace, and scheduled rides all converge on `public.ride_requests`; the rider app creates the row from `RideRequestNotifier.createRide`, and database triggers/RPCs seed driver invites.

The core live matching path is:

1. Rider selects pickup/destination and ride options.
2. Rider reaches `TripSummaryScreen`.
3. Confirm navigates to a matching route.
4. `SearchingScreen` creates or restores a `ride_requests` row.
5. Supabase trigger `ride_request_start_matching` calls `trg_ride_request_after_insert_matching`.
6. Matching RPC `fn_seed_ride_matching_batch` inserts `ride_request_invites`.
7. Online drivers receive invite rows by Realtime and open `NewRideRequestScreen`.
8. Driver accepts through `fn_driver_accept_ride_invite`; `ride_requests.status` becomes `accepted`.
9. Rider Realtime listener sends the rider to `/active`.

The biggest audit findings:

- The booking backend is centered on `ride_requests`, not separate systems per ride type.
- Normal and airport rides are the same backend flow; airport only pre-fills destination metadata.
- Scheduled rides are created immediately and also get invite seeding immediately from the same insert trigger. I did not find evidence that driver search waits until near pickup time.
- Driver invite flow is Realtime-first in the foreground and FCM-capable through `driver-agent`.
- Rider foreground notifications exist, but rider cold-start/background tap handling is not clearly wired like the driver app.
- Remote Supabase Realtime publication includes `ride_requests` and `ride_request_invites`, but not `ride_bids`; marketplace bid UI subscribes to `ride_bids`, so realtime bid updates may not work until publication is verified/fixed.
- A remote `ride_requests` trigger still points to an external HTTP endpoint with an embedded bearer token in trigger definition. I did not print the secret here, but this should be reviewed as a security/deployment risk.
- Background/lock-screen behavior could not be physically tested in this environment. Findings below distinguish code evidence from unverified device behavior.

## 2. Current Booking Architecture

Flutter entry points:

- Home: `apps/rider/lib/screens/home_screen.dart`
- Address search: `apps/rider/lib/screens/search_screen.dart`
- Airport picker: `apps/rider/lib/screens/airport_booking_screen.dart`
- Marketplace offer setup: `apps/rider/lib/screens/marketplace_screen.dart`
- Vehicle choice: `apps/rider/lib/screens/vehicle_category_screen.dart`
- Payment choice: `apps/rider/lib/screens/payment_screen.dart`
- Summary: `apps/rider/lib/screens/trip_summary_screen.dart`
- Matching/waiting: `apps/rider/lib/screens/searching_screen.dart`
- Marketplace matching: `apps/rider/lib/screens/marketplace_matching_screen.dart`
- Active ride: `apps/rider/lib/screens/active_ride_screen.dart`

Core rider state:

- `bookingProvider`: in-memory booking draft, mode, pickup, destination, vehicle categories, payment methods, scheduled time, marketplace offer.
- `rideRequestProvider`: creates/restores active `ride_requests`, holds `rideRequestId`, status, created time, booking mode.
- `activeSearchProvider`: local persisted “notify me” background-search card.
- `nearTermRideRequestProvider`: queries open pending/bidding ride requests for home/rides banners.

Supabase objects confirmed by MCP:

- Tables: `ride_requests`, `rides`, `drivers`, `driver_locations`, `push_devices`, `rider_identities`.
- Realtime publication: `ride_requests`, `ride_request_invites`.
- Functions include: `fn_seed_ride_matching_batch`, `fn_driver_accept_ride_invite`, `fn_driver_decline_ride_invite`, `fn_expire_ride_requests`, `fn_rider_nearby_supply`, `fn_claim_due_rider_lifecycle_jobs`.
- Edge functions include `driver-agent`, `rider-lifecycle-dispatch`, `rider-support-chat`, billing functions, and others.

## 3. Normal Ride Flow

Start:

- User starts from home actions like `/search`, recent places, saved addresses, or direct home destination widgets.
- `SearchScreen` sets pickup/destination on `bookingProvider`.
- `BookingFlowNavigation.routeAfterAddressesComplete` sends the rider to vehicle category, payment, or summary depending on existing profile data.

Before creation:

- `TripSummaryScreen` displays route, vehicle/payment details, optional save-for-later.
- Confirm calls `rideMatchingVariantForBookingMode(booking.effectiveRideMode).routePath`.
- Normal instant rides go to `/searching`.

Creation:

- `SearchingScreen._bootstrapRideFlow` first calls `tryRestoreActiveRideRequest`.
- If no active row is restored, it calls `RideRequestNotifier.createRide`.
- The insert writes to `public.ride_requests`.

Inserted fields include:

- `pickup_coords`, `destination_coords`
- `pickup_address`, `destination_address`
- `status = pending`
- `booking_mode = instant`
- `vehicle_category` and optionally `vehicle_categories`
- `pet_friendly`
- `estimated_distance_km`, `estimated_duration_min`
- `pickup_contact_name`
- `rider_token`, `rider_identity_id`
- `offered_fare` for non-marketplace estimates
- `preferred_driver_id` when a specific driver was selected
- `payment_methods`
- `favorites_first`, `favorites_only`

Database trigger:

- Remote trigger `ride_request_start_matching` is active on `ride_requests AFTER INSERT`.
- It calls `trg_ride_request_after_insert_matching`, which seeds the first matching batch.

Driver search:

- Current dispatch RPC is `fn_seed_ride_matching_batch(p_ride_request_id, p_batch_size, p_window_seconds)`.
- Foreground `SearchingScreen` also runs this RPC every 22 seconds while the ride is still `pending`, using batch size 4 and window 30 seconds.
- The RPC expires old pending invites for the ride, skips if there are still active invites, then inserts more rows into `ride_request_invites`.
- It stops after batch number 20.

Driver filtering:

- Driver must be `drivers.status = available`.
- Driver must have a recent `driver_locations` row updated within 3 minutes.
- Driver must have latitude/longitude.
- Driver must pass `fn_driver_can_accept_rides`, including Platform Balance lockout.
- Driver vehicle category must match requested category/categories.
- Pet-friendly rides require `drivers.accepts_pets`.
- Already-invited drivers are excluded.
- Favorites can be prioritized via `favorites_first`.
- Drivers are ordered by favorites priority and distance to pickup.

Waiting UI:

- Rider sees `SearchingScreen` with radar animation and rotating facts.
- If no live supply is found after `kRiderNoDriverCardDelay`, the app shows alternatives.
- Rider can cancel from the waiting screen.
- Rider can choose “notify me” to return home while keeping the server search alive.

Timeout:

- `kRiderDriverSearchWindow` comes from runtime config (`searchWindowMinutes`).
- The client schedules expiry from `rideCreatedAt + kRiderDriverSearchWindow`.
- On foreground expiry, app calls `cancelExpiredRiderOpenRide`, setting `ride_requests.status = cancelled`, `cancelled_by = rider`, `cancellation_reason = search_window_expired`.
- Near-term providers also cancel stale pending/bidding rows they find.
- There is a database routine `fn_expire_ride_requests`, but I did not find a checked-in cron/scheduler proving it runs automatically.

If no driver accepts:

- Foreground expiry cancels the request and shows `showDriverSearchExpiredDialog`.
- If a terminal status appears by Realtime (`cancelled`, `rejected`, `declined`, `missed`, `expired`), rider resets local state and returns home.

Driver view:

- Online drivers subscribe to `ride_request_invites` inserts for their driver ID.
- On pending invite insert, driver app haptics and navigates to `/driver/ride/new/:rideId`.
- `NewRideRequestScreen` loads the `ride_requests` row and starts a 30-second countdown.

Driver accept:

- Driver calls `driverApi.acceptRide`, which invokes `fn_driver_accept_ride_invite`.
- RPC verifies authenticated driver, billing eligibility, valid pending non-expired invite, and pending ride.
- It updates `ride_requests.status = accepted`, sets `driver_id`, supersedes other pending invites, and marks current invite accepted.
- If another driver accepts first, RPC returns race-lost behavior and the app returns driver home with an error.

Driver decline/ignore:

- Decline calls `fn_driver_decline_ride_invite`, marking that driver's invite expired.
- Ignore/timeout in `NewRideRequestScreen` also calls decline after 30 seconds.
- Ride remains pending for future batches.

Rider update:

- `SearchingScreen` subscribes to `ride_requests` updates by ride ID.
- When status becomes `assigned` or `accepted`, it refreshes widgets and routes to `/active`.
- `ActiveRideScreen` subscribes to further `ride_requests` updates and polls every 20 seconds as fallback.

## 4. Airport Ride Flow

Airport ride is not a separate backend flow.

What it does:

- `AirportBookingScreen` lets the rider pick a `BeneluxAirport`.
- `startBookingWithAirportDestination` sets `bookingProvider` to instant mode.
- It converts airport metadata into an `AddressResult`.
- It stores the airport as destination.
- It tries to fill pickup from current location.
- Then it rejoins `BookingFlowNavigation.routeAfterAddressesComplete`.

No separate airport-specific backend fields were found:

- No airport-specific table write.
- No airport-specific `ride_requests` field beyond destination address/coords.
- No special airport driver filter found.
- No special airport pricing path found in the booking creation logic.
- No separate airport notification behavior found.

Conclusion: airport is currently destination metadata plus a faster UI entry point.

## 5. Marketplace Ride Flow

Start:

- User enters `/marketplace`.
- `MarketplaceScreen` collects route and rider offer amount.
- It sets `bookingProvider.mode = marketplace` and `marketplaceBidEuro`.
- If profile is complete, `BookingFlowNavigation.routeAfterMarketplacePost` sends user to `/marketplace-matching`.

Creation:

- Marketplace also creates a `ride_requests` row.
- Required marketplace fields:
  - `booking_mode = marketplace`
  - `marketplace_offered_fare`
  - `offered_fare`
  - route/payment/vehicle fields as above

Driver notification:

- `bootstrapMarketplaceRide` calls `createRide` then `seedMarketplaceDriverInvites`.
- `seedMarketplaceDriverInvites` calls `fn_seed_ride_matching_batch` with batch size 12 and 30-second window.
- Driver side also has an “Available marketplace rides” tab querying `ride_requests` where `status = pending` and `is_market = true`.

Driver responses:

- Rider marketplace provider reads `ride_bids`.
- UI copy and model support drivers accepting rider price or sending counter offers.
- Rider can accept a `MarketplaceDriverOffer`; app updates `ride_requests.driver_id` and `status = assigned`, then marks the bid accepted.
- Rider can decline an offer; app updates `ride_bids.status = rejected`.

Realtime gap:

- Rider marketplace code subscribes to `ride_bids`.
- MCP showed Supabase Realtime publication includes `ride_requests` and `ride_request_invites`, but not `ride_bids`.
- Unless another publication exists outside `supabase_realtime`, bid realtime updates may not fire. Poll/refresh behavior exists in provider start, but live bid updates are questionable.

Duration:

- Marketplace uses the same `kRiderDriverSearchWindow` in waiting/widget logic.
- I did not find a separate marketplace expiry job beyond client stale cleanup and generic open request expiry logic.

Can rider leave app:

- Server row remains in `ride_requests`.
- Home near-term banner can rediscover pending/bidding rows.
- “Notify me” can persist a local active-search card.

Can driver still see offer if rider closes app:

- Yes, because the request is in Supabase and driver queries/realtime are server-driven, not dependent on rider app staying open.

## 6. Scheduled Ride Flow

Creation:

- User selects schedule using `showSchedulePicker`.
- `bookingProvider.scheduledAt` is set and mode becomes scheduled.
- Booking insert writes `scheduled_pickup_at` and `booking_mode = scheduled` into `ride_requests`.
- Rider lifecycle event `scheduled_ride_created` is tracked with scheduled pickup time.

Storage:

- Scheduled rides are stored in `public.ride_requests`.
- `scheduled_pickup_at` is a timestamptz column.

Driver search timing:

- Current code creates the `ride_requests` row immediately when rider confirms.
- Remote `ride_request_start_matching` trigger runs after every insert.
- The trigger does not appear to skip scheduled rides.
- Therefore, based on the active trigger and client code, scheduled rides appear to start matching immediately, not only near pickup time.

Before pickup:

- Rides tab providers query future scheduled pending/bidding rows.
- Home banner shows scheduled rides within `kRiderNearTermScheduledWindow`.
- Far-future scheduled rows show in the Rides tab section.
- Scheduled matching screen syncs scheduled ride widget state every 60 seconds while open.

Reminders:

- `fn_track_rider_lifecycle_event` and `fn_plan_rider_lifecycle_jobs` exist.
- `scheduled_ride_created` can schedule a `scheduled_3d` lifecycle job.
- Edge function `rider-lifecycle-dispatch` claims due lifecycle jobs.
- I did not verify an active scheduler/cron invoking `rider-lifecycle-dispatch`; this is a gap to verify operationally.

Pre-ride confirmation:

- Driver can send pre-ride confirmation around 16-40 minutes before scheduled pickup per migration comments.
- `driver-agent` can notify rider with category `preride_request`.
- Rider home banner polls pre-ride fields and lets rider confirm attendance.

If no driver accepts:

- Same stale/open search window applies in rider providers.
- I did not find a separate scheduled-specific “no driver by pickup time” escalation path.

## 7. Driver Matching / Dispatch Flow

Selection source:

- `driver_locations` joined to `drivers`.

Invite table:

- `ride_request_invites` contains one row per driver invite.
- Realtime is enabled remotely for this table.

Batching:

- Normal foreground expansion: 4 drivers per batch, 30 seconds.
- Marketplace explicit seeding: 12 drivers per batch, 30 seconds.
- Max batches: 20.
- The RPC skips creating a new batch while any pending invite is active.

Driver app:

- `RideInviteRealtimeListener` only subscribes while `DriverAppState.onlineAvailable`.
- Realtime insert opens `NewRideRequestScreen`.
- `NewRideRequestScreen` has a hardcoded 30-second countdown.

Push:

- `driver-agent` supports `incoming_ride` push notifications.
- Driver FCM handler can route incoming ride notification taps to `/driver/ride/new/:rideId`.
- Driver foreground FCM and cold-start notification open are wired.
- Remote `driver_agent_on_ride_requests` trigger is active on `ride_requests`, but its `INSERT` behavior only sends incoming ride if `driver_id` is already present. For normal initial pending requests with no driver, invite-specific push is not proven by that trigger.
- I did not find a trigger on `ride_request_invites` calling `driver-agent`; driver invite delivery is therefore proven by Realtime, but invite push delivery needs further verification.

## 8. Waiting / Searching State

Dedicated states exist:

- `/searching`: instant radar.
- `/marketplace-matching`: marketplace waiting/offers.
- `/scheduled-matching`: scheduled queued/details view.

Persistent home state:

- `NearTermRideHomeBanner` queries server pending/bidding rows.
- `ActiveNotifySearchCard` persists a local “notify me” state in SharedPreferences.
- Widget sync functions update iOS widgets/live activity style surfaces.

Survive app close/reopen:

- Active ride/search row is recoverable from Supabase by `tryRestoreActiveRideRequest`.
- Near-term providers rediscover pending/bidding rows by `rider_token`.
- Local notify card survives cold start through SharedPreferences until search window expires.

Cancel while searching:

- Rider can cancel in `SearchingScreen`.
- Home near-term banner can cancel an open ride.
- Active notify search can stop and cancel the server row.

Database status on cancel:

- Client stale/cancel helper sets `status = cancelled`, `cancelled_by = rider`, and a reason string.

## 9. Timeout / Retry / No Driver Found Behaviour

Timeout source:

- Client uses runtime config `searchWindowMinutes`.
- Search expiration is scheduled in foreground from `rideCreatedAt`.
- Providers also cancel stale open rows on rediscovery.

Retry/wave logic:

- Foreground matching calls `fn_seed_ride_matching_batch` every 22 seconds.
- RPC itself only inserts another batch when there are no active pending invites.
- Invite expiry is 30 seconds.

No-driver found:

- A no-supply check runs after `kRiderNoDriverCardDelay`.
- If no nearby supply is found, rider sees alternatives/growth dialog.
- Full search expiry cancels and returns home.

Server expiry:

- `fn_expire_ride_requests` exists remotely, but I did not find a committed cron or Edge schedule proving it runs.

## 10. Notifications / Push / Realtime

Realtime:

- `ride_requests` updates: rider matching and active ride state.
- `ride_request_invites` inserts: driver incoming offers.
- `ride_bids`: app subscribes, but remote publication gap found.

Rider FCM:

- `RiderFcmScope` registers rider FCM tokens when identity exists.
- `RiderFcmListener` handles foreground `FirebaseMessaging.onMessage`.
- Foreground rider notifications show snackbars or driver-ping banners.
- I did not find rider `onMessageOpenedApp` or `getInitialMessage` handling equivalent to driver.

Driver FCM:

- `DriverFcmListener` handles foreground messages, notification taps, and cold-start initial messages.
- `DriverFcmHandler` opens incoming ride screens when category is `incoming_ride` and driver is online/available.

In-app notifications:

- `notifications` table is used through `AppNotificationsService`.
- Driver-agent inserts notification rows and sends FCM through `push_devices`.

## 11. Background / Lock Screen Recovery

Important limitation: no simulator, no physical device, and no lock-screen test was run in this environment. This section is code-evidence only.

Rider app:

- App open: realtime subscriptions work for search and active ride.
- App background: server search row continues; foreground realtime listeners are not guaranteed while suspended.
- Phone locked: server row continues; rider push depends on FCM delivery and backend trigger/event coverage.
- App killed: server row continues; on reopen, `tryRestoreActiveRideRequest` and near-term providers can recover pending/active rows.
- Notification tap/cold-start routing for rider is not clearly implemented in code reviewed.

Driver app:

- App open: realtime invite listener works while online.
- App background/locked: FCM handler exists for taps and cold start, but invite push trigger from `ride_request_invites` is not proven.
- App killed: FCM initial-message path exists in driver code.
- Driver can accept after opening app; accept RPC rejects expired invite after `expires_at`.
- Accept from notification directly is not implemented; notification routes to app screen.

## 12. Gaps Found

1. Scheduled rides appear to match immediately after insert.
   Expected product behavior may be “search closer to pickup,” but active trigger currently seeds on insert.

2. `ride_bids` is not in remote `supabase_realtime` publication.
   Marketplace bid subscriptions may not receive live inserts/updates.

3. Invite push for drivers is not proven.
   Realtime invite delivery is clear. FCM incoming ride support exists, but I did not find an active invite-table trigger to call `driver-agent`.

4. Rider notification tap/cold-start routing is incomplete or not obvious.
   Driver has `onMessageOpenedApp` and `getInitialMessage`; rider listener only handles foreground messages in reviewed code.

5. Server-side stale search expiry is not operationally proven.
   `fn_expire_ride_requests` exists, but no checked-in cron/scheduler was found.

6. Remote `ride_requests` trigger contains an external HTTP webhook with embedded bearer token.
   This should be reviewed and migrated to a safer secret-managed path.

7. Marketplace “accept offer” writes `status = assigned`, while driver accept RPC uses `accepted`.
   The app accepts both in many places, but status vocabulary should be normalized before redesign.

8. Scheduled reminders depend on lifecycle dispatcher scheduling.
   DB functions and Edge Function exist, but active scheduler invocation still needs verification.

## 13. Risks

- Rider may believe a scheduled ride is queued for later while drivers are actually invited immediately.
- Marketplace offer UI may fail to update live if `ride_bids` realtime publication is missing.
- Driver lock-screen ride offers may be unreliable if Realtime is the only proven invite channel.
- Rider may miss background/cold-start state changes without robust notification tap handling.
- Client-side stale cleanup means abandoned searches may remain pending until another app/provider path touches them unless server expiry is scheduled.
- Hardcoded/exposed secret in a database HTTP trigger is a security and rotation risk.

## 14. Recommended UX Improvements

These are design recommendations, not implemented in this audit:

- Single persistent “active booking” surface on home for instant/marketplace/scheduled.
- Clear status language:
  - “Looking for nearby drivers”
  - “4 drivers notified”
  - “Next drivers being notified”
  - “Driver found”
  - “No driver yet”
- Scheduled rides should show a timeline:
  - Request created
  - Driver search starts at X
  - Driver assigned
  - Pickup reminder
- Marketplace should show:
  - Drivers notified count
  - Offer expiry
  - Live bid/counter list
  - Clear “boost offer” action
- Background search should explain what still happens after closing the app.
- Rider notification tap should always reopen the exact active booking or active ride.

## 15. What We Can Improve Without Changing Business Logic

- Polish booking/search/summary UI.
- Add clearer waiting copy and progress indicators.
- Improve home active booking card.
- Add safer empty/error states for searching and scheduled matching screens.
- Add local polling fallback for marketplace offers while `ride_bids` realtime is not fixed.
- Improve rider foreground notification routing/snackbar copy.
- Improve “no driver found” recovery UI.
- Add clearer cancellation confirmations.
- Improve scheduled ride detail screen and Rides tab grouping.

## 16. What Would Require Backend Changes

- Delay scheduled driver search until a configured lead time before pickup.
- Add/verify server-side cron for stale ride expiry.
- Add `ride_bids` to Supabase Realtime publication.
- Add invite-table trigger or Edge Function path to send driver FCM for each invite.
- Normalize ride status vocabulary (`assigned` vs `accepted`).
- Add push/deep-link payloads that route rider directly to active search/ride on cold start.
- Move remote HTTP trigger secrets into managed Edge Function secrets or remove legacy HTTP trigger.
- Add scheduled ride reminder scheduler verification and monitoring.
- Add richer dispatch status table/events for “drivers notified,” “batch number,” “next wave,” and “no supply.”

## Evidence Index

Code paths reviewed:

- `apps/rider/lib/router.dart`
- `apps/rider/lib/providers/booking_provider.dart`
- `apps/rider/lib/providers/ride_request_provider.dart`
- `apps/rider/lib/screens/search_screen.dart`
- `apps/rider/lib/screens/trip_summary_screen.dart`
- `apps/rider/lib/screens/searching_screen.dart`
- `apps/rider/lib/screens/marketplace_screen.dart`
- `apps/rider/lib/providers/marketplace_offers_provider.dart`
- `apps/rider/lib/screens/airport_booking_screen.dart`
- `apps/rider/lib/services/booking_airport_selection.dart`
- `apps/rider/lib/providers/active_search_provider.dart`
- `apps/rider/lib/providers/near_term_ride_request_provider.dart`
- `apps/rider/lib/screens/active_ride_screen.dart`
- `apps/rider/lib/widgets/rider_fcm_listener.dart`
- `apps/driver/lib/widgets/ride_invite_realtime_listener.dart`
- `apps/driver/lib/screens/new_ride_request_screen.dart`
- `apps/driver/lib/widgets/driver_fcm_listener.dart`
- `apps/driver/lib/services/driver_fcm_handler.dart`
- `packages/heycaby_api/lib/src/driver_api.dart`
- `supabase/functions/driver-agent/*`
- `supabase/functions/rider-lifecycle-dispatch/index.ts`
- Relevant migrations under `supabase/migrations/`

Read-only Supabase MCP checks:

- Listed active Edge Functions.
- Confirmed key public tables.
- Confirmed relevant routines.
- Confirmed active `ride_requests` triggers.
- Confirmed `supabase_realtime` publication includes `ride_requests` and `ride_request_invites`, not `ride_bids`.
- Confirmed key `ride_requests` columns.

## Implementation Appendix — Booking Flow Polish Pass

Completed in this pass:

- Added rider notification tap/cold-start recovery in `RiderFcmListener`.
- Foreground notification snackbars can now reuse the same recovery path instead of hard-linking blindly.
- Recovery hydrates the `ride_requests` row from Supabase before routing.
- Active ride notifications route to `/active` or `/chat` when allowed.
- Pending/bidding ride notifications route to the correct matching screen based on `booking_mode`.
- Home near-term ride banner now has an explicit Open action.
- The Open action hydrates the ride row and resumes instant, marketplace, or scheduled matching.
- Instant/marketplace waiting screens now show a compact live status strip with elapsed time, remaining search window, and marketplace offer count when applicable.
- Marketplace offers now have a 4-second polling fallback, so rider offer cards can still refresh while `ride_bids` Realtime publication is pending remote deployment.
- Removed one rider analyzer warning from an unused support contact row parameter.
- Added an idempotent local migration to add only `public.ride_bids` to `supabase_realtime`.

Verification completed:

- `flutter analyze --no-fatal-infos --no-fatal-warnings apps/rider/lib/widgets/rider_fcm_listener.dart apps/rider/lib/services/rider_notification_router.dart apps/rider/lib/widgets/near_term_ride_home_banner.dart apps/rider/lib/providers/marketplace_offers_provider.dart apps/rider/lib/screens/marketplace_matching_screen.dart` — passed with no issues.
- `flutter analyze --no-fatal-infos --no-fatal-warnings apps/rider/lib` — passed with no warnings/errors; remaining output is existing analyzer info backlog.
- `cd apps/rider && flutter test test/booking_flow_test.dart test/route_audit_test.dart --no-pub` — passed.
- Supabase MCP read-only smoke confirmed production and staging both have `ride_requests`, `ride_request_invites`, `ride_bids`, `fn_seed_ride_matching_batch`, `fn_driver_accept_ride_invite`, and `fn_driver_decline_ride_invite`.
- Supabase MCP confirmed staging Realtime publication includes `ride_bids` after migration.
- Supabase MCP confirmed production Realtime publication includes `ride_requests`, `ride_request_invites`, and `ride_bids` after migration.
- Supabase MCP confirmed production `driver-agent` Edge Function is active.
- Local inspection confirmed rider-facing `driver-agent` payloads include `ride_request_id`, `screen`, `category`, and delivery-added `notification_id`, which is enough for rider notification tap/cold-start recovery to hydrate the correct ride.

Remote deployment status:

- Staging migration applied by Supabase MCP: `add_ride_bids_to_realtime`.
- Staging smoke passed with 7 realtime events for 7 write operations:
  - Insert driver offer.
  - Update driver offer.
  - Withdraw driver offer.
  - Insert three simultaneous offers.
  - Reconnect and receive a follow-up update.
- Staging reconnect snapshot returned 4 current marketplace offers and the reconnect channel received the follow-up update.
- No duplicate events were observed in the staged headless smoke.
- Synthetic staging smoke data cleanup was verified with zero remaining smoke ride requests, riders, drivers, or auth users.
- Production migration applied by Supabase MCP after staging smoke and rider regression checks passed.
- Production publication verification returned `ride_bids`, `ride_request_invites`, and `ride_requests`.
- No synthetic production smoke data was created.

## Implementation Appendix — Reliability Hardening Pass 2

Completed and deployed:

- Scheduled rides no longer seed driver invites immediately when the pickup time is outside the configured matching lead window.
- The scheduled matching lead window is server-driven through `search_config.scheduled_matching_lead_minutes`, defaulting to 30 minutes and clamped to 5-240 minutes.
- Added `fn_seed_due_scheduled_ride_matching`, which seeds pending scheduled rides only when they enter the lead window.
- Scheduled matching cron is active in staging and production:
  - `heycaby_due_scheduled_matching` every 5 minutes.
- Server-side stale ride expiry cron is active in staging and production:
  - `heycaby_expire_ride_requests` every 2 minutes.
- `notify_driver_agent_trigger` now reads the Edge Function URL from `app_config.agent_webhook_url` instead of hardcoding one project URL.
- Staging now has its own `agent_webhook_url` and generated `agent_webhook_secret`, so DB webhooks do not accidentally call production.

Staging verification:

- Inserted a synthetic scheduled ride 2 hours in the future.
- `fn_seed_ride_matching_batch` returned `scheduled_deferred`.
- `matching_starts_at` was 30 minutes before pickup.
- Driver invite count remained `0`.
- Synthetic scheduled smoke rows were cleaned up.
- Deployed `driver-agent` to staging with DB webhook mode.
- Added a staging-only `ride_request_invites` trigger to call `driver-agent`.
- Inserted a synthetic driver invite.
- The DB webhook reached `driver-agent` successfully after JWT verification was disabled for the webhook function.
- `driver-agent` created one `incoming_ride` notification and one agent log for the synthetic invite.
- Synthetic invite smoke rows, notification, agent log, driver, and auth user were cleaned up.

Production status:

- Scheduled matching defer guard is deployed.
- Scheduled matching cron is active.
- Stale ride expiry cron is active.
- `agent_webhook_url` is configured for production.
- The production `ride_request_invites` trigger is intentionally not active yet.
- Production `driver-agent` was not redeployed with `--no-verify-jwt` because that is a persistent production webhook security-setting change and needs explicit approval.

Production driver invite push deployment:

- Production approval was granted for `driver-agent --no-verify-jwt` only for database webhook delivery, protected by the in-function `x-webhook-secret` check.
- Production `driver-agent` now requires `AGENT_WEBHOOK_SECRET` from Supabase Edge Function secrets for DB webhook requests.
- The database sender secret was moved out of `app_config` and into Supabase Vault.
- Production verification confirmed:
  - `app_config.agent_webhook_secret` rows: `0`.
  - Vault `agent_webhook_secret` rows: `1`.
  - `agent_webhook_url` rows: `1`.
  - `driver_agent_on_ride_request_invites` trigger count: `1`.
- Production smoke created exactly one synthetic invite.
- Production smoke verified exactly one `incoming_ride` notification and one agent log for that invite.
- Production smoke cleanup removed exactly one notification, one agent log, one invite, one ride, one driver, and one auth user.
- Final production cleanup verification returned zero synthetic smoke rides, drivers, and auth users.
