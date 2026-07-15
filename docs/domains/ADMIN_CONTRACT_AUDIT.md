# HeyCaby Admin Domain Contract Audit

Status: **PARTIAL — repository-owned Admin surface verified; external Admin
consumer inventory still required**  
Production project: `fvrprxguoternoxnyhoj`  
Last updated: 2026-07-15

## Rule

Admin is a privileged consumer of domain commands, never an independent source
of business truth. An Admin action must call the same canonical backend command
or a narrowly scoped Admin RPC, use the domain status vocabulary, authorize from
server-owned claims/tables, write a correlated audit event, and leave protected
state unavailable to direct client updates.

## Repository-owned Admin surface

| Action | Domain authority | Authorization | Audit | Result |
| --- | --- | --- | --- | --- |
| Set manual Driver verifications | `fn_admin_set_manual_verifications` / Driver Readiness | `auth.uid()` plus `auth.users.raw_app_meta_data.role` in `admin, super_admin` | `private.domain_security_events`: denied and before/after changed events | Pass |
| Read Shift Handover audit list | `fn_admin_shift_handover_list` / Fleet | `fn_shift_handover_staff_is_authorized` using `admin_users` or server-owned role metadata | Read only | Pass with compatibility risk |
| Read Fleet allowlist | `fn_admin_shift_handover_allowlist_list` / Fleet | `fn_shift_handover_fleet_can_manage_vehicle` | Read only | Pass with compatibility risk |
| Add/remove Fleet allowlist Driver | `fn_admin_shift_handover_allowlist_set` / Fleet | `fn_shift_handover_fleet_can_manage_vehicle`; fail-closed boolean check | Correlated denied or before/after changed event in `private.domain_security_events` | Pass |
| Read prepaid payment timeline | `fn_admin_ride_payment_timeline` / Payments | Active `admin_users` membership; read-only projection | Payment/refund/route/webhook events are append-only backend evidence | Backend pass; Admin consumer missing |
| Refund, fee, no-show, retry route, or void prepaid payment | `ride-payment-admin-command` / Payments | Verified JWT, active Admin membership, `admin`/`super_admin` role, mandatory reason | Correlated payment event plus `ride_audit_log` actor | Backend pass; Admin consumer missing |
| Update payment policy/cohort | `fn_admin_update_ride_payment_policy`, `fn_admin_update_ride_payment_rollout` / Payments | Active role-bound Admin membership | Before/after `ride_payment_config_audit` | Backend pass; Admin consumer missing |

The Driver app surfaces these Fleet/Admin RPCs only to users whose server-owned
app metadata resolves to staff/fleet roles. The UI check is convenience only;
every RPC repeats authorization in Postgres.

## Compatibility classification

The three Shift Handover read/write RPCs still have explicit `anon` execute
grants in production. Their function bodies deny anonymous callers because
`auth.uid()` cannot resolve to staff or a Fleet owner. These grants are an
**accepted compatibility risk / product decision required**, not an endorsement
of anonymous Admin access. They must not be revoked until minimum app versions
and Legacy Shift Handover retirement are approved in
`COMPATIBILITY_DECISION_LOG.md`.

`fn_admin_set_manual_verifications` is not executable by `anon` and remains
callable by `authenticated` only because the function performs the server-owned
Admin-role check itself.

## Production evidence

- Migration `20260714065613:admin_shift_handover_audit_hardening` is applied.
- Isolated PostgreSQL tests passed authorized add, idempotent add, removal,
  unauthenticated denial, denied audit, before/after audit, and correlation ID.
- `supabase/tests/admin_domain_contract_test.sql` passes in production.
- Production rollback smoke returned `invalid_target` and observed the matching
  `shift_handover_allowlist_denied` audit event by correlation ID; no vehicle or
  Driver row was touched.
- Advisor warnings for the retained Shift Handover grants are classified as
  compatibility/product-decision risk. There are no relevant performance
  findings.

## External Admin inventory still required

No standalone Admin application source exists in this monorepo. Before the
overall audit can be marked complete, the owning repository/deployment must be
provided and checked for:

- ride assignment and cancellation;
- Driver eligibility and account restrictions;
- Platform Balance and refunds;
- reports and support moderation;
- Taxi Terug operations;
- receipt/payment correction;
- canonical status vocabulary;
- role authorization and correlated audit events.

Until that inventory is complete, do not remove any Admin-facing RPC, grant, or
legacy response shape.

For prepaid payments specifically, the missing Admin client must not directly
write `ride_payments`, `ride_payment_refunds`, `ride_payment_routes`,
`ride_requests.payment_status`, or payment-related `app_config` rows. It must
call the deployed commands above, show a mandatory-reason confirmation and
pending state, and refresh final status from the read-only timeline after the
Mollie webhook reconciles it.
