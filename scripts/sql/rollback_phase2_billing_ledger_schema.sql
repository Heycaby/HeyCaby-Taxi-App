-- Rollback Phase 2 Steps 1–2 (billing_ledger + market_config).
-- Run only if Phase 2 schema must be removed before Step 4 trigger exists.
-- Does NOT touch ride_audit_log (Phase 1).

BEGIN;

DROP TRIGGER IF EXISTS trg_billing_ledger_assign_sequence ON public.billing_ledger;
DROP FUNCTION IF EXISTS public.fn_billing_ledger_assign_sequence();
DROP VIEW IF EXISTS public.driver_platform_balance;
DROP TABLE IF EXISTS public.billing_ledger;
DROP FUNCTION IF EXISTS public.fn_get_market_config(text, text, uuid, uuid);
DROP TABLE IF EXISTS public.market_config;

COMMIT;
