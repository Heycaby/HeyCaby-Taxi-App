-- Remove the final legacy subscription-control compatibility flag from the
-- active Platform Balance status contract. Flutter no longer reads it, and the
-- driver-facing/product contract is settlement-only Platform Balance.

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
    'ride_requests_paused', COALESCE((v_summary->>'ride_requests_paused')::boolean, false),
    'payment_pending', v_payment_pending,
    'pending_payment_intent_id', v_summary->>'pending_payment_intent_id',
    'pending_payment_cents', CASE WHEN v_summary->>'pending_payment_cents' IS NULL THEN NULL ELSE (v_summary->>'pending_payment_cents')::bigint END,
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

REVOKE ALL ON FUNCTION public.fn_driver_billing_status() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_billing_status() TO authenticated;

COMMENT ON FUNCTION public.fn_driver_billing_status() IS
  'Weekly-only Platform Balance status including per-driver cycle anchor and Payment Pending state.';
