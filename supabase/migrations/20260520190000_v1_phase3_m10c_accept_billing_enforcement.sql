-- Phase 3 M10C — Accept enforcement + market_config feature flag + grace period.
-- Requires M10A + M10B live. billing_enforcement=false disables block without redeploy.

-- ---------------------------------------------------------------------------
-- Market config: per-country enforcement + grace (NL launch: enforce, 0 grace)
-- ---------------------------------------------------------------------------
INSERT INTO public.market_config (scope, country_code, config_key, config_value)
SELECT 'country', 'NL', 'billing_enforcement', 'true'::jsonb
WHERE NOT EXISTS (
  SELECT 1 FROM public.market_config
  WHERE scope = 'country' AND country_code = 'NL'
    AND config_key = 'billing_enforcement' AND active = true
);

INSERT INTO public.market_config (scope, country_code, config_key, config_value)
SELECT 'country', 'NL', 'billing_grace_period_minutes', '0'::jsonb
WHERE NOT EXISTS (
  SELECT 1 FROM public.market_config
  WHERE scope = 'country' AND country_code = 'NL'
    AND config_key = 'billing_grace_period_minutes' AND active = true
);

-- ---------------------------------------------------------------------------
-- Eligibility: enforcement flag + grace (single control point for M10B + M10C)
-- ---------------------------------------------------------------------------
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
  v_outstanding bigint;
  v_status text;
  v_allowed boolean;
  v_reason text;
  v_enforcement boolean;
  v_grace_minutes integer;
  v_limit_reached_at timestamptz;
  v_in_grace boolean := false;
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

  v_outstanding := public.fn_billing_driver_outstanding_cents(v_driver_id, v_market.country_code);
  v_status := public.fn_billing_derive_status(v_outstanding, v_market.limit_cents);

  v_enforcement := COALESCE(
    (public.fn_get_market_config('billing_enforcement', v_market.country_code, v_market.city_id, v_market.zone_id) #>> '{}')::boolean,
    false
  );
  v_grace_minutes := COALESCE(
    (public.fn_get_market_config('billing_grace_period_minutes', v_market.country_code, v_market.city_id, v_market.zone_id) #>> '{}')::integer,
    0
  );

  IF NOT v_enforcement THEN
    v_allowed := true;
    v_reason := NULL;
  ELSIF v_status = 'LOCKED' THEN
    IF v_grace_minutes > 0 THEN
      SELECT MAX(bal.occurred_at) INTO v_limit_reached_at
      FROM public.billing_audit_log bal
      WHERE bal.driver_id = v_driver_id
        AND bal.event = 'billing.limit_reached';

      IF v_limit_reached_at IS NOT NULL
         AND v_limit_reached_at + make_interval(mins => v_grace_minutes) > timezone('utc', now())
      THEN
        v_in_grace := true;
        v_allowed := true;
        v_status := 'GRACE';
        v_reason := NULL;
      ELSE
        v_allowed := false;
        v_reason := 'Outstanding platform fees exceed market limit.';
      END IF;
    ELSE
      v_allowed := false;
      v_reason := 'Outstanding platform fees exceed market limit.';
    END IF;
  ELSE
    v_allowed := true;
    v_reason := NULL;
  END IF;

  RETURN jsonb_build_object(
    'allowed', v_allowed,
    'reason', v_reason,
    'status', v_status,
    'outstanding_cents', v_outstanding,
    'limit_cents', v_market.limit_cents,
    'remaining_cents', GREATEST(v_market.limit_cents - v_outstanding, 0),
    'currency', v_market.currency,
    'country_code', v_market.country_code,
    'billing_enforcement', v_enforcement,
    'grace_period_minutes', v_grace_minutes,
    'in_grace_period', v_in_grace
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Accept: check eligibility at accept time (respects flag via fn above)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_driver_accept_ride_invite (p_ride_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
  v_billing jsonb;
BEGIN
  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  v_billing := public.fn_driver_can_accept_rides(v_driver_id);

  IF COALESCE((v_billing->>'allowed')::boolean, false) = false THEN
    PERFORM public.fn_billing_audit_append(
      v_driver_id,
      'billing.accept_blocked',
      p_ride_request_id,
      jsonb_build_object(
        'reason', v_billing->>'reason',
        'status', v_billing->>'status',
        'outstanding_cents', v_billing->>'outstanding_cents',
        'limit_cents', v_billing->>'limit_cents',
        'billing_enforcement', v_billing->>'billing_enforcement'
      ),
      p_ride_request_id
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id,
      'dispatch.driver_rejected_billing',
      v_driver_id,
      jsonb_build_object(
        'reason', v_billing->>'reason',
        'status', v_billing->>'status',
        'outstanding_cents', v_billing->>'outstanding_cents',
        'limit_cents', v_billing->>'limit_cents'
      ),
      'driver',
      'supabase_trigger',
      p_ride_request_id
    );
    RETURN json_build_object(
      'ok', false,
      'error', 'billing_locked',
      'message', COALESCE(v_billing->>'reason', 'Outstanding platform fees exceed market limit.')
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.ride_request_invites i
    WHERE i.ride_request_id = p_ride_request_id
      AND i.driver_id = v_driver_id
      AND i.status = 'pending'
      AND i.expires_at > now()
  ) THEN
    RETURN json_build_object('ok', false, 'error', 'no_valid_invite');
  END IF;

  UPDATE public.ride_requests rr
  SET
    status = 'accepted',
    driver_id = v_driver_id,
    updated_at = now()
  WHERE rr.id = p_ride_request_id
    AND rr.status = 'pending';

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 0 THEN
    RETURN json_build_object('ok', false, 'error', 'race_lost');
  END IF;

  UPDATE public.ride_request_invites i
  SET status = 'superseded'
  WHERE i.ride_request_id = p_ride_request_id
    AND i.driver_id <> v_driver_id
    AND i.status = 'pending';

  UPDATE public.ride_request_invites i
  SET status = 'accepted'
  WHERE i.ride_request_id = p_ride_request_id
    AND i.driver_id = v_driver_id
    AND i.status = 'pending';

  RETURN json_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_driver_can_accept_rides(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_accept_ride_invite (uuid) TO authenticated;
