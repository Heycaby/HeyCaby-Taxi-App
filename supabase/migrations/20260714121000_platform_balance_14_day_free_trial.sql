-- 14-day launch free trial: drivers stay eligible for new rides and weekly fees
-- do not accrue until the trial ends. Existing outstanding balances are cleared once.

INSERT INTO public.market_config (scope, country_code, config_key, config_value, active)
SELECT
  'country',
  'NL',
  'platform_balance_free_trial_days',
  '14'::jsonb,
  true
WHERE NOT EXISTS (
  SELECT 1
  FROM public.market_config mc
  WHERE mc.scope = 'country'
    AND mc.country_code = 'NL'
    AND mc.config_key = 'platform_balance_free_trial_days'
    AND mc.active = true
);

INSERT INTO public.market_config (scope, country_code, config_key, config_value, active)
SELECT
  'country',
  'NL',
  'platform_balance_free_trial_started_at',
  to_jsonb(timezone('utc', now())::text),
  true
WHERE NOT EXISTS (
  SELECT 1
  FROM public.market_config mc
  WHERE mc.scope = 'country'
    AND mc.country_code = 'NL'
    AND mc.config_key = 'platform_balance_free_trial_started_at'
    AND mc.active = true
);

CREATE OR REPLACE FUNCTION public.fn_driver_platform_balance_free_trial_ends_at(
  p_country_code text DEFAULT 'NL',
  p_now timestamptz DEFAULT timezone('utc', now())
)
RETURNS timestamptz
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_country text;
  v_days integer;
  v_started_raw text;
  v_started_at timestamptz;
