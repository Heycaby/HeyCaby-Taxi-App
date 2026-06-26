# Dispatch Health Dashboard — Engineering Design (v0)

**Audience:** Engineering / ops — not customer-facing  
**Status:** Design only · implement after M10C billing path complete

---

## Purpose

When something goes wrong, answer **where** immediately — not grep logs.

---

## Data sources (already exist or planned)

| Panel | Source |
|-------|--------|
| Avg dispatch time | `ride_audit_log` → `dispatch.batch_seeded` → `skip_metrics.dispatch_duration_ms` |
| Skip breakdown | `skip_metrics` on latest batches |
| Locked drivers | `fn_driver_can_accept_rides` aggregate or `billing_audit_log` |
| Outstanding fees | `SUM(billing_ledger)` |
| Drivers online | `drivers.status = 'available'` + fresh `driver_locations` |
| Pending rides | `ride_requests.status = 'pending'` |

---

## v0 implementation options

1. **SQL view** `v_dispatch_health_snapshot` — admin read-only
2. **RPC** `fn_dispatch_health_snapshot()` — returns JSON for internal dashboard
3. **Metabase / Supabase dashboard** — query views directly

---

## Future metrics (post waves)

- Wave 1/2/3 success rate
- Offer success rate = accepted / sent
- P95 dispatch duration

---

## Offer success rate (future KPI)

```text
Offer Success Rate = Accepted Offers / Sent Offers
```

Per city · hour · vehicle type · driver.

---

*Implement when M4–M7 dispatch waves live; v0 can ship with M10B metrics only.*
