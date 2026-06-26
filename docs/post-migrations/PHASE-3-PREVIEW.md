# Phase 3 Preview — Billing Gate

**Superseded by:** [PHASE-3-DESIGN.md](./PHASE-3-DESIGN.md)

CTO update (2026-05-20):

- **No stored `billing_status` column** — derived from ledger + market_config
- Split into **M10A / M10B / M10C** (eligibility → dispatch → accept)
- Add **`fn_driver_billing_summary`** for Flutter
- Add **`billing_audit_log`** for support timeline

See PHASE-3-DESIGN.md for full spec.
