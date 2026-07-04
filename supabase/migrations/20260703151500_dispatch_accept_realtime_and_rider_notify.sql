-- P0 dispatch hardening:
-- - ride accept is atomic and records accepted_at
-- - core dispatch tables are present in Realtime publication
-- - keep implementation idempotent across staging/production drift

CREATE OR REPLACE FUNCTION public.fn_driver_accept_ride_invite (p_ride_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_billing jsonb;
  v_ride public.ride_requests%ROWTYPE;
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

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  IF v_ride.status <> 'pending' THEN
    RETURN json_build_object('ok', false, 'error', 'race_lost', 'status', v_ride.status);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.ride_request_invites i
    WHERE i.ride_request_id = p_ride_request_id
      AND i.driver_id = v_driver_id
      AND i.status = 'pending'
      AND i.expires_at > now()
    FOR UPDATE
  ) THEN
    RETURN json_build_object('ok', false, 'error', 'no_valid_invite');
  END IF;

  UPDATE public.ride_requests rr
  SET
    status = 'accepted',
    driver_id = v_driver_id,
    accepted_at = COALESCE(rr.accepted_at, now()),
    updated_at = now()
  WHERE rr.id = p_ride_request_id;

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

  RETURN json_build_object(
    'ok', true,
    'ride_request_id', p_ride_request_id,
    'driver_id', v_driver_id,
    'status', 'accepted'
  );
END;
$$;

DO $$
DECLARE
  v_table text;
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) THEN
    FOREACH v_table IN ARRAY ARRAY[
      'ride_requests',
      'ride_request_invites',
      'notifications'
    ]
    LOOP
      IF to_regclass('public.' || v_table) IS NOT NULL
        AND NOT EXISTS (
          SELECT 1
          FROM pg_publication_tables
          WHERE pubname = 'supabase_realtime'
            AND schemaname = 'public'
            AND tablename = v_table
        )
      THEN
        EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', v_table);
      END IF;
    END LOOP;
  END IF;
END $$;
