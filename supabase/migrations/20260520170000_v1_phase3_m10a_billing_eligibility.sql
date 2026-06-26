-- Phase 3 M10A — Billing eligibility (derived state, no stored billing_status column).
-- REPO ONLY until explicit prod approval.
-- Outstanding = SUM(billing_ledger); limit = fn_get_market_config; status computed at read time.

-- ---------------------------------------------------------------------------
-- billing_audit_log — support-facing billing timeline (billing.* namespace)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.billing_audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  ride_id uuid REFERENCES public.ride_requests(id) ON DELETE SET NULL,
  event text NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  correlation_id uuid,
  CONSTRAINT billing_audit_log_event_format CHECK (position('.' IN event) > 1),
  CONSTRAINT billing_audit_log_namespace CHECK (event LIKE 'billing.%')
);

CREATE INDEX IF NOT EXISTS idx_billing_audit_log_driver_occurred
  ON public.billing_audit_log (driver_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_billing_audit_log_correlation
  ON public.billing_audit_log (correlation_id, occurred_at DESC)
  WHERE correlation_id IS NOT NULL;

COMMENT ON TABLE public.billing_audit_log IS
  'Append-only billing timeline: billing.ride_fee_created, billing.limit_reached, billing.accept_blocked, etc.';

ALTER TABLE public.billing_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS billing_audit_log_driver_select ON public.billing_audit_log;
CREATE POLICY billing_audit_log_driver_select
  ON public.billing_audit_log
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.drivers d
      WHERE d.id = billing_audit_log.driver_id AND d.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS billing_audit_log_admin_select ON public.billing_audit_log;
CREATE POLICY billing_audit_log_admin_select
  ON public.billing_audit_log
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
  );

