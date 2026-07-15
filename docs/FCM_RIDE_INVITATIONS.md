# Driver Ride-Invitation Push Contract

## Source of truth

`ride_request_invites` and `ride_requests` own invitation state and expiry.
`driver-agent` owns provider delivery. Flutter renders server truth and never
uses an active socket as the only alert mechanism.

The delivery path is:

```text
canonical dispatch creates a live invite
  -> database webhook invokes driver-agent
  -> driver-agent revalidates invite + ride state
  -> APNs alert (preferred for registered iOS devices) or FCM fallback
  -> iOS displays the visible notification while locked/backgrounded
  -> notification tap opens the Driver app
  -> DriverIncomingRideCoordinator revalidates the invite
  -> live request screen, or a deterministic unavailable/expired message
```

Supabase Realtime remains useful while the app is active. It is not the
background wake-up authority.

## iOS contract

- Normal APNs alert notification; no PushKit, VoIP entitlement, or CallKit.
- `apns-push-type: alert`, priority `10` for incoming rides.
- Time-sensitive interruption level for critical incoming-ride alerts.
- Bundled sound name: `heycaby_ride_request.wav`.
- Payload includes `ride_request_id`, `ride_invite_id`, category, and the
  authoritative server expiry.
- Debug builds register `apns_environment = sandbox`. Profile/release builds
  leave it unresolved because local development provisioning and App Store
  provisioning can both run optimized code.
- Apple development provisioning can still be used for a locally installed
  release-mode binary. If APNs reports an environment/topic mismatch, the
  backend safely retries the opposite APNs host once and persists the resolved
  environment; an accepted push is never sent twice.
- APNs authentication credentials remain Edge Function secrets.
- Real device tokens are never logged or returned to another user.

The Runner target has Push Notifications enabled, `remote-notification` in
background modes, development APNs entitlement for debug, and production APNs
entitlement for release. Notification permission requests alert, badge, and
sound access.

## Device registration

`HeyCabyFcmRegistration` calls the single canonical RPC
`fn_register_push_device` with:

- FCM token;
- platform and app role;
- APNs token on Apple devices;
- APNs environment;
- Rider identity only for the Rider role.

Registration occurs when a session becomes available, on token refresh, when
the Driver shell starts with an existing session, and whenever the app resumes.
The `push_devices` table is not client-writable.

An invalid APNs token is cleared independently. A usable FCM token for the same
device is retained and used as fallback. Provider message IDs, accepted/failed
counts, and error codes are written to `agent_logs`; tokens are omitted.

## App-state handling

- Foreground: `FirebaseMessaging.onMessage` opens the existing incoming-ride
  presentation and its in-app sound.
- Background/locked: iOS owns the visible alert and sound.
- Notification tap: `FirebaseMessaging.onMessageOpenedApp` routes by ride ID.
- Terminated launch: `getInitialMessage()` routes after initialization.
- Background callback: top-level `onBackgroundMessage` performs only limited
  initialization; it does not pretend Flutter can render while suspended.
- Stale/accepted/expired request: the coordinator checks Supabase before
  exposing Accept and shows “no longer available” when appropriate.

## Server payload and expiry

Incoming notifications contain a visible title, pickup summary, sound, invite
ID, ride ID, and expiry. `driver-agent` checks liveness twice: before persisting
the notification and immediately before provider delivery. Provider expiration
and collapse IDs prevent delayed duplicate alerts from becoming actionable.

The backend logs:

- notification and correlation identifiers;
- intended device count;
- APNs/FCM provider chosen;
- provider acceptance ID;
- accepted, failed, and invalid-token counts;
- safe provider error codes.

## Physical-device release checklist

Use production Supabase project `fvrprxguoternoxnyhoj` and real iPhones.

1. Install a release build and sign in as the Driver.
2. Confirm one `push_devices` row has iOS, both tokens, and environment
   `production`.
3. Put the Driver online and create a real Rider request.
4. Repeat with Driver app foregrounded, backgrounded, screen locked, another
   app open, and app terminated.
5. Confirm tap routing opens that ride and the backend rejects an expired or
   already accepted invite.
6. Repeat under poor network, notification sound disabled, and Focus enabled;
   document that iOS user settings control presentation.
7. Inspect `agent_logs` for provider acceptance or a deterministic provider
   error without exposing tokens.

An ordinary iOS app cannot force an unrestricted phone-call-style full-screen
surface. Lock-screen presentation and sound remain subject to the Driver's iOS
notification, Focus, sound, and lock-screen settings.

## Production verification — 2026-07-15

- Firebase project: `heycaby-2457a`.
- Driver Firebase/Xcode bundle: `nl.heycaby.driver.app`.
- Rider Firebase/Xcode bundle: `nl.heycaby.rider.app`.
- Firebase Cloud Messaging API v1: enabled.
- APNs authentication key is configured for development and production on
  both Firebase iOS apps (Key ID `2LL3K6PY7M`, Team ID `AV666KZUVS`).
- Production Supabase direct-APNs secrets have hashes matching the same local
  key file, Key ID, and Team ID; secret values are not recorded here.
- Controlled FCM-only production delivery: accepted (`pushed=1`, `failed=0`,
  no provider error).
- Controlled direct-APNs production delivery: accepted (`pushed=1`,
  `failed=0`, no provider error).
- Clean exported Rider and Driver IPAs contain the correct Firebase project and
  bundle IDs, production APNs entitlement, and `get-task-allow=false`.
