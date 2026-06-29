-- Anchor weekly Platform Balance cycles at model enablement time, not driver
-- account creation time. This prevents retroactive charges for existing drivers.

CREATE TABLE IF NOT EXISTS public.driver_platform_balance_accounts (
  driver_id uuid PRIMARY KEY REFERENCES public.drivers(id) ON DELETE CASCADE,
  balance_started_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.driver_platform_balance_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS driver_platform_balance_accounts_driver_select
  ON public.driver_platform_balance_accounts;
CREATE POLICY driver_platform_balance_accounts_driver_select
  ON public.driver_platform_balance_accounts
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.drivers d
      WHERE d.id = driver_platform_balance_accounts.driver_id
        AND d.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS driver_platform_balance_accounts_admin_select
  ON public.driver_platform_balance_accounts;
CREATE POLICY driver_platform_balance_accounts_admin_select
  ON public.driver_platform_balance_accounts
  FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid()));

COMMENT ON TABLE public.driver_platform_balance_accounts IS
  'Per-driver Platform Balance anchor. First cycle starts here; no retroactive driver.created_at billing.';

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

  SELECT d.id, d.country_code
  INTO v_driver
  FROM public.drivers d
  WHERE d.id = p_driver_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'driver_not_found');
  END IF;

  INSERT INTO public.driver_platform_balance_accounts (driver_id, balance_started_at)
  VALUES (p_driver_id, p_now)
  ON CONFLICT (driver_id) DO NOTHING;

  SELECT a.balance_started_at
  INTO v_anchor
  FROM public.driver_platform_balance_accounts a
  WHERE a.driver_id = p_driver_id;

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

REVOKE ALL ON FUNCTION public.fn_driver_platform_balance_ensure_weekly(uuid, timestamptz)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_platform_balance_ensure_weekly(uuid, timestamptz)
  TO authenticated, service_role;
