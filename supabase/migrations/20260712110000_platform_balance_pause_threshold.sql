-- Platform Balance pause should only block new rides once the weekly fee (€50)
-- remains unpaid after grace — not after legacy per-ride €1 accruals.

UPDATE public.market_config
SET config_value = '0'::jsonb,
    active = true,
    updated_at = timezone('utc', now())
WHERE scope = 'country'
  AND country_code = 'NL'
  AND config_key = 'platform_fee_cents';

INSERT INTO public.market_config (scope, country_code, config_key, config_value, active)
SELECT 'country', 'NL', 'platform_fee_cents', '0'::jsonb, true
WHERE NOT EXISTS (
  SELECT 1
  FROM public.market_config mc
  WHERE mc.scope = 'country'
    AND mc.country_code = 'NL'
    AND mc.config_key = 'platform_fee_cents'
    AND mc.active = true
);

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
  v_weekly_cents integer;
BEGIN
  IF p_ride_id IS NULL OR p_driver_id IS NULL THEN
    RETURN NULL;
  END IF;

  v_country := COALESCE(NULLIF(btrim(p_country_code), ''), 'NL');

  v_weekly_cents := COALESCE(
    (
      public.fn_get_market_config(
        'weekly_platform_balance_cents', v_country, p_city_id, p_zone_id
      ) #>> '{}'
    )::integer,
    5000
  );

  -- Weekly Platform Balance bills via platform_cycle_fee, not per completed ride.
  IF v_weekly_cents > 0 THEN
    RETURN NULL;
  END IF;

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

CREATE OR REPLACE FUNCTION public.fn_driver_can_accept_rides(
  p_driver_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_market record;
  v_cycle_id uuid;
  v_cycle_start_at timestamptz;
  v_due_at timestamptz;
  v_grace_until_at timestamptz;
  v_cycle_currency text;
  v_cycle_country_code text;
  v_outstanding bigint;
  v_pause_threshold bigint;
  v_status text;
  v_allowed boolean;
  v_reason text;
  v_enforcement boolean;
  v_in_grace boolean := false;
  v_balance_state text;
  v_now timestamptz := timezone('utc', now());
BEGIN
  v_driver_id := p_driver_id;
  IF v_driver_id IS NULL THEN
    SELECT d.id INTO v_driver_id
    FROM public.drivers d
    WHERE d.user_id = auth.uid()
    LIMIT 1;
  END IF;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', 'not_a_driver',
      'status', 'UNKNOWN'
    );
  END IF;

  SELECT * INTO v_market
  FROM public.fn_billing_resolve_driver_market(v_driver_id) m
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', 'driver_not_found',
      'status', 'UNKNOWN'
    );
  END IF;

  v_pause_threshold := GREATEST(
    COALESCE(
      (
        public.fn_get_market_config(
          'weekly_platform_balance_cents',
          v_market.country_code,
          v_market.city_id,
          v_market.zone_id
        ) #>> '{}'
      )::bigint,
      5000
    ),
    1
  );

  SELECT
    c.id,
    c.cycle_start_at,
    c.cycle_end_at,
    c.grace_until_at,
    c.currency,
    c.country_code
  INTO
    v_cycle_id,
    v_cycle_start_at,
    v_due_at,
    v_grace_until_at,
    v_cycle_currency,
    v_cycle_country_code
  FROM public.driver_platform_balance_cycles c
  WHERE c.driver_id = v_driver_id
    AND c.status = 'open'
  ORDER BY c.cycle_end_at ASC
  LIMIT 1;

  v_outstanding := public.fn_billing_driver_outstanding_cents(
    v_driver_id,
    v_market.country_code
  );
  v_enforcement := COALESCE(
    (
      public.fn_get_market_config(
        'billing_enforcement',
        v_market.country_code,
        v_market.city_id,
        v_market.zone_id
      ) #>> '{}'
    )::boolean,
    true
  );

  IF v_outstanding <= 0 THEN
    v_status := 'GOOD';
    v_balance_state := 'current';
    v_allowed := true;
    v_reason := NULL;
  ELSIF v_cycle_id IS NOT NULL AND v_grace_until_at >= v_now THEN
    v_status := 'GRACE';
    v_balance_state := 'due';
    v_allowed := true;
    v_reason := NULL;
    v_in_grace := true;
  ELSIF v_outstanding >= v_pause_threshold THEN
    v_status := 'LOCKED';
    v_balance_state := 'paused';
    v_allowed := NOT v_enforcement;
    v_reason := CASE
      WHEN v_allowed THEN NULL
      ELSE 'New ride requests are temporarily paused until your platform balance is settled.'
    END;
  ELSE
    v_status := 'WARNING';
    v_balance_state := 'due';
    v_allowed := true;
    v_reason := NULL;
  END IF;

  RETURN jsonb_build_object(
    'allowed', v_allowed,
    'reason', v_reason,
    'status', v_status,
    'balance_state', v_balance_state,
    'outstanding_cents', GREATEST(v_outstanding, 0),
    'limit_cents', v_pause_threshold,
    'remaining_cents', GREATEST(v_pause_threshold - v_outstanding, 0),
    'currency', COALESCE(v_cycle_currency, v_market.currency, 'EUR'),
    'country_code', COALESCE(v_cycle_country_code, v_market.country_code, 'NL'),
    'billing_enforcement', v_enforcement,
    'in_grace_period', v_in_grace,
    'due_at', v_due_at,
    'grace_until_at', v_grace_until_at,
    'cycle_id', v_cycle_id,
    'cycle_started_at', v_cycle_start_at,
    'cycle_ends_at', v_due_at,
    'ride_requests_paused', NOT v_allowed
  );
END;
$$;

-- Clear erroneous sub-€50 per-ride accruals created before weekly-only billing.
INSERT INTO public.billing_ledger (
  driver_id,
  amount_cents,
  reason,
  country_code,
  currency,
  metadata,
  created_by
)
SELECT
  bl.driver_id,
  -bl.amount_cents,
  'waiver',
  bl.country_code,
  bl.currency,
  jsonb_build_object(
    'source', 'platform_balance_pause_threshold_fix',
    'reversed_ledger_id', bl.id,
    'reversed_reason', bl.reason
  ),
  NULL
FROM public.billing_ledger bl
WHERE bl.reason = 'ride_fee'
  AND bl.amount_cents > 0
  AND bl.amount_cents < 5000
  AND NOT EXISTS (
    SELECT 1
    FROM public.billing_ledger rev
    WHERE rev.driver_id = bl.driver_id
      AND rev.reason = 'waiver'
      AND rev.metadata->>'reversed_ledger_id' = bl.id::text
  );
