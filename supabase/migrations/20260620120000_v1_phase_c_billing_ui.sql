-- Phase C — Backend Consolidation: billing UI RPCs (ledger V1, Supabase-first).
-- Flutter reads status + history from here; Mollie/Apple checkout remains Go until Edge cutover.

-- ---------------------------------------------------------------------------
-- UI-facing billing status (maps ledger V1 → legacy Flutter keys where helpful)
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
    'billing_status_label', CASE v_status
      WHEN 'LOCKED' THEN 'payment_required'
      WHEN 'WARNING' THEN 'approaching_limit'
      ELSE 'good_standing'
    END,
    'show_subscription_controls', false,
    'allow_one_off_checkout', v_status = 'LOCKED',
    'billing_provider', 'ledger',
    'can_settle_outstanding', v_status IN ('LOCKED', 'WARNING') AND v_outstanding > 0
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_billing_status() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_billing_status() TO authenticated;

-- ---------------------------------------------------------------------------
-- Ledger history for billing screen (replaces GET /api/driver/payments)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_billing_ledger_history(p_limit int DEFAULT 50)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
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

  v_lim := GREATEST(1, LEAST(COALESCE(p_limit, 50), 200));

  SELECT COALESCE(jsonb_agg(row_data ORDER BY sort_at DESC), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT
      bl.created_at AS sort_at,
      jsonb_build_object(
        'id', bl.id,
        'title', CASE bl.reason
          WHEN 'ride_fee' THEN 'Platform fee (ride)'
          WHEN 'settlement' THEN 'Platform fee settlement'
          WHEN 'reversal' THEN 'Fee reversal'
          WHEN 'manual_adjustment' THEN 'Manual adjustment'
          WHEN 'credit' THEN 'Credit'
          WHEN 'promotion' THEN 'Promotion'
          WHEN 'waiver' THEN 'Fee waiver'
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

COMMENT ON FUNCTION public.fn_driver_billing_status() IS
  'Phase C: ledger V1 billing status for driver billing UI (Supabase-first).';
COMMENT ON FUNCTION public.fn_driver_billing_ledger_history(int) IS
  'Phase C: append-only billing_ledger rows for driver payment history screen.';
