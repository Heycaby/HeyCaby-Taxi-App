# HeyCaby Compatibility Decision Log

Last updated: 2026-07-14

Purpose: protect production users while domain source-of-truth work continues. Until a decision below is marked `Approved`, engineering must not remove old RPCs, grants, Edge Function routes, Admin flows, or mobile compatibility paths that may still be called by existing Rider, Driver, web, cron, or Admin clients.

## Decision Status

| Decision | Current status | Required approver | Engineering rule until approved |
| --- | --- | --- | --- |
| Minimum Rider app version | Pending product decision | Product + CTO | Keep Rider compatibility paths and legacy response shapes. |
| Minimum Driver app version | Pending product decision | Product + CTO | Keep Driver compatibility paths and legacy response shapes. |
| Anonymous receipt support | Pending product/legal decision | Product + Legal + CTO | Do not remove anonymous receipt routes, grants, or public receipt lookup behavior. |
| Anonymous Web Push support | Pending product/security decision | Product + Security + CTO | Do not revoke related grants or Edge Function behavior without caller inventory. |
| Final invite timing | Pending operations decision | Dispatch owner + CTO | Do not change invite seed timing, expiry timing, or retry timing. |
| Final dispatch timing | Pending operations decision | Dispatch owner + CTO | Do not change matching windows, escalation timing, or assignment fallbacks. |
| Legacy Shift Handover retirement | Pending compatibility decision | Driver Experience owner + CTO | Keep legacy handover reads/writes and Admin visibility until retirement date is set. |
| Legacy Taxi Terug path retirement | Pending compatibility decision | Taxi Terug owner + CTO | Keep legacy Taxi Terug acceptance, expiry, and reporting paths. |
| Operational owner per domain | Pending ownership assignment | CTO | Keep `docs/domains/registry.yaml` as the working map; update it before handoff. |
| Rollback owner and escalation path | Pending operations decision | CTO + Support lead | Every risky release needs a named rollback owner and support escalation contact. |

## Caller Inventory Required Before Backend Removal

Before removing or revoking any compatibility-sensitive backend access, identify callers across:

- current Rider app;
- current Driver app;
- supported old Rider and Driver versions;
- Admin tools;
- public web flows;
- Edge Functions;
- cron jobs;
- support and reporting workflows;
- external payment, notification, analytics, and webhook integrations.

## Admin Contract Audit Checklist

Every Admin action must be checked against the same domain contracts as Rider and Driver:

- calls the canonical RPC, Edge Function, or backend service;
- uses the canonical status vocabulary;
- does not directly override protected ride, payment, readiness, or eligibility state;
- writes an audit event with actor, target, domain, action, and correlation ID;
- enforces role authorization before mutation;
- produces the same domain outcome as the Rider or Driver workflow.

Priority Admin audit areas:

- ride assignment;
- cancellation;
- driver eligibility;
- Platform Balance;
- reports;
- support;
- Taxi Terug;
- refunds;
- account restrictions.

## Supabase Hardening Rule

Remaining Supabase advisor warnings must be classified as one of:

- `Fix now`;
- `Accepted compatibility risk`;
- `Platform-owned issue`;
- `Product decision required`.

Do not blindly revoke function execution, remove grants, or alter `SECURITY DEFINER` behavior. `spatial_ref_sys` is tracked separately as a PostGIS extension/platform ownership issue.
