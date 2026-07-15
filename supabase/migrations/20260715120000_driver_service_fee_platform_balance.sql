-- Driver Service Fee + Platform Balance v2.
--
-- Reuses the canonical billing_ledger and ride_payments domains. The former
-- weekly Platform Balance accrual is retired; historical entries remain
-- immutable. New behavior is dark-launched behind backend feature flags.

ALTER TABLE public.billing_ledger
  DROP CONSTRAINT IF EXISTS billing_ledger_reason_check;

ALTER TABLE public.billing_ledger
  ADD CONSTRAINT billing_ledger_reason_check CHECK (reason IN (
    'ride_fee', 'prepaid_fee_collection', 'platform_cycle_fee',
    'balance_payment', 'reversal', 'manual_adjustment', 'credit',
    'promotion', 'waiver', 'refund', 'settlement'
  ));

CREATE TABLE IF NOT EXISTS public.driver_service_fee_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fee_code text NOT NULL DEFAULT 'HEYCABY_DRIVER_SERVICE_FEE',
  fee_type text NOT NULL CHECK (fee_type IN ('fixed', 'percentage')),
  amount_cents integer,
  percentage_basis_points integer,
  currency text NOT NULL DEFAULT 'EUR' CHECK (currency ~ '^[A-Z]{3}$'),
  applies_to_instant boolean NOT NULL DEFAULT true,
  applies_to_scheduled boolean NOT NULL DEFAULT true,
  applies_to_taxi_terug boolean NOT NULL DEFAULT true,
  applies_to_prepaid boolean NOT NULL DEFAULT true,
  applies_to_direct_payment boolean NOT NULL DEFAULT true,
  warning_threshold_cents integer NOT NULL DEFAULT 4000 CHECK (warning_threshold_cents >= 0),
  balance_limit_cents integer NOT NULL DEFAULT 5000 CHECK (balance_limit_cents > 0),
  direct_payment_restriction_enabled boolean NOT NULL DEFAULT true,
  is_active boolean NOT NULL DEFAULT true,
  effective_from timestamptz NOT NULL,
  effective_until timestamptz,
  reason text NOT NULL,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT driver_service_fee_value CHECK (
    (fee_type = 'fixed' AND amount_cents IS NOT NULL AND amount_cents >= 0
      AND percentage_basis_points IS NULL)
    OR
    (fee_type = 'percentage' AND percentage_basis_points BETWEEN 0 AND 10000
      AND amount_cents IS NULL)
  ),
  CONSTRAINT driver_service_fee_window CHECK (
    effective_until IS NULL OR effective_until > effective_from
  ),
  CONSTRAINT driver_service_fee_thresholds CHECK (
    warning_threshold_cents <= balance_limit_cents
  )
);

CREATE INDEX IF NOT EXISTS driver_service_fee_versions_effective_idx
  ON public.driver_service_fee_versions (fee_code, effective_from DESC)
  WHERE is_active;

ALTER TABLE public.driver_service_fee_versions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.driver_service_fee_versions FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.driver_service_fee_versions TO service_role;

INSERT INTO public.driver_service_fee_versions (
  fee_type, amount_cents, currency, effective_from, reason
)
SELECT 'fixed', 195, 'EUR', timezone('utc', now()),
       'Initial per-completed-ride HeyCaby Driver Service Fee'
WHERE NOT EXISTS (
  SELECT 1 FROM public.driver_service_fee_versions
  WHERE fee_code = 'HEYCABY_DRIVER_SERVICE_FEE'
);

CREATE TABLE IF NOT EXISTS public.ride_driver_fee_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id uuid NOT NULL UNIQUE REFERENCES public.ride_requests(id) ON DELETE RESTRICT,
  driver_id uuid NOT NULL REFERENCES public.drivers(id) ON DELETE RESTRICT,
  fee_config_id uuid NOT NULL REFERENCES public.driver_service_fee_versions(id) ON DELETE RESTRICT,
  fee_code text NOT NULL,
  fee_type text NOT NULL CHECK (fee_type IN ('fixed', 'percentage')),
  fee_amount_cents integer NOT NULL CHECK (fee_amount_cents >= 0),
  fare_amount_cents integer NOT NULL CHECK (fare_amount_cents >= 0),
  estimated_driver_net_cents integer NOT NULL CHECK (estimated_driver_net_cents >= 0),
  currency text NOT NULL DEFAULT 'EUR' CHECK (currency ~ '^[A-Z]{3}$'),
  collection_method text NOT NULL CHECK (
    collection_method IN ('pending', 'mollie_deduction', 'driver_platform_balance')
  ),
  quoted_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  accepted_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  finalized_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS ride_driver_fee_snapshots_driver_idx
  ON public.ride_driver_fee_snapshots (driver_id, accepted_at DESC);

ALTER TABLE public.ride_driver_fee_snapshots ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ride_driver_fee_snapshots FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.ride_driver_fee_snapshots TO service_role;

ALTER TABLE public.ride_payments
  ADD COLUMN IF NOT EXISTS mollie_processing_cost_cents integer
    CHECK (mollie_processing_cost_cents IS NULL OR mollie_processing_cost_cents >= 0),
  ADD COLUMN IF NOT EXISTS mollie_reconciliation_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.ride_payments.mollie_processing_cost_cents IS
  'Actual provider-reported cost. Never estimated or deducted from the Driver Service Fee payout split.';

