-- Platform Balance: permanent driver payment references and bank-transfer
-- reconciliation. This extends the existing weekly ledger and Mollie checkout;
-- it does not replace either contract.

CREATE OR REPLACE FUNCTION public.fn_platform_payment_reference_normalize(
  p_reference text
)
RETURNS text
LANGUAGE sql
IMMUTABLE
STRICT
PARALLEL SAFE
SET search_path = public
AS $$
  SELECT NULLIF(regexp_replace(upper(btrim(p_reference)), '[^A-Z0-9]', '', 'g'), '');
$$;

ALTER TABLE public.driver_platform_balance_accounts
  ADD COLUMN IF NOT EXISTS platform_payment_reference text,
  ADD COLUMN IF NOT EXISTS payment_reference_source_plate text,
  ADD COLUMN IF NOT EXISTS payment_reference_created_at timestamptz,
  ADD COLUMN IF NOT EXISTS payment_reference_first_used_at timestamptz;

CREATE UNIQUE INDEX IF NOT EXISTS
  driver_platform_balance_accounts_payment_reference_uidx
ON public.driver_platform_balance_accounts (
  public.fn_platform_payment_reference_normalize(platform_payment_reference)
)
WHERE platform_payment_reference IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.driver_platform_payment_reference_aliases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES public.drivers(id) ON DELETE RESTRICT,
  reference text NOT NULL,
  normalized_reference text NOT NULL,
  is_primary boolean NOT NULL DEFAULT false,
  first_used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT driver_platform_payment_reference_aliases_reference_not_blank
    CHECK (btrim(reference) <> ''),
  CONSTRAINT driver_platform_payment_reference_aliases_normalized_not_blank
    CHECK (btrim(normalized_reference) <> '')
);

CREATE UNIQUE INDEX IF NOT EXISTS
  driver_platform_payment_reference_aliases_normalized_uidx
ON public.driver_platform_payment_reference_aliases (normalized_reference);

CREATE INDEX IF NOT EXISTS
  driver_platform_payment_reference_aliases_driver_idx
ON public.driver_platform_payment_reference_aliases (driver_id, created_at DESC);

ALTER TABLE public.driver_platform_payment_reference_aliases ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.fn_platform_payment_reference_immutable()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.platform_payment_reference IS NOT NULL
     AND NEW.platform_payment_reference IS DISTINCT FROM OLD.platform_payment_reference THEN
    RAISE EXCEPTION 'platform_payment_reference_is_immutable';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_platform_payment_reference_immutable
ON public.driver_platform_balance_accounts;

CREATE TRIGGER trg_platform_payment_reference_immutable
BEFORE UPDATE OF platform_payment_reference
ON public.driver_platform_balance_accounts
FOR EACH ROW
EXECUTE FUNCTION public.fn_platform_payment_reference_immutable();

