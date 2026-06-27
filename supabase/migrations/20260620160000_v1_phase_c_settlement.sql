-- Phase C completion — ledger settlement (Mollie checkout + apply settlement RPC).
-- Edge Functions call service_role RPCs; Flutter invokes Edge instead of Go HTTP.

-- ---------------------------------------------------------------------------
-- Checkout intents (Mollie payment tracking + idempotent settlement)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.billing_checkout_intents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  amount_cents integer NOT NULL CHECK (amount_cents > 0),
  currency text NOT NULL DEFAULT 'EUR',
  country_code text NOT NULL DEFAULT 'NL',
  provider text NOT NULL DEFAULT 'mollie',
  external_payment_id text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (
    status IN ('open', 'paid', 'failed', 'canceled', 'cancelled', 'expired')
  ),
  checkout_kind text NOT NULL DEFAULT 'settlement' CHECK (
    checkout_kind IN ('settlement', 'subscription')
  ),
  plan_code text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  settlement_ledger_id uuid REFERENCES public.billing_ledger(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT billing_checkout_intents_provider_payment UNIQUE (provider, external_payment_id)
);

CREATE INDEX IF NOT EXISTS idx_billing_checkout_intents_driver_created
  ON public.billing_checkout_intents (driver_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_billing_checkout_intents_status
  ON public.billing_checkout_intents (status, created_at DESC)
  WHERE status = 'open';

ALTER TABLE public.billing_checkout_intents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS billing_checkout_intents_driver_select ON public.billing_checkout_intents;
CREATE POLICY billing_checkout_intents_driver_select
  ON public.billing_checkout_intents
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.drivers d
      WHERE d.id = billing_checkout_intents.driver_id AND d.user_id = auth.uid()
    )
  );

COMMENT ON TABLE public.billing_checkout_intents IS
  'Phase C: Mollie checkout sessions for ledger settlement (and legacy subscription one-offs).';