CREATE OR REPLACE FUNCTION private.trg_protect_driver_fee_snapshot()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF old.ride_id IS DISTINCT FROM new.ride_id
     OR old.driver_id IS DISTINCT FROM new.driver_id
     OR old.fee_config_id IS DISTINCT FROM new.fee_config_id
     OR old.fee_code IS DISTINCT FROM new.fee_code
     OR old.fee_type IS DISTINCT FROM new.fee_type
     OR old.fee_amount_cents IS DISTINCT FROM new.fee_amount_cents
     OR old.fare_amount_cents IS DISTINCT FROM new.fare_amount_cents
     OR old.estimated_driver_net_cents IS DISTINCT FROM new.estimated_driver_net_cents
     OR old.currency IS DISTINCT FROM new.currency
     OR old.quoted_at IS DISTINCT FROM new.quoted_at
     OR old.accepted_at IS DISTINCT FROM new.accepted_at
  THEN RAISE EXCEPTION 'driver_fee_snapshot_is_immutable' USING ERRCODE='P0001'; END IF;
  IF old.finalized_at IS NOT NULL AND old IS DISTINCT FROM new THEN
    RAISE EXCEPTION 'driver_fee_snapshot_is_finalized' USING ERRCODE='P0001';
  END IF;
  RETURN new;
END; $$;

DROP TRIGGER IF EXISTS trg_protect_driver_fee_snapshot ON public.ride_driver_fee_snapshots;
CREATE TRIGGER trg_protect_driver_fee_snapshot
BEFORE UPDATE ON public.ride_driver_fee_snapshots
FOR EACH ROW EXECUTE FUNCTION private.trg_protect_driver_fee_snapshot();

INSERT INTO public.app_config (key, value)
VALUES (
  'feature_flags',
  jsonb_build_object(
    'driver_service_fee_enabled', false,
    'prepaid_driver_fee_deduction_enabled', false,
    'direct_payment_driver_balance_enabled', false,
    'driver_balance_restriction_enabled', false,
    'driver_balance_payment_enabled', false
  )::text
)
ON CONFLICT (key) DO UPDATE SET value = (
  jsonb_build_object(
    'driver_service_fee_enabled', false,
    'prepaid_driver_fee_deduction_enabled', false,
    'direct_payment_driver_balance_enabled', false,
    'driver_balance_restriction_enabled', false,
    'driver_balance_payment_enabled', false
  ) || COALESCE(NULLIF(public.app_config.value, '')::jsonb, '{}'::jsonb)
)::text;

-- Retire future weekly accrual without deleting or rewriting its history.
UPDATE public.market_config
SET config_value = '0'::jsonb, updated_at = timezone('utc', now())
WHERE scope = 'country' AND country_code = 'NL'
  AND config_key = 'weekly_platform_balance_cents' AND active;

