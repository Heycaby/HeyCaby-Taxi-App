# Driver Transactional Email Contract (Phase 1)

This document defines the driver-first SES rollout contract.

## Scope

Phase 1 sends only backend-owned transactional emails for drivers. Supabase Auth OTP email flow remains unchanged.

## Event Types

### `driver_compliance_blocked_v1`

- **Trigger source:** Go backend `driver_service.SetStatus` when driver attempts `available` and readiness fails.
- **Recipient:** driver email from `public.drivers.email`.
- **When to send:** only when `blocked_reason` is non-empty.
- **Idempotency key format:**
  - `driver_compliance_blocked_v1:{driver_id}:{blocked_reason}:{yyyy-mm-dd}`
  - daily dedupe per reason to avoid spam while still reminding active drivers.
- **Payload fields:**
  - `driver_id`
  - `driver_name`
  - `driver_email`
  - `country_code`
  - `blocked_reason`
  - `status_message`
  - `checklist_url` (defaults to `/driver/documents` in app/web context)
- **Success policy:**
  - mark event `sent` with provider message id.
- **Failure policy:**
  - retry transient provider failures up to 3 attempts with short backoff.
  - mark as `failed` after final attempt.

## Status Model

Driver email event rows use:

- `queued`
- `sent`
- `failed`
- `suppressed`

`suppressed` covers duplicate/idempotent drops where an already-sent key exists.

## Operational Rules

- Keep provider logic behind `EMAIL_SES_ENABLED` feature flag.
- Use structured logging with:
  - `template_id`
  - `event_type`
  - `driver_id`
  - `idempotency_key`
  - `provider_message_id`
  - `attempt_count`
  - `status`
- Do not include raw email body in logs.

## Rollout

1. Deploy with `EMAIL_SES_ENABLED=false` (no sends).
2. Enable for internal test accounts.
3. Observe success/failure counters and bounce behavior.
4. Enable for broader driver cohorts.
