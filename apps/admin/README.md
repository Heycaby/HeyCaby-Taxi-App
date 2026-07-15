# HeyCaby Admin OS

Production operations website for `https://admin.heycaby.nl`.

## Architecture boundary

Admin OS is a control plane, not a second business source of truth.

- Supabase remains authoritative for backend state.
- Read screens consume privacy-safe `fn_admin_os_*` projections.
- Mutations call canonical, permission-scoped RPCs or existing Edge Functions.
- Ride and payment lifecycle state is never directly overridden by the website.
- The website uses only the Supabase publishable key and the signed-in Admin JWT.
- Sensitive commands require AAL2 MFA inside PostgreSQL, not only in the UI.
- Driver restrictions are reversible from a recorded previous-state snapshot.
- Sensitive access and commands write `admin_activity_logs` events.

The backend contracts are defined by:

- `supabase/migrations/20260715060705_admin_os_control_plane.sql`
- `supabase/migrations/20260715061939_admin_os_initial_admin_link.sql`

## Surfaces

- Overview: production aggregates for drivers, rides, operations, and money.
- Drivers: masked directory, readiness, coarse location freshness, reversible restrictions.
- Rides: read-only canonical ride state.
- Support and Reports: prioritized queues with MFA-gated audited resolution.
- Communications: MFA-gated Web Push through the existing backend service.
- Finance and Payments: ledger-derived totals and Mollie payment journal.
- Audit: administrator activity evidence.
- Admin AI: read-only aggregate analyst; no mutation tools or PII context.

## Local verification

```sh
npm install
npm run typecheck
npm test
npm run build
```

Required public environment:

```sh
NEXT_PUBLIC_SUPABASE_URL=https://fvrprxguoternoxnyhoj.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=...
```

`OPENAI_API_KEY` is optional and server-only. Without it, Admin AI fails closed with a clear unavailable message. Configure `OPENAI_ADMIN_MODEL` to pin the approved model.

## Ownership and rollback

- Operational owner: HeyCaby platform operations.
- Technical owner: backend/platform engineering.
- Authentication owner: Supabase Auth administrators.
- Deployment owner: Vercel `heycaby-admin` project administrators.
- Rollback: promote the last known-good Vercel deployment. Database contracts are additive; do not remove them while a deployed Admin version may call them.
- Escalation: disable the affected Admin registry account, preserve audit logs, and investigate by resource/correlation ID.

## Privacy rules

- Exact live GPS is not shown in directory views.
- Rider tokens and Auth identifiers are not exposed.
- Emails and phone numbers are masked in lists.
- Detailed PII access requires the `privacy.pii` permission and a recorded reason.
- Do not add direct table writes or a service-role key to this app.