CREATE OR REPLACE FUNCTION private.fn_driver_fee_flag(p_key text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT COALESCE((NULLIF(ac.value, '')::jsonb ->> p_key)::boolean, false)
  FROM public.app_config ac WHERE ac.key = 'feature_flags';
$$;

REVOKE ALL ON FUNCTION private.fn_driver_fee_flag(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.fn_driver_fee_flag(text) TO service_role;

CREATE OR REPLACE FUNCTION public.fn_get_active_driver_service_fee(
  p_at timestamptz DEFAULT timezone('utc', now())
)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v public.driver_service_fee_versions%ROWTYPE;
BEGIN
  SELECT * INTO v
  FROM public.driver_service_fee_versions f
  WHERE f.fee_code = 'HEYCABY_DRIVER_SERVICE_FEE'
    AND f.is_active AND f.effective_from <= p_at
    AND (f.effective_until IS NULL OR f.effective_until > p_at)
  ORDER BY f.effective_from DESC LIMIT 1;
  IF v.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'driver_service_fee_not_configured');
  END IF;
  RETURN jsonb_build_object(
    'ok', true, 'id', v.id, 'fee_code', v.fee_code,
    'fee_type', v.fee_type, 'amount_cents', v.amount_cents,
    'percentage_basis_points', v.percentage_basis_points,
    'currency', v.currency, 'warning_threshold_cents', v.warning_threshold_cents,
    'balance_limit_cents', v.balance_limit_cents,
    'direct_payment_restriction_enabled', v.direct_payment_restriction_enabled,
    'effective_from', v.effective_from, 'effective_until', v.effective_until
  );
END; $$;

REVOKE ALL ON FUNCTION public.fn_get_active_driver_service_fee(timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_get_active_driver_service_fee(timestamptz)
  TO service_role;

CREATE OR REPLACE FUNCTION private.fn_ride_fare_cents(p_ride public.ride_requests)
RETURNS integer
LANGUAGE plpgsql IMMUTABLE SET search_path = '' AS $$
DECLARE v jsonb := to_jsonb(p_ride); v_cents integer; v_euros numeric;
BEGIN
  v_cents := NULLIF(v->>'manual_fare_cents', '')::integer;
  IF v_cents IS NOT NULL AND v_cents >= 0 THEN RETURN v_cents; END IF;
  v_euros := COALESCE(
    NULLIF(v->>'final_fare', '')::numeric,
    NULLIF(v->>'marketplace_offered_fare', '')::numeric,
    NULLIF(v->>'offered_fare', '')::numeric,
    NULLIF(v->>'quoted_fare', '')::numeric,
    NULLIF(v->>'estimated_fare', '')::numeric,
    NULLIF(v->>'estimated_price', '')::numeric
  );
  RETURN CASE WHEN v_euros IS NULL THEN NULL ELSE GREATEST(round(v_euros * 100)::integer, 0) END;
END; $$;

CREATE OR REPLACE FUNCTION private.fn_driver_fee_collection_method(
  p_ride public.ride_requests
)
RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_flags jsonb; v_mode text := COALESCE(to_jsonb(p_ride)->>'booking_mode', 'instant');
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.ride_payments rp WHERE rp.ride_id = p_ride.id
      AND rp.state NOT IN ('failed','canceled','expired','refunded')
  ) THEN RETURN 'mollie_deduction'; END IF;
  SELECT COALESCE(NULLIF(ac.value, '')::jsonb, '{}'::jsonb) INTO v_flags
  FROM public.app_config ac WHERE ac.key = 'feature_flags';
  IF COALESCE((v_flags->>'ride_prepaid_payments_enabled')::boolean, false)
    AND ((v_mode = 'scheduled' AND COALESCE((v_flags->>'ride_prepaid_scheduled_enabled')::boolean, false))
      OR (v_mode = 'terug' AND COALESCE((v_flags->>'ride_prepaid_taxi_terug_enabled')::boolean, false)))
  THEN RETURN 'mollie_deduction'; END IF;
  RETURN 'driver_platform_balance';
END; $$;

CREATE OR REPLACE FUNCTION public.fn_quote_driver_ride_earnings(
  p_ride_id uuid,
  p_driver_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_driver uuid; v_ride public.ride_requests%ROWTYPE; v_fee jsonb;
  v_fare integer; v_fee_cents integer; v_method text; v_balance bigint;
  v_enabled boolean;
BEGIN
  v_driver := COALESCE(p_driver_id, (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid()));
  IF v_driver IS NULL THEN RETURN jsonb_build_object('ok',false,'error','not_a_driver'); END IF;
  IF auth.role() <> 'service_role' AND NOT EXISTS (
    SELECT 1 FROM public.drivers d WHERE d.id=v_driver AND d.user_id=auth.uid()
  ) THEN RETURN jsonb_build_object('ok',false,'error','forbidden'); END IF;
  SELECT * INTO v_ride FROM public.ride_requests r WHERE r.id=p_ride_id;
  IF v_ride.id IS NULL THEN RETURN jsonb_build_object('ok',false,'error','ride_not_found'); END IF;
  v_fare := private.fn_ride_fare_cents(v_ride);
  IF v_fare IS NULL THEN RETURN jsonb_build_object('ok',false,'error','backend_fare_unavailable'); END IF;
  v_fee := public.fn_get_active_driver_service_fee(timezone('utc', now()));
  IF COALESCE((v_fee->>'ok')::boolean,false) IS NOT TRUE THEN RETURN v_fee; END IF;
  v_enabled := private.fn_driver_fee_flag('driver_service_fee_enabled');
  v_fee_cents := CASE WHEN NOT v_enabled THEN 0
    WHEN v_fee->>'fee_type'='fixed' THEN (v_fee->>'amount_cents')::integer
    ELSE round(v_fare * (v_fee->>'percentage_basis_points')::integer / 10000.0)::integer END;
  v_fee_cents := LEAST(GREATEST(v_fee_cents,0),v_fare);
  v_method := private.fn_driver_fee_collection_method(v_ride);
  v_balance := public.fn_billing_driver_outstanding_cents(v_driver, COALESCE(v_ride.country_code,'NL'));
  RETURN jsonb_build_object(
    'ok',true,'enabled',v_enabled,'ride_id',p_ride_id,'driver_id',v_driver,
    'ride_fare_cents',v_fare,'service_fee_cents',v_fee_cents,
    'estimated_driver_net_cents',v_fare-v_fee_cents,'currency',v_fee->>'currency',
    'collection_method',v_method,'fee_config_id',v_fee->>'id',
    'current_platform_balance_cents',GREATEST(v_balance,0),
    'projected_platform_balance_cents',GREATEST(v_balance,0)+CASE WHEN v_method='driver_platform_balance' THEN v_fee_cents ELSE 0 END,
    'warning_threshold_cents',(v_fee->>'warning_threshold_cents')::integer,
    'balance_limit_cents',(v_fee->>'balance_limit_cents')::integer
  );
END; $$;

REVOKE ALL ON FUNCTION public.fn_quote_driver_ride_earnings(uuid,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_quote_driver_ride_earnings(uuid,uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.fn_snapshot_driver_service_fee(
  p_ride_id uuid, p_driver_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_quote jsonb; v_snapshot public.ride_driver_fee_snapshots%ROWTYPE;
BEGIN
  SELECT * INTO v_snapshot FROM public.ride_driver_fee_snapshots WHERE ride_id=p_ride_id;
  IF v_snapshot.id IS NOT NULL THEN RETURN jsonb_build_object(
    'ok',true,'idempotent_replay',true,'snapshot_id',v_snapshot.id,
    'service_fee_cents',v_snapshot.fee_amount_cents,'fare_amount_cents',v_snapshot.fare_amount_cents,
    'estimated_driver_net_cents',v_snapshot.estimated_driver_net_cents,
    'collection_method',v_snapshot.collection_method,'currency',v_snapshot.currency,
    'fee_config_id',v_snapshot.fee_config_id
  ); END IF;
  IF NOT private.fn_driver_fee_flag('driver_service_fee_enabled') THEN
    RETURN jsonb_build_object('ok',true,'enabled',false,'service_fee_cents',0);
  END IF;
  v_quote := public.fn_quote_driver_ride_earnings(p_ride_id,p_driver_id);
  IF COALESCE((v_quote->>'ok')::boolean,false) IS NOT TRUE THEN RETURN v_quote; END IF;
  INSERT INTO public.ride_driver_fee_snapshots(
    ride_id,driver_id,fee_config_id,fee_code,fee_type,fee_amount_cents,
    fare_amount_cents,estimated_driver_net_cents,currency,collection_method,metadata
  ) SELECT p_ride_id,p_driver_id,f.id,f.fee_code,f.fee_type,
      (v_quote->>'service_fee_cents')::integer,(v_quote->>'ride_fare_cents')::integer,
      (v_quote->>'estimated_driver_net_cents')::integer,v_quote->>'currency',
      v_quote->>'collection_method',jsonb_build_object('source','acceptance_snapshot')
    FROM public.driver_service_fee_versions f WHERE f.id=(v_quote->>'fee_config_id')::uuid
  RETURNING * INTO v_snapshot;
  PERFORM public.fn_ride_audit_append(p_ride_id,'billing.driver_fee_snapshotted',p_driver_id,
    jsonb_build_object('snapshot_id',v_snapshot.id,'fee_cents',v_snapshot.fee_amount_cents,
      'fare_cents',v_snapshot.fare_amount_cents,'collection_method',v_snapshot.collection_method),
    'system','supabase_trigger',p_ride_id);
  RETURN jsonb_build_object('ok',true,'snapshot_id',v_snapshot.id,
    'service_fee_cents',v_snapshot.fee_amount_cents,'fare_amount_cents',v_snapshot.fare_amount_cents,
    'estimated_driver_net_cents',v_snapshot.estimated_driver_net_cents,
    'collection_method',v_snapshot.collection_method,'currency',v_snapshot.currency,
    'fee_config_id',v_snapshot.fee_config_id);
END; $$;

REVOKE ALL ON FUNCTION public.fn_snapshot_driver_service_fee(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.fn_snapshot_driver_service_fee(uuid,uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.fn_prepare_prepaid_driver_service_fee(
  p_ride_id uuid, p_driver_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_result jsonb; v_s public.ride_driver_fee_snapshots%ROWTYPE;
BEGIN
  v_result := public.fn_snapshot_driver_service_fee(p_ride_id,p_driver_id);
  IF COALESCE((v_result->>'ok')::boolean,false) IS NOT TRUE
     OR COALESCE((v_result->>'enabled')::boolean,true) IS FALSE THEN
    RETURN v_result;
  END IF;
  SELECT * INTO v_s FROM public.ride_driver_fee_snapshots
  WHERE ride_id=p_ride_id AND driver_id=p_driver_id FOR UPDATE;
  IF v_s.id IS NULL THEN RETURN jsonb_build_object('ok',false,'error','driver_fee_snapshot_missing'); END IF;
  IF v_s.finalized_at IS NOT NULL AND v_s.collection_method<>'mollie_deduction' THEN
    RETURN jsonb_build_object('ok',false,'error','driver_fee_collection_already_finalized');
  END IF;
  UPDATE public.ride_driver_fee_snapshots
  SET collection_method='mollie_deduction',
      metadata=metadata||jsonb_build_object('prepaid_selected_at',timezone('utc',now()))
  WHERE id=v_s.id AND finalized_at IS NULL;
  RETURN jsonb_build_object('ok',true,'enabled',true,'snapshot_id',v_s.id,
    'service_fee_cents',v_s.fee_amount_cents,'fare_amount_cents',v_s.fare_amount_cents,
    'estimated_driver_net_cents',v_s.estimated_driver_net_cents,
    'collection_method','mollie_deduction','currency',v_s.currency,
    'fee_config_id',v_s.fee_config_id);
END; $$;

REVOKE ALL ON FUNCTION public.fn_prepare_prepaid_driver_service_fee(uuid,uuid)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.fn_prepare_prepaid_driver_service_fee(uuid,uuid)
  TO service_role;

CREATE OR REPLACE FUNCTION private.trg_driver_fee_acceptance_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_check jsonb; v_snapshot jsonb;
BEGIN
  IF new.driver_id IS NULL OR new.status NOT IN ('assigned','accepted','driver_found')
     OR (old.driver_id IS NOT DISTINCT FROM new.driver_id AND old.status IS NOT DISTINCT FROM new.status)
  THEN RETURN new; END IF;
  v_check := public.fn_check_driver_payment_eligibility(new.driver_id,new.id);
  IF COALESCE((v_check->>'ride_allowed')::boolean,false) IS NOT TRUE THEN
    RAISE EXCEPTION 'driver_platform_balance_limit_reached' USING ERRCODE='P0001';
  END IF;
  v_snapshot := public.fn_snapshot_driver_service_fee(new.id,new.driver_id);
  IF COALESCE((v_snapshot->>'ok')::boolean,false) IS NOT TRUE THEN
    RAISE EXCEPTION 'driver_fee_snapshot_failed' USING ERRCODE='P0001';
  END IF;
  RETURN new;
END; $$;

-- Forward declaration is replaced below before this trigger can execute.
CREATE OR REPLACE FUNCTION public.fn_check_driver_payment_eligibility(
  p_driver_id uuid DEFAULT NULL, p_ride_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_driver uuid; v_fee jsonb; v_outstanding bigint; v_method text := 'driver_platform_balance';
  v_ride public.ride_requests%ROWTYPE; v_direct boolean; v_restrict boolean;
  v_warning bigint; v_limit bigint;
BEGIN
  v_driver := COALESCE(p_driver_id,(SELECT d.id FROM public.drivers d WHERE d.user_id=auth.uid()));
  IF v_driver IS NULL THEN RETURN jsonb_build_object('ride_allowed',false,'reason','not_a_driver'); END IF;
  IF auth.role()<>'service_role' AND NOT EXISTS(
    SELECT 1 FROM public.drivers d WHERE d.id=v_driver AND d.user_id=auth.uid()
  ) THEN RETURN jsonb_build_object('ride_allowed',false,'reason','forbidden'); END IF;
  v_fee := public.fn_get_active_driver_service_fee(timezone('utc',now()));
  IF COALESCE((v_fee->>'ok')::boolean,false) IS NOT TRUE THEN RETURN v_fee || jsonb_build_object('ride_allowed',false); END IF;
  IF p_ride_id IS NOT NULL THEN
    SELECT * INTO v_ride FROM public.ride_requests WHERE id=p_ride_id;
    IF v_ride.id IS NULL THEN RETURN jsonb_build_object('ride_allowed',false,'reason','ride_not_found'); END IF;
    v_method := private.fn_driver_fee_collection_method(v_ride);
  END IF;
  v_outstanding := public.fn_billing_driver_outstanding_cents(v_driver,NULL);
  v_warning := (v_fee->>'warning_threshold_cents')::bigint;
  v_limit := (v_fee->>'balance_limit_cents')::bigint;
  v_restrict := private.fn_driver_fee_flag('driver_service_fee_enabled')
    AND private.fn_driver_fee_flag('driver_balance_restriction_enabled')
    AND COALESCE((v_fee->>'direct_payment_restriction_enabled')::boolean,true);
  v_direct := NOT v_restrict OR v_outstanding < v_limit;
  RETURN jsonb_build_object(
    'ride_allowed',CASE WHEN v_method='mollie_deduction' THEN true ELSE v_direct END,
    'direct_payment_ride_allowed',v_direct,'prepaid_ride_allowed',true,
    'platform_balance_cents',GREATEST(v_outstanding,0),
    'warning_threshold_cents',v_warning,'balance_limit_cents',v_limit,
    'warning',v_outstanding>=v_warning,'collection_method',v_method,
    'reason',CASE WHEN NOT v_direct THEN 'driver_platform_balance_limit_reached' ELSE NULL END,
    'currency',v_fee->>'currency'
  );
END; $$;

DROP TRIGGER IF EXISTS trg_driver_fee_acceptance_guard ON public.ride_requests;
CREATE TRIGGER trg_driver_fee_acceptance_guard
BEFORE UPDATE OF status,driver_id ON public.ride_requests
FOR EACH ROW EXECUTE FUNCTION private.trg_driver_fee_acceptance_guard();

CREATE OR REPLACE FUNCTION public.fn_driver_can_accept_rides(p_driver_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v jsonb;
BEGIN
  v := public.fn_check_driver_payment_eligibility(p_driver_id,NULL);
  RETURN jsonb_build_object(
    'allowed',true,
    'reason',NULL,
    'status',CASE WHEN COALESCE((v->>'direct_payment_ride_allowed')::boolean,true) THEN
      CASE WHEN COALESCE((v->>'warning')::boolean,false) THEN 'WARNING' ELSE 'GOOD' END ELSE 'LOCKED' END,
    'balance_state',CASE WHEN COALESCE((v->>'direct_payment_ride_allowed')::boolean,true) THEN 'current' ELSE 'direct_payment_paused' END,
    'outstanding_cents',COALESCE((v->>'platform_balance_cents')::bigint,0),
    'limit_cents',COALESCE((v->>'balance_limit_cents')::bigint,5000),
    'remaining_cents',GREATEST(COALESCE((v->>'balance_limit_cents')::bigint,5000)-COALESCE((v->>'platform_balance_cents')::bigint,0),0),
    'currency',COALESCE(v->>'currency','EUR'),
    'direct_payment_ride_allowed',COALESCE((v->>'direct_payment_ride_allowed')::boolean,true),
    'prepaid_ride_allowed',true,
    'ride_requests_paused',false,
    'direct_payment_rides_paused',NOT COALESCE((v->>'direct_payment_ride_allowed')::boolean,true)
  );
END; $$;

REVOKE ALL ON FUNCTION public.fn_check_driver_payment_eligibility(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.fn_check_driver_payment_eligibility(uuid,uuid) TO authenticated,service_role;
REVOKE ALL ON FUNCTION public.fn_driver_can_accept_rides(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_can_accept_rides(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.fn_driver_platform_balance_ensure_weekly(
  p_driver_id uuid,p_now timestamptz DEFAULT timezone('utc',now())
)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path = '' AS $$
  SELECT jsonb_build_object('ok',true,'created_cycles',0,'retired',true);
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_billing_summary(p_driver_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_driver uuid; v_check jsonb; v_fee jsonb; v_pending_id uuid;
  v_pending_amount integer; v_pending_started timestamptz;
BEGIN
  v_driver:=COALESCE(p_driver_id,(SELECT d.id FROM public.drivers d WHERE d.user_id=auth.uid()));
  IF v_driver IS NULL THEN RETURN jsonb_build_object('ok',false,'error','not_a_driver'); END IF;
  v_check:=public.fn_driver_can_accept_rides(v_driver);
  v_fee:=public.fn_get_active_driver_service_fee(timezone('utc',now()));
  SELECT i.id,i.amount_cents,i.created_at INTO v_pending_id,v_pending_amount,v_pending_started
  FROM public.billing_checkout_intents i WHERE i.driver_id=v_driver
    AND i.checkout_kind='settlement' AND i.status='open' AND i.settlement_ledger_id IS NULL
  ORDER BY i.created_at DESC LIMIT 1;
  RETURN jsonb_build_object(
    'ok',true,'outstanding',COALESCE((v_check->>'outstanding_cents')::bigint,0),
    'limit',COALESCE((v_check->>'limit_cents')::bigint,5000),
    'remaining',COALESCE((v_check->>'remaining_cents')::bigint,0),
    'warning_threshold_cents',COALESCE((v_fee->>'warning_threshold_cents')::integer,4000),
    'currency',COALESCE(v_check->>'currency',v_fee->>'currency','EUR'),
    'country_code','NL','status',v_check->>'status','balance_state',v_check->>'balance_state',
    'allowed',true,'direct_payment_ride_allowed',(v_check->>'direct_payment_ride_allowed')::boolean,
    'prepaid_ride_allowed',true,'ride_requests_paused',false,
    'direct_payment_rides_paused',(v_check->>'direct_payment_rides_paused')::boolean,
    'platform_fee_cents',COALESCE((v_fee->>'amount_cents')::integer,0),
    'weekly_platform_balance_cents',0,'payment_pending',v_pending_id IS NOT NULL,
    'pending_payment_intent_id',v_pending_id,'pending_payment_cents',v_pending_amount,
    'pending_payment_started_at',v_pending_started
  );
END; $$;

CREATE OR REPLACE FUNCTION public.fn_driver_billing_status()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_driver uuid; v jsonb; v_outstanding bigint;
BEGIN
  SELECT d.id INTO v_driver FROM public.drivers d WHERE d.user_id=auth.uid() LIMIT 1;
  IF v_driver IS NULL THEN RETURN jsonb_build_object('ok',false,'error','not_a_driver'); END IF;
  v:=public.fn_driver_billing_summary(v_driver);
  v_outstanding:=COALESCE((v->>'outstanding')::bigint,0);
  RETURN jsonb_build_object(
    'ok',true,'billing_model','driver_service_fee_v2','payment_required',v_outstanding>0,
    'allowed',true,'status',v->>'status','balance_state',v->>'balance_state',
    'outstanding_cents',v_outstanding,'limit_cents',(v->>'limit')::bigint,
    'remaining_cents',(v->>'remaining')::bigint,
    'warning_threshold_cents',(v->>'warning_threshold_cents')::integer,
    'platform_fee_cents',(v->>'platform_fee_cents')::integer,
    'driver_service_fee_cents',(v->>'platform_fee_cents')::integer,
    'weekly_platform_balance_cents',0,'weekly_fee_cents',0,
    'currency',v->>'currency','country_code',v->>'country_code',
    'ride_requests_paused',false,
    'direct_payment_rides_paused',COALESCE((v->>'direct_payment_rides_paused')::boolean,false),
    'direct_payment_ride_allowed',COALESCE((v->>'direct_payment_ride_allowed')::boolean,true),
    'prepaid_ride_allowed',true,
    'payment_pending',COALESCE((v->>'payment_pending')::boolean,false),
    'pending_payment_intent_id',v->>'pending_payment_intent_id',
    'pending_payment_cents',CASE WHEN v->>'pending_payment_cents' IS NULL THEN NULL ELSE (v->>'pending_payment_cents')::bigint END,
    'pending_payment_started_at',v->>'pending_payment_started_at',
    'checkout_amount_cents',CASE WHEN v_outstanding>0 THEN v_outstanding END,
    'billing_status_label',CASE
      WHEN COALESCE((v->>'payment_pending')::boolean,false) THEN 'payment_pending'
      WHEN COALESCE((v->>'direct_payment_rides_paused')::boolean,false) THEN 'direct_payment_rides_paused'
      WHEN v_outstanding >= (v->>'warning_threshold_cents')::bigint THEN 'balance_warning'
      WHEN v_outstanding>0 THEN 'balance_due' ELSE 'current' END,
    'allow_one_off_checkout',v_outstanding>0,'billing_provider','platform_balance',
    'can_settle_outstanding',v_outstanding>0,'settlement_method','mollie_checkout',
    'bank_transfer_configured',false
  );
END; $$;

REVOKE ALL ON FUNCTION public.fn_driver_platform_balance_ensure_weekly(uuid,timestamptz) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.fn_driver_billing_summary(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.fn_driver_billing_status() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_platform_balance_ensure_weekly(uuid,timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_billing_summary(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_billing_status() TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.fn_finalize_completed_ride_fee(p_ride_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_ride public.ride_requests%ROWTYPE; v_s public.ride_driver_fee_snapshots%ROWTYPE; v_id uuid;
BEGIN
  IF NOT private.fn_driver_fee_flag('driver_service_fee_enabled') THEN
    RETURN jsonb_build_object('ok',true,'enabled',false);
  END IF;
  SELECT * INTO v_ride FROM public.ride_requests WHERE id=p_ride_id FOR UPDATE;
  IF v_ride.id IS NULL THEN RETURN jsonb_build_object('ok',false,'error','ride_not_found'); END IF;
  IF v_ride.status NOT IN ('completed','closed') THEN RETURN jsonb_build_object('ok',false,'error','ride_not_completed'); END IF;
  SELECT * INTO v_s FROM public.ride_driver_fee_snapshots WHERE ride_id=p_ride_id FOR UPDATE;
  IF v_s.id IS NULL THEN
    PERFORM public.fn_snapshot_driver_service_fee(p_ride_id,v_ride.driver_id);
    SELECT * INTO v_s FROM public.ride_driver_fee_snapshots WHERE ride_id=p_ride_id FOR UPDATE;
  END IF;
  IF v_s.id IS NULL OR v_s.fee_amount_cents=0 THEN RETURN jsonb_build_object('ok',true,'charged',false); END IF;
  IF v_s.collection_method='driver_platform_balance'
     AND NOT private.fn_driver_fee_flag('direct_payment_driver_balance_enabled') THEN
    RETURN jsonb_build_object('ok',true,'enabled',false);
  END IF;
  IF v_s.collection_method='mollie_deduction'
     AND NOT private.fn_driver_fee_flag('prepaid_driver_fee_deduction_enabled') THEN
    RETURN jsonb_build_object('ok',true,'enabled',false);
  END IF;
  INSERT INTO public.billing_ledger(driver_id,amount_cents,reason,ride_id,currency,country_code,metadata)
  VALUES(v_s.driver_id,v_s.fee_amount_cents,'ride_fee',p_ride_id,v_s.currency,
    COALESCE(v_ride.country_code,'NL'),jsonb_build_object('source','driver_service_fee_v2',
      'fee_snapshot_id',v_s.id,'fee_config_id',v_s.fee_config_id,'collection_method',v_s.collection_method,
      'idempotency_key','driver_fee_charge:'||p_ride_id::text))
  ON CONFLICT (ride_id,reason) WHERE reason='ride_fee' AND ride_id IS NOT NULL DO NOTHING
  RETURNING id INTO v_id;
  UPDATE public.ride_driver_fee_snapshots SET finalized_at=COALESCE(finalized_at,timezone('utc',now()))
  WHERE id=v_s.id;
  IF v_id IS NOT NULL THEN
    PERFORM public.fn_billing_audit_append(v_s.driver_id,'billing.driver_service_fee_charged',p_ride_id,
      jsonb_build_object('ledger_id',v_id,'amount_cents',v_s.fee_amount_cents,
        'collection_method',v_s.collection_method),p_ride_id);
  END IF;
  RETURN jsonb_build_object('ok',true,'charged',v_id IS NOT NULL,'idempotent_replay',v_id IS NULL,
    'collection_method',v_s.collection_method,'service_fee_cents',v_s.fee_amount_cents);
END; $$;

-- Preserve the existing completion trigger's canonical call path.
CREATE OR REPLACE FUNCTION public.fn_billing_accrue_ride_fee(
  p_ride_id uuid,p_driver_id uuid,p_country_code text DEFAULT 'NL',
  p_city_id uuid DEFAULT NULL,p_zone_id uuid DEFAULT NULL
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_result jsonb; v_id uuid;
BEGIN
  v_result := public.fn_finalize_completed_ride_fee(p_ride_id);
  SELECT id INTO v_id FROM public.billing_ledger
  WHERE ride_id=p_ride_id AND reason='ride_fee' LIMIT 1;
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.fn_collect_prepaid_driver_service_fee(
  p_ride_id uuid,p_ride_payment_id uuid
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_s public.ride_driver_fee_snapshots%ROWTYPE; v_p public.ride_payments%ROWTYPE; v_id uuid;
BEGIN
  SELECT * INTO v_p FROM public.ride_payments WHERE id=p_ride_payment_id AND ride_id=p_ride_id FOR UPDATE;
  IF v_p.id IS NULL THEN RETURN jsonb_build_object('ok',false,'error','payment_not_found'); END IF;
  IF v_p.state<>'routed' THEN RETURN jsonb_build_object('ok',false,'error','payment_not_routed'); END IF;
  SELECT * INTO v_s FROM public.ride_driver_fee_snapshots WHERE ride_id=p_ride_id;
  IF v_s.id IS NULL OR v_s.collection_method<>'mollie_deduction' THEN
    RETURN jsonb_build_object('ok',false,'error','prepaid_fee_snapshot_missing');
  END IF;
  PERFORM public.fn_finalize_completed_ride_fee(p_ride_id);
  INSERT INTO public.billing_ledger(driver_id,amount_cents,reason,ride_id,currency,country_code,metadata)
  VALUES(v_s.driver_id,-v_s.fee_amount_cents,'prepaid_fee_collection',p_ride_id,v_s.currency,'NL',
    jsonb_build_object('source','mollie_route','ride_payment_id',p_ride_payment_id,
      'idempotency_key','prepaid_driver_fee:'||p_ride_id::text))
  ON CONFLICT DO NOTHING RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok',true,'collected',v_id IS NOT NULL,'idempotent_replay',v_id IS NULL);
END; $$;

CREATE UNIQUE INDEX IF NOT EXISTS billing_ledger_one_prepaid_collection_per_ride
  ON public.billing_ledger(ride_id,reason)
  WHERE reason='prepaid_fee_collection' AND ride_id IS NOT NULL;

REVOKE ALL ON FUNCTION public.fn_finalize_completed_ride_fee(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.fn_billing_accrue_ride_fee(uuid,uuid,text,uuid,uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.fn_collect_prepaid_driver_service_fee(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.fn_finalize_completed_ride_fee(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_billing_accrue_ride_fee(uuid,uuid,text,uuid,uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_collect_prepaid_driver_service_fee(uuid,uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.fn_admin_driver_service_fee_config()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_actor public.admin_users; v_active jsonb; v_history jsonb;
BEGIN
  v_actor := private.fn_admin_os_actor('finance.manage',false);
  v_active := public.fn_get_active_driver_service_fee(timezone('utc',now()));
  SELECT COALESCE(jsonb_agg(to_jsonb(f) ORDER BY f.effective_from DESC),'[]'::jsonb)
    INTO v_history FROM public.driver_service_fee_versions f;
  RETURN jsonb_build_object('ok',true,'active',v_active,'history',v_history,
    'flags',(SELECT COALESCE(NULLIF(value,'')::jsonb,'{}'::jsonb) FROM public.app_config WHERE key='feature_flags'));
END; $$;

CREATE OR REPLACE FUNCTION public.fn_admin_schedule_driver_service_fee_change(
  p_fee_type text,p_amount_cents integer,p_percentage_basis_points integer,
  p_effective_from timestamptz,p_reason text,
  p_warning_threshold_cents integer DEFAULT 4000,p_balance_limit_cents integer DEFAULT 5000
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_actor public.admin_users; v_old public.driver_service_fee_versions%ROWTYPE; v_new uuid;
BEGIN
  v_actor := private.fn_admin_os_actor('finance.manage',true);
  IF p_effective_from <= timezone('utc',now()) OR char_length(btrim(COALESCE(p_reason,'')))<8 THEN
    RETURN jsonb_build_object('ok',false,'error','future_effective_date_and_reason_required');
  END IF;
  IF p_fee_type NOT IN ('fixed','percentage') OR p_warning_threshold_cents<0
     OR p_balance_limit_cents<=0 OR p_warning_threshold_cents>p_balance_limit_cents THEN
    RETURN jsonb_build_object('ok',false,'error','invalid_fee_configuration');
  END IF;
  SELECT * INTO v_old FROM public.driver_service_fee_versions
  WHERE fee_code='HEYCABY_DRIVER_SERVICE_FEE' AND is_active
    AND effective_from<=p_effective_from AND (effective_until IS NULL OR effective_until>p_effective_from)
  ORDER BY effective_from DESC LIMIT 1 FOR UPDATE;
  IF v_old.id IS NOT NULL THEN
    UPDATE public.driver_service_fee_versions SET effective_until=p_effective_from WHERE id=v_old.id;
  END IF;
  INSERT INTO public.driver_service_fee_versions(
    fee_type,amount_cents,percentage_basis_points,effective_from,reason,created_by,
    warning_threshold_cents,balance_limit_cents
  ) VALUES(p_fee_type,CASE WHEN p_fee_type='fixed' THEN p_amount_cents END,
    CASE WHEN p_fee_type='percentage' THEN p_percentage_basis_points END,
    p_effective_from,btrim(p_reason),v_actor.user_id,p_warning_threshold_cents,p_balance_limit_cents)
  RETURNING id INTO v_new;
  PERFORM private.fn_admin_os_audit(v_actor,'driver_service_fee.schedule','driver_service_fee',v_new::text,
    jsonb_build_object('previous_config_id',v_old.id,'effective_from',p_effective_from,
      'fee_type',p_fee_type,'amount_cents',p_amount_cents,'percentage_basis_points',p_percentage_basis_points,
      'reason',btrim(p_reason)));
  RETURN jsonb_build_object('ok',true,'config_id',v_new,'effective_from',p_effective_from);
END; $$;

REVOKE ALL ON FUNCTION public.fn_admin_driver_service_fee_config() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.fn_admin_schedule_driver_service_fee_change(text,integer,integer,timestamptz,text,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.fn_admin_driver_service_fee_config() TO authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.fn_admin_schedule_driver_service_fee_change(text,integer,integer,timestamptz,text,integer,integer) TO authenticated,service_role;

COMMENT ON TABLE public.driver_service_fee_versions IS
  'Versioned Finance-owned Driver Service Fee configuration. Never update historical price fields.';
COMMENT ON TABLE public.ride_driver_fee_snapshots IS
  'Immutable fee and earnings quote frozen for a ride when the Driver accepts.';
