-- Phase 2 Step 4 — trip.completed → billing_ledger (REPO ONLY until explicit prod approval).
-- Fee amount from fn_get_market_config (never hardcoded).
-- Idempotent: partial unique index + ON CONFLICT DO NOTHING.
-- Does NOT implement billing lock (Phase 3).

-- ---------------------------------------------------------------------------
-- Billing entry types (canonical enum — extend rarely)
-- ride_fee | reversal | manual_adjustment | credit | promotion | waiver
-- (+ legacy: refund | settlement)
-- ---------------------------------------------------------------------------
ALTER TABLE public.billing_ledger
  DROP CONSTRAINT IF EXISTS billing_ledger_reason_check;

ALTER TABLE public.billing_ledger
  ADD CONSTRAINT billing_ledger_reason_check CHECK (reason IN (
    'ride_fee',
    'reversal',
    'manual_adjustment',
    'credit',
    'promotion',
    'waiver',
    'refund',
    'settlement'
  ));

COMMENT ON COLUMN public.billing_ledger.reason IS
  'Entry type: ride_fee, reversal, manual_adjustment, credit, promotion, waiver (+ refund, settlement). Append-only.';

-- ---------------------------------------------------------------------------
-- Accrue platform fee for a completed ride (idempotent)
-- ---------------------------------------------------------------------------
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
  IF p_ride_id IS NULL OR p_driver_id IS NULL THEN
    RETURN NULL;
  END IF;

  v_country := COALESCE(NULLIF(btrim(p_country_code), ''), 'NL');

  v_fee := public.fn_get_market_config(
    'platform_fee_cents', v_country, p_city_id, p_zone_id
  );
  IF v_fee IS NULL THEN
    RETURN NULL;
  END IF;

  v_fee_cents := (v_fee #>> '{}')::integer;
  IF v_fee_cents IS NULL OR v_fee_cents = 0 THEN
    RETURN NULL;
  END IF;

  v_currency := COALESCE(
    public.fn_get_market_config('currency', v_country, p_city_id, p_zone_id) #>> '{}',
    'EUR'
  );

  INSERT INTO public.billing_ledger (
    driver_id,
    amount_cents,
    reason,
    ride_id,
    country_code,
    currency,
    metadata,
    created_by
  )
  VALUES (
    p_driver_id,
    v_fee_cents,
    'ride_fee',
    p_ride_id,
    v_country,
    v_currency,
    jsonb_build_object('source', 'trip_completed_trigger'),
    auth.uid()
  )
  ON CONFLICT (ride_id, reason)
    WHERE reason = 'ride_fee' AND ride_id IS NOT NULL
  DO NOTHING
  RETURNING id INTO v_ledger_id;

  IF v_ledger_id IS NOT NULL THEN
    PERFORM public.fn_ride_audit_append(
      p_ride_id,
      'billing.ride_fee_created',
      p_driver_id,
      jsonb_build_object(
        'ledger_id', v_ledger_id,
        'amount_cents', v_fee_cents,
        'currency', v_currency,
        'country_code', v_country
      ),
      'system',
      'supabase_trigger',
      p_ride_id
    );
  END IF;

  RETURN v_ledger_id;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_billing_accrue_ride_fee(uuid, uuid, text, uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_billing_accrue_ride_fee(uuid, uuid, text, uuid, uuid)
  TO service_role;

-- ---------------------------------------------------------------------------
-- Trigger: status transition → completed | closed
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_billing_ledger_trip_completed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
    AND OLD.status IS DISTINCT FROM NEW.status
    AND NEW.status IN ('completed', 'closed')
  THEN
    PERFORM public.fn_billing_accrue_ride_fee(
      NEW.id,
      NEW.driver_id,
      NEW.country_code,
      NEW.pickup_city_id,
      NEW.zone_id
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_billing_ledger_trip_completed ON public.ride_requests;
CREATE TRIGGER trg_billing_ledger_trip_completed
  AFTER UPDATE OF status ON public.ride_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_billing_ledger_trip_completed();