CREATE OR REPLACE FUNCTION public.fn_driver_platform_payment_reference_ensure(
  p_driver_id uuid
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_plate text;
  v_plate_normalized text;
  v_reference text;
  v_normalized text;
  v_existing text;
  v_suffix text;
  v_suffix_length integer := 3;
BEGIN
  IF p_driver_id IS NULL THEN
    RETURN NULL;
  END IF;

  INSERT INTO public.driver_platform_balance_accounts (driver_id)
  VALUES (p_driver_id)
  ON CONFLICT (driver_id) DO NOTHING;

  SELECT a.platform_payment_reference
  INTO v_existing
  FROM public.driver_platform_balance_accounts a
  WHERE a.driver_id = p_driver_id
  FOR UPDATE;

  IF v_existing IS NOT NULL THEN
    RETURN v_existing;
  END IF;

  SELECT d.vehicle_plate
  INTO v_plate
  FROM public.drivers d
  WHERE d.id = p_driver_id;

  v_plate_normalized := public.fn_platform_payment_reference_normalize(v_plate);
  IF v_plate_normalized IS NULL THEN
    RETURN NULL;
  END IF;

  v_reference := 'HC-' || v_plate_normalized;
  v_normalized := public.fn_platform_payment_reference_normalize(v_reference);

  WHILE EXISTS (
    SELECT 1
    FROM public.driver_platform_payment_reference_aliases a
    WHERE a.normalized_reference = v_normalized
      AND a.driver_id <> p_driver_id
  ) OR EXISTS (
    SELECT 1
    FROM public.driver_platform_balance_accounts a
    WHERE public.fn_platform_payment_reference_normalize(a.platform_payment_reference) = v_normalized
      AND a.driver_id <> p_driver_id
  ) LOOP
    v_suffix := upper(substr(replace(p_driver_id::text, '-', ''), 1, v_suffix_length));
    v_reference := 'HC-' || v_plate_normalized || '-' || v_suffix;
    v_normalized := public.fn_platform_payment_reference_normalize(v_reference);
    v_suffix_length := v_suffix_length + 1;
    IF v_suffix_length > 12 THEN
      RAISE EXCEPTION 'platform_payment_reference_collision';
    END IF;
  END LOOP;

  UPDATE public.driver_platform_balance_accounts
  SET
    platform_payment_reference = v_reference,
    payment_reference_source_plate = v_plate_normalized,
    payment_reference_created_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  WHERE driver_id = p_driver_id
    AND platform_payment_reference IS NULL;

  INSERT INTO public.driver_platform_payment_reference_aliases (
    driver_id,
    reference,
    normalized_reference,
    is_primary
  ) VALUES (
    p_driver_id,
    v_reference,
    v_normalized,
    true
  )
  ON CONFLICT (normalized_reference) DO NOTHING;

  RETURN v_reference;
END;
$$;

DO $$
DECLARE
  v_driver_id uuid;
BEGIN
  FOR v_driver_id IN
    SELECT a.driver_id
    FROM public.driver_platform_balance_accounts a
    JOIN public.drivers d ON d.id = a.driver_id
    WHERE a.platform_payment_reference IS NULL
      AND public.fn_platform_payment_reference_normalize(d.vehicle_plate) IS NOT NULL
  LOOP
    PERFORM public.fn_driver_platform_payment_reference_ensure(v_driver_id);
  END LOOP;
END;
$$;

CREATE TABLE IF NOT EXISTS public.billing_bank_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider text NOT NULL,
  external_transaction_id text NOT NULL,
  booked_at timestamptz NOT NULL,
  amount_cents integer NOT NULL CHECK (amount_cents > 0),
  currency text NOT NULL DEFAULT 'EUR',
  raw_reference text,
  normalized_reference text,
  matched_driver_id uuid REFERENCES public.drivers(id) ON DELETE RESTRICT,
  settlement_ledger_id uuid REFERENCES public.billing_ledger(id) ON DELETE RESTRICT,
  applied_cents integer NOT NULL DEFAULT 0 CHECK (applied_cents >= 0),
  unapplied_cents integer NOT NULL DEFAULT 0 CHECK (unapplied_cents >= 0),
  status text NOT NULL DEFAULT 'received' CHECK (
    status IN ('received', 'unmatched', 'settled', 'partially_settled', 'manual_review')
  ),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (provider, external_transaction_id)
);

CREATE INDEX IF NOT EXISTS billing_bank_transactions_reference_idx
ON public.billing_bank_transactions (normalized_reference, booked_at DESC);

CREATE INDEX IF NOT EXISTS billing_bank_transactions_driver_idx
ON public.billing_bank_transactions (matched_driver_id, booked_at DESC)
WHERE matched_driver_id IS NOT NULL;

ALTER TABLE public.billing_bank_transactions ENABLE ROW LEVEL SECURITY;

INSERT INTO public.market_config (
  scope,
  country_code,
  city_id,
  zone_id,
  config_key,
  config_value,
  active
)
SELECT
  'country',
  'NL',
  NULL,
  NULL,
  'platform_balance_bank_transfer',
  jsonb_build_object('enabled', false),
  true
WHERE NOT EXISTS (
  SELECT 1
  FROM public.market_config mc
  WHERE mc.scope = 'country'
    AND mc.country_code = 'NL'
    AND mc.config_key = 'platform_balance_bank_transfer'
    AND mc.active = true
);

