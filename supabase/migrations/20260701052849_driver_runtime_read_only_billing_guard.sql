-- Driver runtime read-only guard for Platform Balance.
--
-- Root cause:
--   fn_driver_runtime() is STABLE and is called as a read/runtime contract.
--   It calls fn_driver_can_accept_rides(), which previously called
--   fn_driver_platform_balance_ensure_weekly(). That ensure function writes
--   billing cycle + ledger rows, so runtime could fail with:
--   "cannot execute INSERT in a read-only transaction".
--
-- Fix:
--   * Keep fn_driver_can_accept_rides() read-only.
--   * Let explicit mutation/status paths ensure cycles before reading.
--   * Preserve the existing public function names used by Flutter.

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
    'cycle_started_at', v_cycle_start_at,
    'cycle_ends_at', v_due_at,
    'ride_requests_paused', NOT v_allowed
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_billing_summary(
  p_driver_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_check jsonb;
  v_driver_id uuid;
  v_amount integer;
  v_anchor timestamptz;
  v_pending_id uuid;
  v_pending_amount integer;
  v_pending_started_at timestamptz;
  v_pending_external_id text;
BEGIN
  v_driver_id := COALESCE(
    p_driver_id,
    (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid() LIMIT 1)
  );

  v_check := public.fn_driver_can_accept_rides(v_driver_id);
  v_amount := COALESCE(
    (
      public.fn_get_market_config(
        'weekly_platform_balance_cents',
        COALESCE(v_check->>'country_code', 'NL'),
        NULL,
        NULL
      ) #>> '{}'
    )::integer,
    5000
  );

  SELECT a.balance_started_at
  INTO v_anchor
  FROM public.driver_platform_balance_accounts a
  WHERE a.driver_id = v_driver_id;

  SELECT
    bci.id,
    bci.amount_cents,
    bci.created_at,
    bci.external_payment_id
  INTO
    v_pending_id,
    v_pending_amount,
    v_pending_started_at,
    v_pending_external_id
  FROM public.billing_checkout_intents bci
  WHERE bci.driver_id = v_driver_id
    AND bci.checkout_kind = 'settlement'
    AND bci.status = 'open'
    AND bci.settlement_ledger_id IS NULL
  ORDER BY bci.created_at DESC
  LIMIT 1;

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
    'cycle_started_at', v_check->>'cycle_started_at',
    'cycle_ends_at', v_check->>'cycle_ends_at',
    'balance_started_at', v_anchor,
    'next_cycle_starts_at',
      COALESCE((v_check->>'cycle_ends_at')::timestamptz, v_anchor + interval '7 days'),
    'ride_requests_paused',
      COALESCE((v_check->>'ride_requests_paused')::boolean, false),
    'payment_pending', v_pending_id IS NOT NULL,
    'pending_payment_intent_id', v_pending_id,
    'pending_payment_cents', v_pending_amount,
    'pending_payment_started_at', v_pending_started_at,
    'pending_payment_external_id', v_pending_external_id
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
  v_payment_pending boolean;
BEGIN
  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  PERFORM public.fn_driver_platform_balance_ensure_weekly(v_driver_id);

  v_summary := public.fn_driver_billing_summary(v_driver_id);
  v_status := COALESCE(v_summary->>'status', 'GOOD');
  v_balance_state := COALESCE(v_summary->>'balance_state', 'current');
  v_allowed := COALESCE((v_summary->>'allowed')::boolean, true);
  v_outstanding := COALESCE((v_summary->>'outstanding')::bigint, 0);
  v_amount := COALESCE((v_summary->>'weekly_platform_balance_cents')::bigint, 5000);
  v_currency := COALESCE(NULLIF(btrim(v_summary->>'currency'), ''), 'EUR');
  v_payment_pending := COALESCE((v_summary->>'payment_pending')::boolean, false);

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
    'cycle_started_at', v_summary->>'cycle_started_at',
    'cycle_ends_at', v_summary->>'cycle_ends_at',
    'balance_started_at', v_summary->>'balance_started_at',
    'next_cycle_starts_at', v_summary->>'next_cycle_starts_at',
    'ride_requests_paused',
      COALESCE((v_summary->>'ride_requests_paused')::boolean, false),
    'payment_pending', v_payment_pending,
    'pending_payment_intent_id', v_summary->>'pending_payment_intent_id',
    'pending_payment_cents',
      CASE
        WHEN v_summary->>'pending_payment_cents' IS NULL THEN NULL
        ELSE (v_summary->>'pending_payment_cents')::bigint
      END,
    'pending_payment_started_at', v_summary->>'pending_payment_started_at',
    'checkout_amount_cents', CASE WHEN v_outstanding > 0 THEN v_outstanding ELSE NULL END,
    'billing_status_label', CASE
      WHEN v_payment_pending THEN 'payment_pending'
      WHEN v_balance_state = 'paused' THEN 'ride_requests_paused'
      WHEN v_balance_state = 'due' THEN 'balance_due'
      ELSE 'current'
    END,
    'allow_one_off_checkout', v_outstanding > 0,
    'billing_provider', 'platform_balance',
    'can_settle_outstanding', v_outstanding > 0
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_set_status(
  p_status text,
  p_lat double precision DEFAULT NULL,
  p_lng double precision DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_user_id uuid := auth.uid();
  v_d public.drivers%ROWTYPE;
  v_readiness jsonb;
  v_billing jsonb;
  v_flags jsonb;
  v_skip_gates boolean := false;
  v_status text := lower(trim(COALESCE(p_status, '')));
BEGIN
  IF v_status NOT IN ('available', 'offline', 'on_break') THEN
    RETURN jsonb_build_object(
      'status', 'offline',
      'blocked_reason', 'invalid_status',
      'message', 'Invalid status'
    );
  END IF;

  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = v_user_id
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'offline',
      'blocked_reason', 'not_a_driver',
      'message', 'Driver profile not found'
    );
  END IF;

  SELECT * INTO v_d FROM public.drivers d WHERE d.id = v_driver_id;

  IF v_status = 'available' THEN
    v_readiness := public.fn_driver_readiness_eval(v_driver_id);
    IF COALESCE((v_readiness->>'can_go_online')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object(
        'status', 'offline',
        'blocked_reason', 'missing_docs',
        'message', COALESCE(v_readiness->>'status_message', 'Compliance incomplete'),
        'readiness', v_readiness
      );
    END IF;

    v_flags := public.fn_app_config_jsonb('feature_flags');
    v_skip_gates := COALESCE((v_flags->>'skip_go_online_gates')::boolean, false);

    IF NOT v_skip_gates AND NOT public.fn_driver_is_review_account(v_user_id) THEN
      PERFORM public.fn_driver_platform_balance_ensure_weekly(v_driver_id);
      v_billing := public.fn_driver_can_accept_rides(v_driver_id);
      IF COALESCE((v_billing->>'allowed')::boolean, false) IS NOT TRUE THEN
        RETURN jsonb_build_object(
          'status', 'offline',
          'blocked_reason', 'payment_required',
          'message', COALESCE(v_billing->>'reason', 'Platform fee payment required'),
          'redirect', '/driver/billing'
        );
      END IF;
    END IF;
  END IF;

  UPDATE public.drivers
  SET status = v_status::public.driver_status,
      updated_at = timezone('utc', now())
  WHERE id = v_driver_id;

  IF p_lat IS NOT NULL AND p_lng IS NOT NULL THEN
    INSERT INTO public.driver_locations (
      user_id,
      driver_id,
      latitude,
      longitude,
      country_code,
      updated_at
    )
    VALUES (
      v_user_id,
      v_driver_id,
      p_lat,
      p_lng,
      COALESCE(v_d.country_code, 'NL'),
      timezone('utc', now())
    )
    ON CONFLICT (user_id) DO UPDATE
    SET driver_id = EXCLUDED.driver_id,
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        country_code = EXCLUDED.country_code,
        updated_at = EXCLUDED.updated_at;
  END IF;

  RETURN jsonb_build_object(
    'status', v_status,
    'message', CASE
      WHEN v_status = 'available' THEN 'Online'
      WHEN v_status = 'on_break' THEN 'On break'
      ELSE 'Offline'
    END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_can_accept_rides(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_billing_summary(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_billing_status() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_set_status(text, double precision, double precision) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.fn_driver_can_accept_rides(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_billing_summary(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_billing_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_set_status(text, double precision, double precision) TO authenticated;

COMMENT ON FUNCTION public.fn_driver_can_accept_rides(uuid) IS
  'Read-only Platform Balance eligibility check. Cycle creation must happen through explicit mutation paths.';
COMMENT ON FUNCTION public.fn_driver_billing_status() IS
  'Weekly-only Platform Balance status; ensures due cycles before returning driver-facing billing state.';
