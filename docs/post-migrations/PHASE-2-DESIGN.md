# Phase 2 Design — Billing Ledger

**Status:** Steps 1–2 live on HEYCABY-TAXI · Step 4 trigger NOT approved · Lock Phase 3  
**Tracker:** M9 (schema), M10 (lock — deferred)

---

## Order (CTO-approved)

| Step | Deliverable | Prod? |
|------|-------------|-------|
| 1 | `billing_ledger` table + indexes + RLS + balance view | Review first |
| 2 | `market_config` + NL defaults + `fn_get_market_config` | Review first |
| 3 | Manual insert smoke + duplicate `ride_fee` test | Staging/prod after step 1–2 |
| 4 | `trip.completed` → ledger trigger | After five smokes pass |
| — | **`billing_status` (M10)** | **Phase 3 — before lock** |
| — | **Lock €60 (M11)** | **Phase 3 — after M10** |

---

## Database invariants

1. **One `ride_fee` per ride** — partial unique index `(ride_id, reason) WHERE reason = 'ride_fee'`.
2. **Ledger is append-only** — refunds use `reversal` row with negative `amount_cents`, never UPDATE.
3. **Rider fare money never in this table** — platform fees only.

---

## Reversal example

```
ride_fee     +100  (€1)
reversal     -100  (admin refund — metadata: original_ledger_id)
```

---

## Smoke tests required before Step 4 prod

- [x] Manual `ride_fee` insert → balance view correct
- [x] Duplicate `(ride_id, ride_fee)` → unique violation
- [x] `fn_get_market_config('platform_fee_cents', 'NL')` → 100
- [x] Concurrency duplicate insert → one row only
- [ ] Trip completed **once** → one ledger row (Step 4) — see [PHASE-2-STEP4-DESIGN.md](./PHASE-2-STEP4-DESIGN.md)
- [ ] Five CTO Step 4 smokes pass before prod

---

## ledger_sequence

Per-driver monotonic sequence assigned on INSERT via `fn_billing_ledger_assign_sequence`. Deterministic ordering when timestamps collide.

## Future (not V1)

- Hash chain per entry for tamper-evident audit
- Cached balance table only if SUM queries prove too slow

---

## Files

| File | Purpose |
|------|---------|
| `supabase/migrations/20260520150000_v1_phase2_billing_ledger_schema_only.sql` | Steps 1–2 SQL (not applied) |
| `scripts/sql/smoke_phase2_billing_ledger_manual.sql` | Step 3 manual smoke |

---

## Post-migration report

Will be written to `docs/post-migrations/PHASE-2-POST-MIGRATION-REPORT.md` after production apply.