CREATE OR REPLACE FUNCTION public.fn_driver_billing_reconcile_bank_transaction(
  p_provider text,
  p_external_transaction_id text,
  p_amount_cents integer,
  p_currency text,
  p_reference text,
  p_booked_at timestamptz DEFAULT timezone('utc', now()),
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_provider text := lower(btrim(COALESCE(p_provider, 'bank_import')));
  v_external_id text := btrim(COALESCE(p_external_transaction_id, ''));
  v_currency text := upper(btrim(COALESCE(p_currency, 'EUR')));
  v_normalized_reference text;
  v_transaction_id uuid;
  v_driver_id uuid;
  v_driver_user_id uuid;
  v_result jsonb;
  v_ledger_id uuid;
  v_applied_cents integer := 0;
  v_unapplied_cents integer := 0;
  v_status text;
  v_existing record;
  v_eligibility jsonb;
BEGIN
  IF v_external_id = '' OR p_amount_cents IS NULL OR p_amount_cents <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_input');
  END IF;

  v_normalized_reference := public.fn_platform_payment_reference_normalize(p_reference);

  INSERT INTO public.billing_bank_transactions (
    provider,
    external_transaction_id,
    booked_at,
    amount_cents,
    currency,
    raw_reference,
    normalized_reference,
    metadata
  ) VALUES (
    v_provider,
    v_external_id,
    COALESCE(p_booked_at, timezone('utc', now())),
    p_amount_cents,
    v_currency,
    p_reference,
    v_normalized_reference,
    COALESCE(p_metadata, '{}'::jsonb)
  )
  ON CONFLICT (provider, external_transaction_id) DO NOTHING
  RETURNING id INTO v_transaction_id;

  IF v_transaction_id IS NULL THEN
    SELECT * INTO v_existing
    FROM public.billing_bank_transactions bbt
    WHERE bbt.provider = v_provider
      AND bbt.external_transaction_id = v_external_id;

    RETURN jsonb_build_object(
      'ok', true,
      'idempotent_replay', true,
      'transaction_id', v_existing.id,
      'status', v_existing.status,
      'driver_id', v_existing.matched_driver_id,
      'settlement_ledger_id', v_existing.settlement_ledger_id,
      'applied_cents', v_existing.applied_cents,
      'unapplied_cents', v_existing.unapplied_cents
    );
  END IF;

  IF v_normalized_reference IS NULL THEN
    UPDATE public.billing_bank_transactions
    SET status = 'unmatched', updated_at = timezone('utc', now())
    WHERE id = v_transaction_id;
    RETURN jsonb_build_object(
      'ok', true,
      'transaction_id', v_transaction_id,
      'status', 'unmatched',
      'reason', 'missing_reference'
    );
  END IF;

  SELECT a.driver_id
  INTO v_driver_id
  FROM public.driver_platform_payment_reference_aliases a
  WHERE a.normalized_reference = v_normalized_reference
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    UPDATE public.billing_bank_transactions
    SET status = 'unmatched', updated_at = timezone('utc', now())
    WHERE id = v_transaction_id;
    RETURN jsonb_build_object(
      'ok', true,
      'transaction_id', v_transaction_id,
      'status', 'unmatched',
      'reason', 'reference_not_found'
    );
  END IF;

  SELECT d.user_id INTO v_driver_user_id
  FROM public.drivers d
  WHERE d.id = v_driver_id;

  IF v_currency <> 'EUR' THEN
    UPDATE public.billing_bank_transactions
    SET
      matched_driver_id = v_driver_id,
      unapplied_cents = p_amount_cents,
      status = 'manual_review',
      updated_at = timezone('utc', now())
    WHERE id = v_transaction_id;
    RETURN jsonb_build_object(
      'ok', true,
      'transaction_id', v_transaction_id,
      'status', 'manual_review',
      'reason', 'currency_mismatch',
      'driver_id', v_driver_id
    );
  END IF;

  v_result := public.fn_driver_billing_apply_settlement(
    v_driver_id,
    p_amount_cents,
    v_provider,
    v_provider || ':' || v_external_id,
    COALESCE(p_metadata, '{}'::jsonb) || jsonb_build_object(
      'bank_transaction_id', v_transaction_id,
      'raw_reference', p_reference,
      'normalized_reference', v_normalized_reference,
      'booked_at', p_booked_at
    )
  );

  IF COALESCE((v_result->>'ok')::boolean, false) THEN
    v_ledger_id := NULLIF(v_result->>'ledger_id', '')::uuid;
    v_applied_cents := COALESCE((v_result->>'settled_cents')::integer, 0);
    v_unapplied_cents := GREATEST(p_amount_cents - v_applied_cents, 0);
    v_status := CASE
      WHEN v_applied_cents = p_amount_cents THEN 'settled'
      WHEN v_applied_cents > 0 THEN 'partially_settled'
      ELSE 'manual_review'
    END;
  ELSE
    v_applied_cents := 0;
    v_unapplied_cents := p_amount_cents;
    v_status := 'manual_review';
  END IF;

  UPDATE public.billing_bank_transactions
  SET
    matched_driver_id = v_driver_id,
    settlement_ledger_id = v_ledger_id,
    applied_cents = v_applied_cents,
    unapplied_cents = v_unapplied_cents,
    status = v_status,
    metadata = metadata || jsonb_build_object('settlement_result', v_result),
    updated_at = timezone('utc', now())
  WHERE id = v_transaction_id;

  IF v_applied_cents > 0 THEN
    UPDATE public.driver_platform_balance_accounts
    SET
      payment_reference_first_used_at = COALESCE(
        payment_reference_first_used_at,
        timezone('utc', now())
      ),
      updated_at = timezone('utc', now())
    WHERE driver_id = v_driver_id;

    UPDATE public.driver_platform_payment_reference_aliases
    SET first_used_at = COALESCE(first_used_at, timezone('utc', now()))
    WHERE driver_id = v_driver_id
      AND normalized_reference = v_normalized_reference;

    IF v_driver_user_id IS NOT NULL THEN
      INSERT INTO public.notifications (
        user_type,
        user_id,
        agent,
        category,
        title,
        body,
        data,
        priority,
        channel
      ) VALUES (
        'driver',
        v_driver_user_id::text,
        'driver_agent',
        'platform_balance_settled',
        'Platform Balance updated',
        CASE
          WHEN v_unapplied_cents > 0
            THEN 'Your transfer was received. Any surplus is being reviewed.'
          ELSE 'Your bank transfer was received and applied to your Platform Balance.'
        END,
        jsonb_build_object(
          'screen', 'platform_balance',
          'notification_type', 'platform_balance_settled',
          'transaction_id', v_transaction_id,
          'applied_cents', v_applied_cents,
          'unapplied_cents', v_unapplied_cents
        ),
        'high',
        'both'
      );
    END IF;

    PERFORM public.fn_billing_audit_append(
      v_driver_id,
      'billing.bank_transfer_reconciled',
      NULL,
      jsonb_build_object(
        'transaction_id', v_transaction_id,
        'provider', v_provider,
        'external_transaction_id', v_external_id,
        'applied_cents', v_applied_cents,
        'unapplied_cents', v_unapplied_cents,
        'settlement_ledger_id', v_ledger_id,
        'normalized_reference', v_normalized_reference
      )
    );
  END IF;

  v_eligibility := public.fn_driver_can_accept_rides(v_driver_id);

  RETURN jsonb_build_object(
    'ok', true,
    'transaction_id', v_transaction_id,
    'status', v_status,
    'driver_id', v_driver_id,
    'settlement_ledger_id', v_ledger_id,
    'applied_cents', v_applied_cents,
    'unapplied_cents', v_unapplied_cents,
    'ride_eligibility', v_eligibility
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
  v_payment_reference text;
  v_bank_config jsonb;
  v_bank_configured boolean := false;
BEGIN
  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  PERFORM public.fn_driver_platform_balance_ensure_weekly(v_driver_id);
  v_payment_reference := public.fn_driver_platform_payment_reference_ensure(v_driver_id);

  v_summary := public.fn_driver_billing_summary(v_driver_id);
  v_status := COALESCE(v_summary->>'status', 'GOOD');
  v_balance_state := COALESCE(v_summary->>'balance_state', 'current');
  v_allowed := COALESCE((v_summary->>'allowed')::boolean, true);
  v_outstanding := COALESCE((v_summary->>'outstanding')::bigint, 0);
  v_amount := COALESCE((v_summary->>'weekly_platform_balance_cents')::bigint, 5000);
  v_currency := COALESCE(NULLIF(btrim(v_summary->>'currency'), ''), 'EUR');
  v_payment_pending := COALESCE((v_summary->>'payment_pending')::boolean, false);

  v_bank_config := public.fn_get_market_config(
    'platform_balance_bank_transfer',
    COALESCE(v_summary->>'country_code', 'NL'),
    NULL,
    NULL
  );

  v_bank_configured := COALESCE((v_bank_config->>'enabled')::boolean, false)
    AND NULLIF(btrim(v_bank_config->>'account_holder'), '') IS NOT NULL
    AND NULLIF(btrim(v_bank_config->>'iban'), '') IS NOT NULL
    AND NULLIF(btrim(v_bank_config->>'bank_name'), '') IS NOT NULL
    AND NULLIF(btrim(v_bank_config->>'bic'), '') IS NOT NULL
    AND v_payment_reference IS NOT NULL;

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
    'can_settle_outstanding', v_outstanding > 0,
    'settlement_method', CASE
      WHEN v_bank_configured THEN 'bank_transfer'
      ELSE 'mollie_checkout'
    END,
    'bank_transfer_configured', v_bank_configured,
    'platform_payment_reference', v_payment_reference,
    'bank_transfer', CASE
      WHEN v_bank_configured THEN jsonb_build_object(
        'account_holder', v_bank_config->>'account_holder',
        'iban', v_bank_config->>'iban',
        'bank_name', v_bank_config->>'bank_name',
        'bic', v_bank_config->>'bic',
        'reference', v_payment_reference
      )
      ELSE NULL
    END
  );
END;
$$;

-- Repair inherited CREATE OR REPLACE grants. Only the two own-driver read RPCs
-- remain client-callable; all arbitrary-driver readers and writers are service-only.
REVOKE ALL ON FUNCTION public.fn_driver_billing_status() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_billing_status() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.fn_driver_billing_ledger_history(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_billing_ledger_history(integer) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.fn_billing_audit_append(uuid, text, uuid, jsonb, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_billing_audit_append(uuid, text, uuid, jsonb, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.fn_driver_billing_apply_settlement(uuid, integer, text, text, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_billing_apply_settlement(uuid, integer, text, text, jsonb) TO service_role;

REVOKE ALL ON FUNCTION public.fn_driver_billing_summary(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_billing_summary(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.fn_driver_can_accept_rides(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_can_accept_rides(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.fn_driver_platform_balance_ensure_weekly(uuid, timestamptz) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_platform_balance_ensure_weekly(uuid, timestamptz) TO service_role;

REVOKE ALL ON FUNCTION public.fn_driver_platform_balance_latest_open(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_platform_balance_latest_open(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.fn_driver_billing_checkout_intent_by_payment(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_billing_checkout_intent_by_payment(text) TO service_role;

REVOKE ALL ON FUNCTION public.fn_driver_billing_record_checkout_intent(uuid, integer, text, text, text, text, text, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_billing_record_checkout_intent(uuid, integer, text, text, text, text, text, jsonb) TO service_role;

REVOKE ALL ON FUNCTION public.fn_platform_payment_reference_normalize(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_platform_payment_reference_normalize(text) TO service_role;

REVOKE ALL ON FUNCTION public.fn_platform_payment_reference_immutable() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_driver_platform_payment_reference_ensure(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_platform_payment_reference_ensure(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.fn_driver_billing_reconcile_bank_transaction(text, text, integer, text, text, timestamptz, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_billing_reconcile_bank_transaction(text, text, integer, text, text, timestamptz, jsonb) TO service_role;

REVOKE ALL ON TABLE public.driver_platform_payment_reference_aliases FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.driver_platform_payment_reference_aliases TO service_role;

REVOKE ALL ON TABLE public.billing_bank_transactions FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.billing_bank_transactions TO service_role;

COMMENT ON COLUMN public.driver_platform_balance_accounts.platform_payment_reference IS
  'Permanent, server-generated Platform Balance bank-transfer reference. Never reassigned after creation.';
COMMENT ON TABLE public.billing_bank_transactions IS
  'Idempotent service-role import and reconciliation journal for Platform Balance bank transfers.';
COMMENT ON FUNCTION public.fn_driver_billing_reconcile_bank_transaction(text, text, integer, text, text, timestamptz, jsonb) IS
  'Service-role-only bank transaction reconciliation. Matches permanent reference, appends one settlement, and returns recalculated ride eligibility.';
