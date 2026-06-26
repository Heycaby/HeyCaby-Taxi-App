-- Rollback Phase 3 M10A (keeps M10B/C changes if applied — run in reverse order).

BEGIN;

-- Restore Step 4 accrue fn without limit_reached (from 20260520160000)
CREATE OR REPLACE FUNCTION public.fn_billing_accrue_ride_fee(
  p_ride_id uuid,
  p_driver_id uuid,
  p_country_code text DEFAULT 'NL',
  p_city_id uuid DEFAULT NULL,
  p_zone_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_country text;
  v_fee jsonb;
  v_fee_cents integer;
  v_currency text;
  v_ledger_id uuid;
BEGIN
  IF p_ride_id IS NULL OR p_driver_id IS NULL THEN RETURN NULL; END IF;
  v_country := COALESCE(NULLIF(btrim(p_country_code), ''), 'NL');
  v_fee := public.fn_get_market_config('platform_fee_cents', v_country, p_city_id, p_zone_id);
  IF v_fee IS NULL THEN RETURN NULL; END IF;
  v_fee_cents := (v_fee #>> '{}')::integer;
  IF v_fee_cents IS NULL OR v_fee_cents = 0 THEN RETURN NULL; END IF;
  v_currency := COALESCE(
    public.fn_get_market_config('currency', v_country, p_city_id, p_zone_id) #>> '{}', 'EUR');
  INSERT INTO public.billing_ledger (
    driver_id, amount_cents, reason, ride_id, country_code, currency, metadata, created_by
  ) VALUES (
    p_driver_id, v_fee_cents, 'ride_fee', p_ride_id, v_country, v_currency,
    jsonb_build_object('source', 'trip_completed_trigger'), auth.uid()
  )
  ON CONFLICT (ride_id, reason) WHERE reason = 'ride_fee' AND ride_id IS NOT NULL DO NOTHING
  RETURNING id INTO v_ledger_id;
  IF v_ledger_id IS NOT NULL THEN
    PERFORM public.fn_ride_audit_append(
      p_ride_id, 'billing.ride_fee_created', p_driver_id,
      jsonb_build_object('ledger_id', v_ledger_id, 'amount_cents', v_fee_cents,
        'currency', v_currency, 'country_code', v_country),
      'system', 'supabase_trigger', p_ride_id);
  END IF;
  RETURN v_ledger_id;
END;
$$;

DROP FUNCTION IF EXISTS public.fn_driver_platform_health(uuid);
DROP FUNCTION IF EXISTS public.fn_driver_billing_summary(uuid);
DROP FUNCTION IF EXISTS public.fn_driver_can_accept_rides(uuid);
DROP FUNCTION IF EXISTS public.fn_billing_resolve_driver_market(uuid, text, uuid, uuid);
DROP FUNCTION IF EXISTS public.fn_billing_derive_status(bigint, bigint);
DROP FUNCTION IF EXISTS public.fn_billing_driver_outstanding_cents(uuid, text);
DROP FUNCTION IF EXISTS public.fn_billing_audit_append(uuid, text, uuid, jsonb, uuid);
DROP TABLE IF EXISTS public.billing_audit_log;

COMMIT;
