# HeyCaby Masked Calling Blueprint

Status: dark-launched control plane; production activation is blocked until the owner test and Twilio inventory are complete.

## Decision and source of truth

Masked calling belongs to the Ride Communications domain. Supabase owns eligibility, time windows, rate limits, participant binding, number allocation and audit state. Twilio transports calls and reports telephony state. Rider, Driver and Admin render backend projections; none calculates permission or receives the other participant's phone number.

HeyCaby uses custom Twilio Programmable Voice with a server-initiated two-leg bridge. There was no existing Twilio implementation to preserve. Twilio Proxy was not selected because it is a Public Beta without an SLA and the HeyCaby lifecycle needs strict arrival, time-limit and callback control. The two systems must never be enabled for the same ride.

An already connected call may finish its five-minute allowance when the ten-minute post-ride initiation window closes. No new call can begin after that window.

## Existing inventory audit

- `ride_requests` is the lifecycle authority and already contains `driver_arrived_at`, `completed_at`, Rider and assigned Driver bindings.
- Server-verified arrival is implemented by the Ride Verification domain.
- `messages`, `conversations`, `fn_send_ride_message` and ride chat block/report tables own in-app chat.
- `ride_contact_attempts` already supports `masked_call`; it is reused for no-show evidence instead of creating a duplicate generic contact log.
- Driver phone data exists in the Driver domain. Signed-in Rider calling uses a verified Supabase Auth phone. Anonymous or unverified Riders receive `phone_missing`.
- No Twilio credential, Proxy session, Voice webhook or hardcoded proxy number existed in the repository at audit time.
- Admin Communications previously covered controlled Push and a disabled arbitrary-email surface. The canonical masked-calling aggregate is added there.

## Product contract

| Ride state | Ping | In-app message | Masked call |
|---|---:|---:|---:|
| Searching / unassigned | Existing policy | No | No |
| Accepted / en route | Yes | Yes | No |
| Server-verified `driver_arrived` | Yes | Yes | Yes |
| `in_progress` | Yes | Yes | Yes |
| Completed, first 10 minutes | — | Yes | Yes |
| Completed, 10–120 minutes | — | Yes | No |
| Completed, after 120 minutes | — | No | No; Support/Lost Item only |

Today’s Rides is a rolling 24-hour backend window, not a device calendar day. Ride History has receipts and Support/Lost Item actions but no expired direct-communication controls.

## Supabase contract

The migrations `20260715094600_masked_ride_calling_control_plane.sql` and
`20260715095959_masked_calling_lifecycle_monitoring.sql` add:

- `ride_communication_sessions`: one logical relationship per ride, without real phone numbers.
- `ride_call_attempts`: call status, timing, cost and failure metadata; no real phone numbers.
- `twilio_number_pool`: server-only production/development inventory and cooldown state.
- `twilio_voice_webhook_events`: idempotent, redacted webhook evidence.
- `twilio_usage_snapshots`: server-synchronized balance and cost aggregates.
- `ride_communication_operational_alerts`: service-owned, correlation-linked
  provider/capacity alerts.

All tables have RLS enabled, no `anon` or `authenticated` table grants, and service-role-only writes. Canonical functions are:

- `fn_ride_communication_permissions(ride_id)`: authenticated Rider/assigned Driver projection.
- `fn_create_masked_call_intent(ride_id, idempotency_key)`: participant-bound, rate-limited and atomically allocates a number.
- `fn_ride_call_state(ride_id)`: sanitized client state.
- `fn_masked_call_routing_context(attempt_id)`: service-only telephone routing context.
- `fn_authorize_masked_call_attempt(attempt_id)`: service-only final lifecycle check when Twilio requests TwiML.
- `fn_update_masked_call_attempt(...)`: service-only callback transition.
- `fn_record_twilio_voice_webhook(...)`: service-only idempotent delivery record.
- `fn_admin_os_communications_overview()`: privacy-safe Admin aggregate.

Default config is stored in `app_config.ride_communication_config`. `masked_calling_enabled` is `false`. Limits are 300 seconds, 10 post-ride call minutes, 120 post-ride message minutes, three attempts per participant, 30 seconds between attempts, and 45 minutes number cooldown.

## Edge Functions and Twilio contract

- `ride-masked-call-start` requires a Supabase JWT, invokes the canonical intent RPC, obtains the service-only routing context and creates the first Twilio leg.
- `twilio-voice-twiml` is public only for Twilio, validates `X-Twilio-Signature`, reauthorizes the attempt and emits `<Dial timeLimit="300" record="do-not-record">` for the recipient leg.
- `twilio-voice-status-webhook` validates the exact public URL signature, stores only a redacted/idempotent callback, and updates canonical call state.

