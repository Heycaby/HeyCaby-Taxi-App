-- Payment completion v2: manual confirm for cash / Tikkie / PIN (no payment processing).

ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS payment_status text NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS payment_confirmed_at timestamptz,
  ADD COLUMN IF NOT EXISTS rider_payment_confirmed_at timestamptz,
  ADD COLUMN IF NOT EXISTS driver_payment_confirmed_at timestamptz,
  ADD COLUMN IF NOT EXISTS tip_amount_eur numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_amount_eur numeric,
  ADD COLUMN IF NOT EXISTS payment_method_settled text;

COMMENT ON COLUMN public.ride_requests.payment_status IS
  'pending | rider_ack | confirmed — manual payment coordination only.';
COMMENT ON COLUMN public.ride_requests.payment_method_settled IS
  'cash | pin | tikkie — method actually used at drop-off (may differ from booking).';

CREATE OR REPLACE FUNCTION public.fn_confirm_ride_payment(
  p_ride_id uuid,
  p_tip_eur numeric DEFAULT 0,
  p_rider_token text DEFAULT NULL,
  p_payment_method text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_driver_id uuid;
  v_is_driver boolean := false;
  v_is_rider boolean := false;
  v_base numeric;
  v_waiting numeric;
  v_tip numeric := GREATEST(COALESCE(p_tip_eur, 0), 0);
  v_method text := NULLIF(lower(btrim(COALESCE(p_payment_method, ''))), '');
  v_status text;
BEGIN
  IF p_ride_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_ride_id');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests
  WHERE id = p_ride_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  IF v_ride.status <> 'completed' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ride_not_completed');
  END IF;

  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NOT NULL AND v_ride.driver_id = v_driver_id THEN
    v_is_driver := true;
  END IF;

  IF NOT v_is_driver THEN
    IF v_ride.rider_identity_id IS NOT NULL AND auth.uid() IS NOT NULL THEN
      SELECT EXISTS (
        SELECT 1 FROM public.rider_identities ri
        WHERE ri.id = v_ride.rider_identity_id AND ri.user_id = auth.uid()
      ) INTO v_is_rider;
    END IF;
    IF NOT v_is_rider
       AND p_rider_token IS NOT NULL
       AND btrim(p_rider_token) <> ''
       AND v_ride.rider_token = btrim(p_rider_token) THEN
      v_is_rider := true;
    END IF;
    IF NOT v_is_rider
       AND auth.uid() IS NOT NULL
       AND v_ride.rider_token IS NOT NULL
       AND EXISTS (
         SELECT 1 FROM public.rider_sessions rs
         WHERE rs.user_id = auth.uid()
           AND rs.session_token = v_ride.rider_token
       ) THEN
      v_is_rider := true;
    END IF;
  END IF;

  IF NOT v_is_driver AND NOT v_is_rider THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authorized');
  END IF;

  v_base := COALESCE(
    v_ride.final_fare,
    v_ride.marketplace_offered_fare,
    v_ride.offered_fare,
    v_ride.quoted_fare,
    v_ride.estimated_fare,
    0
  );
  v_waiting := CASE
    WHEN COALESCE(v_ride.waiting_fee_waived, false) THEN 0
    ELSE COALESCE(v_ride.waiting_fee_cents, 0)::numeric / 100
  END;

  IF v_method IS NULL THEN
    v_method := NULLIF(lower(btrim(COALESCE(v_ride.payment_method_settled, ''))), '');
  END IF;
  IF v_method IS NULL AND v_ride.payment_methods IS NOT NULL
     AND array_length(v_ride.payment_methods, 1) > 0 THEN
    v_method := lower(v_ride.payment_methods[1]::text);
  END IF;
  IF v_method = 'card' THEN
    v_method := 'pin';
  END IF;

  UPDATE public.ride_requests rr
  SET
    tip_amount_eur = CASE WHEN v_is_rider THEN v_tip ELSE rr.tip_amount_eur END,
    total_amount_eur = v_base + v_waiting +
      CASE WHEN v_is_rider THEN v_tip ELSE COALESCE(rr.tip_amount_eur, 0) END,
    payment_method_settled = COALESCE(v_method, rr.payment_method_settled),
    rider_payment_confirmed_at = CASE
      WHEN v_is_rider THEN timezone('utc', now())
      ELSE rr.rider_payment_confirmed_at
    END,
    driver_payment_confirmed_at = CASE
      WHEN v_is_driver THEN timezone('utc', now())
      ELSE rr.driver_payment_confirmed_at
    END,
    payment_status = CASE
      WHEN v_is_driver THEN 'confirmed'
      WHEN v_is_rider AND rr.driver_payment_confirmed_at IS NOT NULL THEN 'confirmed'
      WHEN v_is_rider THEN 'rider_ack'
      ELSE rr.payment_status
    END,
    payment_confirmed_at = CASE
      WHEN v_is_driver THEN timezone('utc', now())
      WHEN v_is_rider AND rr.driver_payment_confirmed_at IS NOT NULL THEN timezone('utc', now())
      ELSE rr.payment_confirmed_at
    END,
    updated_at = timezone('utc', now())
  WHERE rr.id = p_ride_id
  RETURNING payment_status INTO v_status;

  PERFORM public.fn_ride_audit_append(
    p_ride_id,
    'payment.confirmed',
  CASE WHEN v_is_driver THEN v_driver_id ELSE NULL END,
    jsonb_build_object(
      'actor', CASE WHEN v_is_driver THEN 'driver' ELSE 'rider' END,
      'tip_eur', v_tip,
      'payment_method', v_method,
      'payment_status', v_status
    )
  );

  IF v_is_driver AND v_ride.driver_id IS NOT NULL THEN
    PERFORM public.fn_driver_ride_issue_auto_receipt(p_ride_id, v_ride.driver_id);
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'confirmed', v_status = 'confirmed',
    'payment_status', v_status
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_confirm_ride_payment(uuid, numeric, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_confirm_ride_payment(uuid, numeric, text, text) TO authenticated;
