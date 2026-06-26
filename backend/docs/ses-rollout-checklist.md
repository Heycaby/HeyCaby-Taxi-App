# SES Rollout Checklist (Driver Phase 1)

## Environment

- `EMAIL_SES_ENABLED=false` by default in all environments.
- `EMAIL_SES_REGION` set to target SES region.
- `EMAIL_FROM_ADDRESS` is a verified SES identity.
- Optional:
  - `EMAIL_REPLY_TO_ADDRESS`
  - `EMAIL_SES_CONFIGURATION_SET`
  - `EMAIL_SES_MAX_ATTEMPTS` (default `3`)

## AWS SES Prerequisites

- Domain or sender identity verified in SES.
- DKIM enabled.
- SPF and DMARC records configured.
- Account moved out of SES sandbox for production traffic.
- Suppression handling reviewed in SES console.

## Staged Rollout

1. Deploy backend with email service code and `EMAIL_SES_ENABLED=false`.
2. Trigger driver blocked readiness flow and verify:
   - `driver_email_events` row is created as `queued`/`suppressed` behavior as expected.
   - no outbound email is attempted while disabled.
3. Enable `EMAIL_SES_ENABLED=true` in staging/internal environment.
4. Trigger blocked readiness flow again and verify:
   - event transitions to `sent` with `provider_message_id`.
   - idempotency key prevents duplicate sends on repeated attempts same day.
5. Observe logs and SES metrics for failures/bounces.
6. Roll out to production cohorts.

## Rollback

- Immediate rollback switch: set `EMAIL_SES_ENABLED=false`.
- This preserves app behavior and suppresses new sends without code rollback.

## Manual Verification

- Driver with missing docs tries to go online and remains blocked.
- Driver receives transactional compliance email.
- Repeating same blocked action same day does not spam duplicate emails.
- Transient provider failures are retried (up to configured max attempts).
- Final status is persisted in `driver_email_events`.
