# M10C Closure — Billing Program Complete

**Date:** 2026-06-25  
**Status:** ✅ **Closed / Frozen**

---

## Delivered

- Accept-time billing enforcement via `fn_driver_accept_ride_invite`
- Per-market feature flag: `billing_enforcement` (NL launch: `true`)
- Configurable grace: `billing_grace_period_minutes` (NL launch: `0`)
- Dual audit: `billing.accept_blocked` + `dispatch.driver_rejected_billing`
- E2E lifecycle smoke: threshold → block → pay → immediate recovery
- Hotfix: accept sets `accepted` status (DB constraint alignment)

## Report

[PHASE-3-M10C-POST-MIGRATION-REPORT.md](./PHASE-3-M10C-POST-MIGRATION-REPORT.md)

---

**No further M10C changes** unless rollback or production incident.

**Billing Program:** ✅ Complete — bug fixes and business features only from here.

**Next program:** Presence · Dispatch resilience · Go retirement (one endpoint per deploy).
