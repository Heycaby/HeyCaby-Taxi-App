-- Weekly-only Platform Balance model.
-- Driver-facing language: Platform Balance / Outstanding / Settle Balance.
-- Backend remains source of truth for weekly cycle, grace period, balance, and ride eligibility.

ALTER TABLE public.billing_ledger
  DROP CONSTRAINT IF EXISTS billing_ledger_reason_check;

ALTER TABLE public.billing_ledger
  ADD CONSTRAINT billing_ledger_reason_check CHECK (reason IN (
    'ride_fee',
    'platform_cycle_fee',
    'reversal',
    'manual_adjustment',
    'credit',
    'promotion',
    'waiver',
    'refund',
    'settlement'
  ));

COMMENT ON COLUMN public.billing_ledger.reason IS
  'Entry type: platform_cycle_fee, settlement, ride_fee, reversal, manual_adjustment, credit, promotion, waiver, refund. Append-only.';

CREATE TABLE IF NOT EXISTS public.driver_platform_balance_cycles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  cycle_start_at timestamptz NOT NULL,
  cycle_end_at timestamptz NOT NULL,
  grace_until_at timestamptz NOT NULL,
  amount_cents integer NOT NULL DEFAULT 5000 CHECK (amount_cents > 0),
  currency text NOT NULL DEFAULT 'EUR',
  country_code text NOT NULL DEFAULT 'NL',
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'settled', 'void')),
  ledger_entry_id uuid REFERENCES public.billing_ledger(id) ON DELETE SET NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT driver_platform_balance_cycles_window CHECK (cycle_end_at > cycle_start_at),
  CONSTRAINT driver_platform_balance_cycles_grace CHECK (grace_until_at >= cycle_end_at),
  CONSTRAINT driver_platform_balance_cycles_driver_start UNIQUE (driver_id, cycle_start_at)
);

CREATE INDEX IF NOT EXISTS idx_driver_platform_balance_cycles_driver_end
  ON public.driver_platform_balance_cycles (driver_id, cycle_end_at DESC);

CREATE INDEX IF NOT EXISTS idx_driver_platform_balance_cycles_open_grace
  ON public.driver_platform_balance_cycles (status, grace_until_at)
  WHERE status = 'open';

ALTER TABLE public.driver_platform_balance_cycles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS driver_platform_balance_cycles_driver_select ON public.driver_platform_balance_cycles;
CREATE POLICY driver_platform_balance_cycles_driver_select
  ON public.driver_platform_balance_cycles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.drivers d
      WHERE d.id = driver_platform_balance_cycles.driver_id
        AND d.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS driver_platform_balance_cycles_admin_select ON public.driver_platform_balance_cycles;
CREATE POLICY driver_platform_balance_cycles_admin_select
  ON public.driver_platform_balance_cycles
  FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid()));

COMMENT ON TABLE public.driver_platform_balance_cycles IS
  'Weekly platform balance cycles. UI must present this as Platform Balance, not subscription/membership.';

CREATE OR REPLACE FUNCTION public.trg_driver_platform_balance_cycles_settled()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.reason = 'settlement'
     AND public.fn_billing_driver_outstanding_cents(NEW.driver_id, NEW.country_code) <= 0
  THEN
    UPDATE public.driver_platform_balance_cycles c
    SET status = 'settled',
        updated_at = timezone('utc', now())
    WHERE c.driver_id = NEW.driver_id
      AND c.status = 'open';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_driver_platform_balance_cycles_settled
  ON public.billing_ledger;
CREATE TRIGGER trg_driver_platform_balance_cycles_settled
  AFTER INSERT ON public.billing_ledger
  FOR EACH ROW
  WHEN (NEW.reason = 'settlement')
  EXECUTE FUNCTION public.trg_driver_platform_balance_cycles_settled();

INSERT INTO public.market_config (scope, country_code, config_key, config_value)
SELECT 'country', 'NL', 'weekly_platform_balance_cents', '5000'::jsonb
WHERE NOT EXISTS (
  SELECT 1 FROM public.market_config
  WHERE scope = 'country' AND country_code = 'NL'
    AND config_key = 'weekly_platform_balance_cents' AND active = true
);

INSERT INTO public.market_config (scope, country_code, config_key, config_value)
SELECT 'country', 'NL', 'platform_balance_grace_days', '3'::jsonb
WHERE NOT EXISTS (
  SELECT 1 FROM public.market_config
  WHERE scope = 'country' AND country_code = 'NL'
    AND config_key = 'platform_balance_grace_days' AND active = true
);

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

  SELECT d.id, d.country_code, d.created_at
  INTO v_driver
  FROM public.drivers d
  WHERE d.id = p_driver_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'driver_not_found');
  END IF;

  v_country := COALESCE(NULLIF(btrim(v_driver.country_code), ''), 'NL');
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

  v_anchor := COALESCE(v_driver.created_at, p_now);
  v_cycle_start := v_anchor;
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