CREATE OR REPLACE FUNCTION public.fn_billing_audit_append(
  p_driver_id uuid,
  p_event text,
  p_ride_id uuid DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_correlation_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_driver_id IS NULL OR p_event IS NULL OR btrim(p_event) = '' THEN
    RETURN;
  END IF;
  IF p_event NOT LIKE 'billing.%' THEN
    RAISE EXCEPTION 'billing_audit_log requires billing.* event, got %', p_event;
  END IF;
  INSERT INTO public.billing_audit_log (driver_id, ride_id, event, metadata, correlation_id)
  VALUES (
    p_driver_id,
    p_ride_id,
    p_event,
    COALESCE(p_metadata, '{}'::jsonb),
    COALESCE(p_correlation_id, p_ride_id)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_billing_audit_append(uuid, text, uuid, jsonb, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_billing_audit_append(uuid, text, uuid, jsonb, uuid) TO service_role;

-- ---------------------------------------------------------------------------
-- Derived billing helpers (ledger + market_config = single source of truth)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_billing_driver_outstanding_cents(
  p_driver_id uuid,
  p_country_code text DEFAULT NULL
)
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(SUM(bl.amount_cents), 0)::bigint
  FROM public.billing_ledger bl
  WHERE bl.driver_id = p_driver_id
    AND (p_country_code IS NULL OR bl.country_code = p_country_code);
$$;

CREATE OR REPLACE FUNCTION public.fn_billing_derive_status(
  p_outstanding_cents bigint,
  p_limit_cents bigint
)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_limit_cents IS NULL OR p_limit_cents <= 0 THEN 'GOOD'
    WHEN p_outstanding_cents >= p_limit_cents THEN 'LOCKED'
    WHEN p_outstanding_cents >= (p_limit_cents * 80 / 100) THEN 'WARNING'
    ELSE 'GOOD'
  END;
$$;

CREATE OR REPLACE FUNCTION public.fn_billing_resolve_driver_market(
  p_driver_id uuid,
  p_country_code text DEFAULT NULL,
  p_city_id uuid DEFAULT NULL,
  p_zone_id uuid DEFAULT NULL
)
RETURNS TABLE (
  country_code text,
  city_id uuid,
  zone_id uuid,
  currency text,
  limit_cents bigint,
  fee_cents bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_country text;
  v_city uuid;
  v_zone uuid;
BEGIN
  SELECT
    COALESCE(NULLIF(btrim(p_country_code), ''), NULLIF(btrim(d.country_code), ''), 'NL'),
    p_city_id,
    p_zone_id
  INTO v_country, v_city, v_zone
  FROM public.drivers d
  WHERE d.id = p_driver_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  country_code := v_country;
  city_id := v_city;
  zone_id := v_zone;
  currency := COALESCE(
    public.fn_get_market_config('currency', v_country, v_city, v_zone) #>> '{}',
    'EUR'
  );
  limit_cents := COALESCE(
    (public.fn_get_market_config('outstanding_limit_cents', v_country, v_city, v_zone) #>> '{}')::bigint,
    6000
  );
  fee_cents := COALESCE(
    (public.fn_get_market_config('platform_fee_cents', v_country, v_city, v_zone) #>> '{}')::bigint,
    100
  );
  RETURN NEXT;
END;
$$;

-- ---------------------------------------------------------------------------
-- M10A: fn_driver_can_accept_rides — expose logic only (no enforcement yet)
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
  v_allowed := v_status <> 'LOCKED';
  v_reason := CASE
    WHEN v_allowed THEN NULL
    ELSE 'Outstanding platform fees exceed market limit.'
  END;

  RETURN jsonb_build_object(
    'allowed', v_allowed,
    'reason', v_reason,
    'status', v_status,
    'outstanding_cents', v_outstanding,
    'limit_cents', v_market.limit_cents,
    'remaining_cents', GREATEST(v_market.limit_cents - v_outstanding, 0),
    'currency', v_market.currency,
    'country_code', v_market.country_code
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- fn_driver_billing_summary — Flutter dashboard RPC (no client-side math)
-- ---------------------------------------------------------------------------
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
  v_market record;
  v_driver_id uuid;
BEGIN
  v_check := public.fn_driver_can_accept_rides(p_driver_id);
  v_driver_id := COALESCE(
    p_driver_id,
    (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid() LIMIT 1)
  );

  SELECT * INTO v_market
  FROM public.fn_billing_resolve_driver_market(v_driver_id) m
  LIMIT 1;

  RETURN jsonb_build_object(
    'outstanding', (v_check->>'outstanding_cents')::bigint,
    'limit', (v_check->>'limit_cents')::bigint,
    'remaining', (v_check->>'remaining_cents')::bigint,
    'currency', v_check->>'currency',
    'status', v_check->>'status',
    'allowed', (v_check->>'allowed')::boolean,
    'platform_fee_cents', COALESCE(v_market.fee_cents, 100),
    'country_code', v_check->>'country_code'
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- fn_driver_platform_health — admin + future go-online single RPC
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_driver_platform_health(
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
  v_d public.drivers%ROWTYPE;
  v_billing jsonb;
  v_summary jsonb;
  v_verified boolean;
  v_docs boolean;
  v_vehicle boolean;
  v_online boolean;
  v_dispatch_eligible boolean;
BEGIN
  IF p_driver_id IS NOT NULL THEN
    IF auth.uid() IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
       AND NOT EXISTS (
         SELECT 1 FROM public.drivers d
         WHERE d.id = p_driver_id AND d.user_id = auth.uid()
       )
    THEN
      RETURN jsonb_build_object('allowed', false, 'error', 'forbidden');
    END IF;
    v_driver_id := p_driver_id;
  ELSE
    SELECT d.id INTO v_driver_id
    FROM public.drivers d
    WHERE d.user_id = auth.uid()
    LIMIT 1;
  END IF;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('allowed', false, 'error', 'not_a_driver');
  END IF;

  SELECT * INTO v_d FROM public.drivers d WHERE d.id = v_driver_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('allowed', false, 'error', 'driver_not_found');
  END IF;

  v_billing := public.fn_driver_can_accept_rides(v_driver_id);
  v_summary := public.fn_driver_billing_summary(v_driver_id);

  v_verified := COALESCE(v_d.profile_status = 'verified', false)
    OR COALESCE(v_d.is_verified_badge, false);
  v_docs := COALESCE(v_d.chauffeurspas_verified, false)
    AND COALESCE(v_d.rijbewijs_verified, false)
    AND COALESCE(v_d.taxi_insurance_verified, false);
  v_vehicle := COALESCE(v_d.vehicle_verified, false)
    OR COALESCE(v_d.vehicle_photos_approved, false);
  v_online := v_d.status = 'available';

  v_dispatch_eligible :=
    COALESCE((v_billing->>'allowed')::boolean, false)
    AND v_online
    AND COALESCE(v_d.compliance_status, '') IS DISTINCT FROM 'suspended'
    AND COALESCE(v_d.min_profile_requirements_met, false);

  RETURN jsonb_build_object(
    'allowed', v_dispatch_eligible,
    'billing', jsonb_build_object(
      'status', v_summary->>'status',
      'outstanding', (v_summary->>'outstanding')::bigint,
      'limit', (v_summary->>'limit')::bigint,
      'remaining', (v_summary->>'remaining')::bigint,
      'currency', v_summary->>'currency',
      'can_accept_rides', (v_billing->>'allowed')::boolean
    ),
    'driver', jsonb_build_object(
      'verified', v_verified,
      'documents_valid', v_docs,
      'vehicle_approved', v_vehicle,
      'is_online', v_online,
      'compliance_status', v_d.compliance_status,
      'profile_status', v_d.profile_status,
      'operational_status', v_d.status
    ),
    'dispatch', jsonb_build_object(
      'eligible', v_dispatch_eligible
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_billing_driver_outstanding_cents(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_billing_derive_status(bigint, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_billing_resolve_driver_market(uuid, text, uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_can_accept_rides(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_billing_summary(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_platform_health(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.fn_driver_can_accept_rides(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_billing_summary(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_platform_health(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_billing_driver_outstanding_cents(uuid, text) TO service_role;

-- Log billing.limit_reached when accrual pushes driver to LOCKED (extends Step 4 fn)
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
  v_outstanding_before bigint;
  v_outstanding_after bigint;
  v_limit bigint;
  v_status_after text;
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

  v_limit := COALESCE(
    (public.fn_get_market_config('outstanding_limit_cents', v_country, p_city_id, p_zone_id) #>> '{}')::bigint,
    6000
  );
  v_outstanding_before := public.fn_billing_driver_outstanding_cents(p_driver_id, v_country);

  INSERT INTO public.billing_ledger (
    driver_id, amount_cents, reason, ride_id,
    country_code, currency, metadata, created_by
  )
  VALUES (
    p_driver_id, v_fee_cents, 'ride_fee', p_ride_id,
    v_country, v_currency,
    jsonb_build_object('source', 'trip_completed_trigger'),
    auth.uid()
  )
  ON CONFLICT (ride_id, reason)
    WHERE reason = 'ride_fee' AND ride_id IS NOT NULL
  DO NOTHING
  RETURNING id INTO v_ledger_id;

  IF v_ledger_id IS NOT NULL THEN
    PERFORM public.fn_ride_audit_append(
      p_ride_id, 'billing.ride_fee_created', p_driver_id,
      jsonb_build_object(
        'ledger_id', v_ledger_id,
        'amount_cents', v_fee_cents,
        'currency', v_currency,
        'country_code', v_country
      ),
      'system', 'supabase_trigger', p_ride_id
    );

    v_outstanding_after := public.fn_billing_driver_outstanding_cents(p_driver_id, v_country);
    v_status_after := public.fn_billing_derive_status(v_outstanding_after, v_limit);

    IF v_status_after = 'LOCKED'
       AND public.fn_billing_derive_status(v_outstanding_before, v_limit) <> 'LOCKED'
    THEN
      PERFORM public.fn_billing_audit_append(
        p_driver_id,
        'billing.limit_reached',
        p_ride_id,
        jsonb_build_object(
          'outstanding_cents', v_outstanding_after,
          'limit_cents', v_limit,
          'ledger_id', v_ledger_id
        ),
        p_ride_id
      );
    END IF;
  END IF;

  RETURN v_ledger_id;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_billing_accrue_ride_fee(uuid, uuid, text, uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_billing_accrue_ride_fee(uuid, uuid, text, uuid, uuid) TO service_role;