BEGIN
  v_country := COALESCE(NULLIF(btrim(p_country_code), ''), 'NL');
  v_days := COALESCE(
    (
      public.fn_get_market_config(
        'platform_balance_free_trial_days',
        v_country,
        NULL,
        NULL
      ) #>> '{}'
    )::integer,
    0
  );

  IF v_days <= 0 THEN
    RETURN p_now - interval '1 second';
  END IF;

  v_started_raw := public.fn_get_market_config(
    'platform_balance_free_trial_started_at',
    v_country,
    NULL,
    NULL
  ) #>> '{}';

  IF v_started_raw IS NULL OR btrim(v_started_raw) = '' THEN
    RETURN p_now - interval '1 second';
  END IF;

  BEGIN
    v_started_at := v_started_raw::timestamptz;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN p_now - interval '1 second';
  END;

  RETURN v_started_at + make_interval(days => GREATEST(v_days, 0));
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_platform_balance_in_free_trial(
  p_country_code text DEFAULT 'NL',
  p_now timestamptz DEFAULT timezone('utc', now())
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p_now < public.fn_driver_platform_balance_free_trial_ends_at(p_country_code, p_now);
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_platform_balance_ensure_weekly(
  p_driver_id uuid,
  p_now timestamptz DEFAULT timezone('utc', now())
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver record;
  v_country text;
  v_currency text;
  v_amount integer;
  v_grace_days integer;
  v_anchor timestamptz;
  v_trial_ends_at timestamptz;
  v_cycle_start timestamptz;
  v_cycle_end timestamptz;
  v_cycle_id uuid;
  v_ledger_id uuid;
  v_created int := 0;
  v_i int := 0;
BEGIN
  IF p_driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_driver_id');
  END IF;

  SELECT d.id, d.country_code
  INTO v_driver
  FROM public.drivers d
  WHERE d.id = p_driver_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'driver_not_found');
  END IF;

  v_country := COALESCE(NULLIF(btrim(v_driver.country_code), ''), 'NL');
  v_trial_ends_at := public.fn_driver_platform_balance_free_trial_ends_at(v_country, p_now);

  IF public.fn_driver_platform_balance_in_free_trial(v_country, p_now) THEN
    INSERT INTO public.driver_platform_balance_accounts (driver_id, balance_started_at)
    VALUES (p_driver_id, v_trial_ends_at)
    ON CONFLICT (driver_id) DO UPDATE
    SET balance_started_at = GREATEST(
          public.driver_platform_balance_accounts.balance_started_at,
          EXCLUDED.balance_started_at
        ),
        updated_at = timezone('utc', now());

    RETURN jsonb_build_object(
      'ok', true,
      'created_cycles', 0,
      'free_trial', true,
      'free_trial_ends_at', v_trial_ends_at
    );
  END IF;

  INSERT INTO public.driver_platform_balance_accounts (driver_id, balance_started_at)
  VALUES (p_driver_id, p_now)
  ON CONFLICT (driver_id) DO NOTHING;

  SELECT a.balance_started_at
  INTO v_anchor
  FROM public.driver_platform_balance_accounts a
  WHERE a.driver_id = p_driver_id;

  v_currency := COALESCE(
    public.fn_get_market_config('currency', v_country, NULL, NULL) #>> '{}',
    'EUR'
  );
  v_amount := COALESCE(
    (public.fn_get_market_config('weekly_platform_balance_cents', v_country, NULL, NULL) #>> '{}')::integer,
    5000
  );
  v_grace_days := COALESCE(
    (public.fn_get_market_config('platform_balance_grace_days', v_country, NULL, NULL) #>> '{}')::integer,
    3
  );

  v_cycle_start := COALESCE(v_anchor, p_now);
  v_cycle_end := v_cycle_start + interval '7 days';

  WHILE v_cycle_end <= p_now AND v_i < 104 LOOP
    INSERT INTO public.driver_platform_balance_cycles (
      driver_id,
      cycle_start_at,
      cycle_end_at,
      grace_until_at,
      amount_cents,
      currency,
      country_code,
      metadata
    )
    VALUES (
      p_driver_id,
      v_cycle_start,
      v_cycle_end,
      v_cycle_end + make_interval(days => GREATEST(v_grace_days, 0)),
      v_amount,
      v_currency,
      v_country,
      jsonb_build_object('source', 'weekly_platform_balance', 'cycle_days', 7)
    )
    ON CONFLICT (driver_id, cycle_start_at) DO NOTHING
    RETURNING id INTO v_cycle_id;

    IF v_cycle_id IS NOT NULL THEN
      INSERT INTO public.billing_ledger (
        driver_id,
        amount_cents,
        reason,
        country_code,
        currency,
        metadata
      )
      VALUES (
        p_driver_id,
        v_amount,
        'platform_cycle_fee',
        v_country,
        v_currency,
        jsonb_build_object(
          'source', 'weekly_platform_balance',
          'cycle_id', v_cycle_id,
          'cycle_start_at', v_cycle_start,
          'cycle_end_at', v_cycle_end,
          'grace_until_at', v_cycle_end + make_interval(days => GREATEST(v_grace_days, 0))
        )
      )
      RETURNING id INTO v_ledger_id;

      UPDATE public.driver_platform_balance_cycles c
      SET ledger_entry_id = v_ledger_id,
          updated_at = timezone('utc', now())
      WHERE c.id = v_cycle_id;

      PERFORM public.fn_billing_audit_append(
        p_driver_id,
        'billing.platform_balance_created',
        NULL,
        jsonb_build_object(
          'cycle_id', v_cycle_id,
          'ledger_id', v_ledger_id,
          'amount_cents', v_amount,
          'cycle_start_at', v_cycle_start,
          'cycle_end_at', v_cycle_end,
          'grace_until_at', v_cycle_end + make_interval(days => GREATEST(v_grace_days, 0))
        )
      );

      v_created := v_created + 1;
    END IF;

    v_cycle_start := v_cycle_end;
    v_cycle_end := v_cycle_start + interval '7 days';
    v_cycle_id := NULL;
    v_ledger_id := NULL;
    v_i := v_i + 1;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'created_cycles', v_created);
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
  v_in_free_trial boolean := false;
  v_balance_state text;
  v_trial_ends_at timestamptz;
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

  v_trial_ends_at := public.fn_driver_platform_balance_free_trial_ends_at(
    v_market.country_code,
    v_now
  );
  v_in_free_trial := public.fn_driver_platform_balance_in_free_trial(
    v_market.country_code,
    v_now
  );

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

  IF v_in_free_trial THEN
    v_status := 'TRIAL';
    v_balance_state := 'current';
    v_allowed := true;
    v_reason := NULL;
  ELSIF v_outstanding <= 0 THEN
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
    'in_free_trial', v_in_free_trial,
    'free_trial_ends_at', CASE WHEN v_in_free_trial THEN v_trial_ends_at ELSE NULL END,
    'due_at', v_due_at,
    'grace_until_at', v_grace_until_at,
    'cycle_id', v_cycle_id,
    'cycle_started_at', v_cycle_start_at,
    'cycle_ends_at', v_due_at,
    'ride_requests_paused', NOT v_allowed
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_runtime_billing(p_driver_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_billing jsonb;
  v_summary jsonb;
  v_allowed boolean;
BEGIN
  v_billing := public.fn_driver_can_accept_rides(p_driver_id);
  v_summary := public.fn_driver_billing_summary(p_driver_id);
  v_allowed := COALESCE((v_billing->>'allowed')::boolean, false);

  RETURN jsonb_build_object(
    'status', COALESCE(v_summary->>'status', v_billing->>'status', 'UNKNOWN'),
    'balance_state', COALESCE(v_billing->>'balance_state', 'current'),
    'outstanding', COALESCE((v_summary->>'outstanding')::bigint, 0),
    'outstanding_cents', COALESCE((v_billing->>'outstanding_cents')::bigint, 0),
    'limit', COALESCE((v_summary->>'limit')::bigint, 0),
    'remaining', COALESCE((v_summary->>'remaining')::bigint, 0),
    'currency', COALESCE(v_summary->>'currency', v_billing->>'currency', 'EUR'),
    'can_accept_rides', v_allowed,
    'ride_requests_paused', NOT v_allowed,
    'in_grace_period', COALESCE((v_billing->>'in_grace_period')::boolean, false),
    'in_free_trial', COALESCE((v_billing->>'in_free_trial')::boolean, false),
    'free_trial_ends_at', v_billing->>'free_trial_ends_at',
    'blocked_reason', v_billing->>'reason',
    'eligibility_reason', CASE
      WHEN v_allowed THEN NULL
      ELSE 'platform_balance_overdue'
    END,
    'allowed', v_allowed
  );
END;
$$;

DO $$
DECLARE
  v_trial_ends_at timestamptz;
BEGIN
  v_trial_ends_at := public.fn_driver_platform_balance_free_trial_ends_at('NL', timezone('utc', now()));

  INSERT INTO public.driver_platform_balance_accounts (driver_id, balance_started_at)
  SELECT d.id, v_trial_ends_at
  FROM public.drivers d
  ON CONFLICT (driver_id) DO UPDATE
  SET balance_started_at = GREATEST(
        public.driver_platform_balance_accounts.balance_started_at,
        EXCLUDED.balance_started_at
      ),
      updated_at = timezone('utc', now());

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
    agg.driver_id,
    -agg.outstanding_cents,
    'promotion',
    agg.country_code,
    agg.currency,
    jsonb_build_object(
      'source', 'platform_balance_14_day_free_trial',
      'free_trial_ends_at', v_trial_ends_at
    ),
    NULL
  FROM (
    SELECT
      bl.driver_id,
      COALESCE(NULLIF(btrim(MAX(d.country_code)), ''), 'NL') AS country_code,
      COALESCE(NULLIF(btrim(MAX(bl.currency)), ''), 'EUR') AS currency,
      SUM(bl.amount_cents)::bigint AS outstanding_cents
    FROM public.billing_ledger bl
    JOIN public.drivers d ON d.id = bl.driver_id
    GROUP BY bl.driver_id
    HAVING SUM(bl.amount_cents) > 0
  ) agg
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.billing_ledger promo
    WHERE promo.driver_id = agg.driver_id
      AND promo.reason = 'promotion'
      AND promo.metadata->>'source' = 'platform_balance_14_day_free_trial'
  );

  UPDATE public.driver_platform_balance_cycles c
  SET status = 'settled',
      updated_at = timezone('utc', now())
  WHERE c.status = 'open'
    AND public.fn_billing_driver_outstanding_cents(c.driver_id, c.country_code) <= 0;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_platform_balance_free_trial_ends_at(text, timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_platform_balance_free_trial_ends_at(text, timestamptz)
  TO service_role;

REVOKE ALL ON FUNCTION public.fn_driver_platform_balance_in_free_trial(text, timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_platform_balance_in_free_trial(text, timestamptz)
  TO service_role;

REVOKE ALL ON FUNCTION public.fn_driver_platform_balance_ensure_weekly(uuid, timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_platform_balance_ensure_weekly(uuid, timestamptz)
  TO service_role;

REVOKE ALL ON FUNCTION public.fn_driver_can_accept_rides(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_can_accept_rides(uuid)
  TO service_role;

REVOKE ALL ON FUNCTION public.fn_driver_runtime_billing(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_runtime_billing(uuid)
  TO service_role;

COMMENT ON FUNCTION public.fn_driver_platform_balance_in_free_trial(text, timestamptz) IS
  'Launch free trial window from market_config. While active, ride eligibility is not blocked by Platform Balance.';
