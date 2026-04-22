---
name: rider-security-identity
description: Explains how Rider identity, secure storage, and backend synchronization work so the agent can safely modify authentication-adjacent flows without exposing sensitive data.
---

# Rider Security and Identity Skill

## When to use this skill

Use this skill whenever you:
- Touch code that reads or writes rider tokens, identity IDs, emails, or booking names.
- Modify secure storage behavior for the Rider app.
- Change how rides are linked to riders on the backend.

## Identity model

- Core types live in `packages/heycaby_api`:
  - `RiderIdentityState` holds identityId, riderToken, email, bookingName, and flags.
  - `RiderIdentityNotifier` (AsyncNotifier) loads identity from secure storage on build.
- Identity is persistent and is not tied to explicit login screens; it’s created and enriched progressively.

## Secure storage

- Secure storage wrapper:
  - Defined in `packages/heycaby_api/lib/src/secure_storage.dart`.
  - Uses `flutter_secure_storage` under the hood.
  - Stores:
    - `rider_token`
    - `rider_identity_id`
    - `rider_email`
    - `rider_booking_name`
- Rules:
  - Always go through the provided secure storage helpers and identity notifier.
  - Do not introduce alternate storage paths for these values.

## Progressive enrichment

- Booking name:
  - Collected during booking (pickup contact name).
  - If the backend has no booking name yet, it is persisted via the identity notifier when the first ride is created.
- Email:
  - Collected when the rider accesses favorites or other account-like features.
  - Stored in secure storage and synced to backend.
- These flows allow guest booking first, and account data later, without ever blocking the ride.

## Logging and security

- Do not log raw identity IDs, tokens, or emails.
- When debugging, log only masked identifiers (for example, last 4 characters) if absolutely necessary.
- Never print environment variables or Supabase keys.
- Keep all network calls that use identity scoped to the existing API client and Supabase helpers.