REVOKE ALL ON FUNCTION public.fn_driver_platform_balance_ensure_weekly(uuid, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_platform_balance_ensure_weekly(uuid, timestamptz) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.fn_driver_platform_balance_latest_open(p_driver_id uuid)
RETURNS TABLE (
  cycle_id uuid,
  due_at timestamptz,
  grace_until_at timestamptz,
  amount_cents integer,
  currency text,
  country_code text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    c.id,
    c.cycle_end_at,
    c.grace_until_at,
    c.amount_cents,
    c.currency,
    c.country_code
  FROM public.driver_platform_balance_cycles c
  WHERE c.driver_id = p_driver_id
    AND c.status = 'open'
  ORDER BY c.cycle_end_at ASC
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_platform_balance_latest_open(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_platform_balance_latest_open(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.fn_driver_can_accept_rides(
  p_driver_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_market record;
  v_cycle_id uuid;
  v_due_at timestamptz;
  v_grace_until_at timestamptz;
  v_cycle_currency text;
  v_cycle_country_code text;
  v_outstanding bigint;
  v_status text;
  v_allowed boolean;
  v_reason text;
  v_enforcement boolean;
  v_in_grace boolean := false;
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
    RETURN jsonb_build_object('allowed', false, 'reason', 'not_a_driver', 'status', 'UNKNOWN');
  END IF;

  PERFORM public.fn_driver_platform_balance_ensure_weekly(v_driver_id, v_now);

  SELECT * INTO v_market
  FROM public.fn_billing_resolve_driver_market(v_driver_id) m
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'driver_not_found', 'status', 'UNKNOWN');
  END IF;

  SELECT
    c.cycle_id,
    c.due_at,
    c.grace_until_at,
    c.currency,
    c.country_code
  INTO
    v_cycle_id,
    v_due_at,
    v_grace_until_at,
    v_cycle_currency,
    v_cycle_country_code
  FROM public.fn_driver_platform_balance_latest_open(v_driver_id)
    AS c(cycle_id, due_at, grace_until_at, amount_cents, currency, country_code)
  LIMIT 1;

  v_outstanding := public.fn_billing_driver_outstanding_cents(v_driver_id, v_market.country_code);
  v_enforcement := COALESCE(
    (public.fn_get_market_config('billing_enforcement', v_market.country_code, v_market.city_id, v_market.zone_id) #>> '{}')::boolean,
    true
  );

  IF v_outstanding <= 0 THEN
    v_status := 'GOOD';
    v_allowed := true;
    v_reason := NULL;
  ELSIF v_cycle_id IS NOT NULL AND v_grace_until_at >= v_now THEN
    v_status := 'GRACE';
    v_allowed := true;
    v_reason := NULL;
    v_in_grace := true;
  ELSE
    v_status := 'LOCKED';
    v_allowed := NOT v_enforcement;
    v_reason := CASE
      WHEN v_allowed THEN NULL
      ELSE 'New ride requests are temporarily paused until your platform balance is settled.'
    END;
  END IF;

  RETURN jsonb_build_object(
    'allowed', v_allowed,
    'reason', v_reason,
    'status', v_status,
    'balance_state', CASE
      WHEN v_outstanding <= 0 THEN 'current'
      WHEN v_status = 'GRACE' THEN 'due'
      ELSE 'paused'
    END,
    'outstanding_cents', GREATEST(v_outstanding, 0),
    'limit_cents', 0,
    'remaining_cents', 0,
    'currency', COALESCE(v_cycle_currency, v_market.currency, 'EUR'),
    'country_code', COALESCE(v_cycle_country_code, v_market.country_code, 'NL'),
    'billing_enforcement', v_enforcement,
    'in_grace_period', v_in_grace,
    'due_at', v_due_at,
    'grace_until_at', v_grace_until_at,
    'cycle_id', v_cycle_id,
    'ride_requests_paused', NOT v_allowed
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_billing_summary(
  p_driver_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_check jsonb;
  v_driver_id uuid;
  v_amount integer;
BEGIN
  v_driver_id := COALESCE(
    p_driver_id,
    (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid() LIMIT 1)
  );

  v_check := public.fn_driver_can_accept_rides(v_driver_id);
  v_amount := COALESCE(
    (public.fn_get_market_config('weekly_platform_balance_cents', COALESCE(v_check->>'country_code', 'NL'), NULL, NULL) #>> '{}')::integer,
    5000
  );

  RETURN jsonb_build_object(
    'outstanding', COALESCE((v_check->>'outstanding_cents')::bigint, 0),
    'limit', 0,
    'remaining', 0,
    'currency', COALESCE(v_check->>'currency', 'EUR'),
    'status', COALESCE(v_check->>'status', 'GOOD'),
    'balance_state', COALESCE(v_check->>'balance_state', 'current'),
    'allowed', COALESCE((v_check->>'allowed')::boolean, true),
    'weekly_platform_balance_cents', v_amount,
    'platform_fee_cents', v_amount,
    'country_code', COALESCE(v_check->>'country_code', 'NL'),
    'due_at', v_check->>'due_at',
    'grace_until_at', v_check->>'grace_until_at',
    'cycle_id', v_check->>'cycle_id',
    'ride_requests_paused', COALESCE((v_check->>'ride_requests_paused')::boolean, false)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_billing_status()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_summary jsonb;
  v_status text;
  v_allowed boolean;
  v_outstanding bigint;
  v_amount bigint;
  v_currency text;
  v_balance_state text;
BEGIN
  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  v_summary := public.fn_driver_billing_summary(v_driver_id);
  v_status := COALESCE(v_summary->>'status', 'GOOD');
  v_balance_state := COALESCE(v_summary->>'balance_state', 'current');
  v_allowed := COALESCE((v_summary->>'allowed')::boolean, true);
  v_outstanding := COALESCE((v_summary->>'outstanding')::bigint, 0);
  v_amount := COALESCE((v_summary->>'weekly_platform_balance_cents')::bigint, 5000);
  v_currency := COALESCE(NULLIF(btrim(v_summary->>'currency'), ''), 'EUR');

  RETURN jsonb_build_object(
    'ok', true,
    'billing_model', 'platform_balance_v1',
    'payment_required', NOT v_allowed,
    'allowed', v_allowed,
    'status', v_status,
    'balance_state', v_balance_state,
    'outstanding_cents', v_outstanding,
    'limit_cents', 0,
    'remaining_cents', 0,
    'platform_fee_cents', v_amount,
    'weekly_platform_balance_cents', v_amount,
    'weekly_fee_cents', v_amount,
    'currency', v_currency,
    'country_code', v_summary->>'country_code',
    'due_at', v_summary->>'due_at',
    'grace_until_at', v_summary->>'grace_until_at',
    'cycle_id', v_summary->>'cycle_id',
    'ride_requests_paused', COALESCE((v_summary->>'ride_requests_paused')::boolean, false),
    'checkout_amount_cents', CASE WHEN v_outstanding > 0 THEN v_outstanding ELSE NULL END,
    'billing_status_label', CASE v_balance_state
      WHEN 'paused' THEN 'ride_requests_paused'
      WHEN 'due' THEN 'balance_due'
      ELSE 'current'
    END,
    'show_subscription_controls', false,
    'allow_one_off_checkout', v_outstanding > 0,
    'billing_provider', 'platform_balance',
    'can_settle_outstanding', v_outstanding > 0
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_can_accept_rides(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_billing_summary(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_billing_status() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.fn_driver_can_accept_rides(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_billing_summary(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_billing_status() TO authenticated;

COMMENT ON FUNCTION public.fn_driver_billing_status() IS
  'Weekly-only Platform Balance status. Flutter must not present subscription/membership/plan language.';

CREATE OR REPLACE FUNCTION public.fn_driver_billing_ledger_history(p_limit int DEFAULT 50)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_rows jsonb;
  v_lim int;
BEGIN
  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_a_driver', 'entries', '[]'::jsonb);
  END IF;

  PERFORM public.fn_driver_platform_balance_ensure_weekly(v_driver_id, timezone('utc', now()));
  v_lim := GREATEST(1, LEAST(COALESCE(p_limit, 50), 200));

  SELECT COALESCE(jsonb_agg(row_data ORDER BY sort_at DESC), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT
      bl.created_at AS sort_at,
      jsonb_build_object(
        'id', bl.id,
        'title', CASE bl.reason
          WHEN 'platform_cycle_fee' THEN 'Platform Balance'
          WHEN 'settlement' THEN 'Balance settlement'
          WHEN 'ride_fee' THEN 'Platform fee'
          WHEN 'reversal' THEN 'Reversal'
          WHEN 'manual_adjustment' THEN 'Manual adjustment'
          WHEN 'credit' THEN 'Credit'
          WHEN 'promotion' THEN 'Promotion'
          WHEN 'waiver' THEN 'Waiver'
          WHEN 'refund' THEN 'Refund'
          ELSE initcap(replace(bl.reason, '_', ' '))
        END,
        'reason', bl.reason,
        'amount_cents', bl.amount_cents,
        'currency', bl.currency,
        'created_at', bl.created_at,
        'ride_id', bl.ride_id,
        'status', 'posted',
        'type', bl.reason
      ) AS row_data
    FROM public.billing_ledger bl
    WHERE bl.driver_id = v_driver_id
    ORDER BY bl.created_at DESC
    LIMIT v_lim
  ) q;

  RETURN jsonb_build_object('ok', true, 'entries', v_rows);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_billing_ledger_history(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_billing_ledger_history(int) TO authenticated;