Required production Edge secrets:

- `TWILIO_ACCOUNT_SID`
- `TWILIO_AUTH_TOKEN`
- `TWILIO_VOICE_PUBLIC_BASE_URL=https://fvrprxguoternoxnyhoj.supabase.co/functions/v1`

Secrets never enter Flutter, Realtime, Admin HTML, logs or database client projections. Number inventory is added to `twilio_number_pool` by a privileged operational sync; no Apple release is required.

## Number pool

Numbers must be E.164, voice-capable, Dutch-regulation suitable and tagged for exactly one environment. Allocation uses a database row lock with `SKIP LOCKED`. There is one active communication session per ride and one active call per ride. A number moves `available → active → cooldown → available`; cooldown defaults to 45 minutes. Production and development inventories may not overlap.

Alerts: zero/low available capacity, allocation failures, disabled numbers, unhealthy numbers, and utilization above the agreed capacity threshold. Capacity planning uses peak simultaneous eligible sessions, not total daily rides.

## UX

Before arrival, both apps remain Ping/Chat first and do not render Call. After canonical permission returns `can_call=true`, the communication surface shows “Call through HeyCaby.” Confirmation explains privacy, the five-minute cap and that HeyCaby calls the initiator first. The mobile timer is display-only. Provider callbacks own queued/ringing/connected/ended/failed state.

Failure copy never exposes numbers: temporarily unavailable, pool busy, no answer, window ended, or verify your own phone. Native incoming-call UI may display the assigned HeyCaby number; the peer’s number is never used as caller ID.

## Privacy, safety and abuse controls

- Recording is disabled in config and TwiML. Enabling it is a separate legal/consent project.
- Blocks close direct communication; Support remains available.
- Only operational SID, state, timestamps, duration, cost, roles and correlation IDs are retained.
- Webhook payloads are allowlisted/redacted before storage.
- Three attempts per side, 30-second cooldown, one active call per ride and unique idempotency keys prevent rapid/duplicate calling.
- Client-supplied destination, caller ID, duration and policy values are ignored.
- Admin sees aggregates and masked operational context, never raw participant numbers or Twilio secrets.

## Admin and monitoring

Admin Communications displays calls today, answered/failed counts, minutes, average duration, five-minute terminations, initiator split, pool capacity/failures and the latest server-synchronized Twilio balance/cost snapshot.

Required alerts carry ride, attempt and correlation IDs:

- invalid Twilio signature or replay;
- unknown callback/call SID;
- pool below minimum or exhausted;
- elevated failed/no-answer rate;
- call duration over 300 seconds;
- permission outside lifecycle or after expiration;
- duplicate session/active call;
- Twilio CPS queue delay;
- low account balance;
- repeated unusual Rider/Driver calling patterns.

The five-minute `ride-communication-maintenance` job closes expired sessions,
moves numbers through cooldown, releases healthy numbers, and scans signature,
failure-rate, balance and pool-capacity alerts. Ride completion and participant
blocks synchronize communication sessions immediately through database triggers.

## Verification matrix

Automated database tests must cover non-participant denial, call hidden before arrival, activation after verified arrival, block/restriction denial, exact post-ride windows, message expiry, attempt limits, cooldown, idempotent retry, one active call, pool exhaustion, no client table grants, no number in projections and Admin privacy.

Edge tests must cover valid/invalid Twilio signatures, exact public URL handling, TwiML `timeLimit=300`, `record=do-not-record`, redacted callbacks, duplicate callbacks and provider failure recovery.

Physical-phone owner test in production (internal accounts only): accepted/en-route hidden; verified arrival visible; two real phones bridge with hidden numbers; five-minute termination; ten-minute initiation expiry; two-hour chat expiry; block closes communication; disabled number fails safely; Admin totals/cost/pool update. No call is recorded.

## Rollout and rollback

1. Apply the additive migration with the feature flag disabled.
2. Deploy the three Edge Functions and configure secrets.
3. Add at least two healthy production Twilio numbers and verify regulatory status.
4. Run SQL/security/Flutter/Admin regression suites.
5. Enable only for owner/internal production accounts via a cohort policy extension.
6. Run the two-phone owner test and monitor callbacks, pool and cost.
7. Expand gradually after an error-free observation period.

Emergency rollback is configuration-only: set `masked_calling_enabled=false`. Ping, in-app chat and ride lifecycle remain independent and continue working. Existing connected Twilio calls retain their server-enforced maximum, while no new intent is authorized.

## Production verdict

**NO-GO for activation; GO for disabled production deployment.** The control plane and UI are deliberately dark until credentials, number inventory, alert destinations, Twilio signature tests and the two-phone owner test pass. Enabling the flag before those checks would violate the release boundary.
