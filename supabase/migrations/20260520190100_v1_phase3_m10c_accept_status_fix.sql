-- M10C hotfix: ride_requests.status must be 'accepted' (DB check constraint), not 'assigned'.
-- Caught during M10C E2E smoke on HEYCABY-TAXI.

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
