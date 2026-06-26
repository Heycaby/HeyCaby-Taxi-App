-- Rollback Phase 2 Step 4 only (keeps billing_ledger + market_config from Steps 1–2).

BEGIN;

DROP TRIGGER IF EXISTS trg_billing_ledger_trip_completed ON public.ride_requests;
DROP FUNCTION IF EXISTS public.trg_billing_ledger_trip_completed();
DROP FUNCTION IF EXISTS public.fn_billing_accrue_ride_fee(uuid, uuid, text, uuid, uuid);

COMMIT;