-- ---------------------------------------------------------------------------
-- Apply settlement (service_role / Edge only)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_billing_apply_settlement(
  p_driver_id uuid,
  p_paid_cents integer,
  p_provider text,
  p_external_id text,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_outstanding bigint;
  v_settle_cents integer;
  v_ledger_id uuid;
  v_market record;
  v_meta jsonb;
BEGIN
  IF p_driver_id IS NULL OR p_paid_cents IS NULL OR p_paid_cents <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_input');
  END IF;
  IF p_external_id IS NULL OR btrim(p_external_id) = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_external_id');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.billing_ledger bl
    WHERE bl.driver_id = p_driver_id
      AND bl.reason = 'settlement'
      AND bl.metadata->>'external_id' = p_external_id
  ) THEN
    SELECT bl.id INTO v_ledger_id
    FROM public.billing_ledger bl
    WHERE bl.driver_id = p_driver_id
      AND bl.reason = 'settlement'
      AND bl.metadata->>'external_id' = p_external_id
    LIMIT 1;
    RETURN jsonb_build_object(
      'ok', true,
      'already_settled', true,
      'ledger_id', v_ledger_id
    );
  END IF;

  v_outstanding := public.fn_billing_driver_outstanding_cents(p_driver_id);
  IF v_outstanding <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'nothing_to_settle');
  END IF;

  v_settle_cents := LEAST(p_paid_cents, v_outstanding::integer);
  IF v_settle_cents <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_settlement_amount');
  END IF;

  SELECT * INTO v_market
  FROM public.fn_billing_resolve_driver_market(p_driver_id) m
  LIMIT 1;

  v_meta := COALESCE(p_metadata, '{}'::jsonb) || jsonb_build_object(
    'external_id', p_external_id,
    'provider', COALESCE(NULLIF(btrim(p_provider), ''), 'mollie'),
    'paid_cents', p_paid_cents,
    'settled_cents', v_settle_cents
  );

  INSERT INTO public.billing_ledger (
    driver_id,
    amount_cents,
    reason,
    currency,
    country_code,
    metadata
  )
  VALUES (
    p_driver_id,
    -v_settle_cents,
    'settlement',
    COALESCE(v_market.currency, 'EUR'),
    COALESCE(v_market.country_code, 'NL'),
    v_meta
  )
  RETURNING id INTO v_ledger_id;

  PERFORM public.fn_billing_audit_append(
    p_driver_id,
    'billing.payment_received',
    NULL,
    jsonb_build_object(
      'provider', COALESCE(NULLIF(btrim(p_provider), ''), 'mollie'),
      'external_id', p_external_id,
      'settled_cents', v_settle_cents,
      'ledger_id', v_ledger_id
    )
  );

  UPDATE public.billing_checkout_intents bci
  SET
    status = 'paid',
    settlement_ledger_id = v_ledger_id,
    updated_at = timezone('utc', now())
  WHERE bci.provider = COALESCE(NULLIF(btrim(p_provider), ''), 'mollie')
    AND bci.external_payment_id = p_external_id;

  RETURN jsonb_build_object(
    'ok', true,
    'ledger_id', v_ledger_id,
    'settled_cents', v_settle_cents,
    'outstanding_after', public.fn_billing_driver_outstanding_cents(p_driver_id)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_billing_apply_settlement(uuid, integer, text, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_billing_apply_settlement(uuid, integer, text, text, jsonb) TO service_role;

-- ---------------------------------------------------------------------------
-- Record checkout intent (service_role / Edge only)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_billing_record_checkout_intent(
  p_driver_id uuid,
  p_amount_cents integer,
  p_external_payment_id text,
  p_checkout_kind text DEFAULT 'settlement',
  p_plan_code text DEFAULT NULL,
  p_currency text DEFAULT 'EUR',
  p_country_code text DEFAULT 'NL',
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF p_driver_id IS NULL OR p_amount_cents IS NULL OR p_amount_cents <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_input');
  END IF;
  IF p_external_payment_id IS NULL OR btrim(p_external_payment_id) = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_payment_id');
  END IF;

  INSERT INTO public.billing_checkout_intents (
    driver_id,
    amount_cents,
    currency,
    country_code,
    external_payment_id,
    checkout_kind,
    plan_code,
    metadata
  )
  VALUES (
    p_driver_id,
    p_amount_cents,
    COALESCE(NULLIF(btrim(p_currency), ''), 'EUR'),
    COALESCE(NULLIF(btrim(p_country_code), ''), 'NL'),
    btrim(p_external_payment_id),
    COALESCE(NULLIF(btrim(p_checkout_kind), ''), 'settlement'),
    NULLIF(btrim(p_plan_code), ''),
    COALESCE(p_metadata, '{}'::jsonb)
  )
  ON CONFLICT (provider, external_payment_id) DO UPDATE
  SET
    amount_cents = EXCLUDED.amount_cents,
    metadata = billing_checkout_intents.metadata || EXCLUDED.metadata,
    updated_at = timezone('utc', now())
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('ok', true, 'intent_id', v_id);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_billing_record_checkout_intent(uuid, integer, text, text, text, text, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_billing_record_checkout_intent(uuid, integer, text, text, text, text, text, jsonb) TO service_role;

-- ---------------------------------------------------------------------------
-- Resolve intent by Mollie id (service_role / Edge only)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_billing_checkout_intent_by_payment(
  p_external_payment_id text
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.billing_checkout_intents%ROWTYPE;
BEGIN
  SELECT * INTO v_row
  FROM public.billing_checkout_intents bci
  WHERE bci.provider = 'mollie'
    AND bci.external_payment_id = btrim(p_external_payment_id)
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_found');
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'intent_id', v_row.id,
    'driver_id', v_row.driver_id,
    'amount_cents', v_row.amount_cents,
    'status', v_row.status,
    'checkout_kind', v_row.checkout_kind,
    'plan_code', v_row.plan_code,
    'settlement_ledger_id', v_row.settlement_ledger_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_billing_checkout_intent_by_payment(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_billing_checkout_intent_by_payment(text) TO service_role;

-- ---------------------------------------------------------------------------
-- UI status: expose checkout amount for ledger settlement
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_billing_status()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_summary jsonb;
  v_status text;
  v_allowed boolean;
  v_outstanding bigint;
  v_limit bigint;
  v_remaining bigint;
  v_fee_cents bigint;
  v_currency text;
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
  v_allowed := COALESCE((v_summary->>'allowed')::boolean, true);
  v_outstanding := COALESCE((v_summary->>'outstanding')::bigint, 0);
  v_limit := COALESCE((v_summary->>'limit')::bigint, 0);
  v_remaining := COALESCE((v_summary->>'remaining')::bigint, 0);
  v_fee_cents := COALESCE((v_summary->>'platform_fee_cents')::bigint, 100);
  v_currency := COALESCE(NULLIF(btrim(v_summary->>'currency'), ''), 'EUR');

  RETURN jsonb_build_object(
    'ok', true,
    'billing_model', 'ledger_v1',
    'payment_required', NOT v_allowed,
    'allowed', v_allowed,
    'status', v_status,
    'outstanding_cents', v_outstanding,
    'limit_cents', v_limit,
    'remaining_cents', v_remaining,
    'platform_fee_cents', v_fee_cents,
    'weekly_fee_cents', v_fee_cents,
    'currency', v_currency,
    'country_code', v_summary->>'country_code',
    'checkout_amount_cents', CASE WHEN v_outstanding > 0 THEN v_outstanding ELSE NULL END,
    'billing_status_label', CASE v_status
      WHEN 'LOCKED' THEN 'payment_required'
      WHEN 'WARNING' THEN 'approaching_limit'
      ELSE 'good_standing'
    END,
    'show_subscription_controls', false,
    'allow_one_off_checkout', v_outstanding > 0,
    'billing_provider', 'ledger',
    'can_settle_outstanding', v_outstanding > 0
  );
END;
$$;

COMMENT ON FUNCTION public.fn_driver_billing_apply_settlement(uuid, integer, text, text, jsonb) IS
  'Phase C: idempotent ledger settlement after Mollie/Apple payment confirmation.';
COMMENT ON FUNCTION public.fn_driver_billing_record_checkout_intent(uuid, integer, text, text, text, text, text, jsonb) IS
  'Phase C: persist Mollie checkout intent before redirect.';
