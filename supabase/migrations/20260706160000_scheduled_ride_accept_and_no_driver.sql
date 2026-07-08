-- Scheduled ride accept + no-driver cutoff (staging-first rollout).

CREATE OR REPLACE FUNCTION public.fn_driver_accept_scheduled_ride(p_ride_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
  v_billing jsonb;
  v_ride public.ride_requests%ROWTYPE;
  v_d public.drivers%ROWTYPE;
  v_conversation_id uuid;
  v_rider_target text;
  v_duration_min numeric;
  v_overlap boolean;
BEGIN
  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  IF v_ride.status = 'cancelled' THEN
    RETURN json_build_object('ok', false, 'error', 'ride_cancelled');
  END IF;

  IF v_ride.status = 'accepted' AND v_ride.driver_id = v_driver_id THEN
    SELECT c.id INTO v_conversation_id
    FROM public.conversations c
    WHERE c.ride_request_id = p_ride_request_id;
    RETURN json_build_object(
      'ok', true, 'already_accepted', true,
      'ride_id', p_ride_request_id,
      'conversation_id', v_conversation_id
    );
  END IF;

  IF v_ride.status <> 'pending' OR v_ride.driver_id IS NOT NULL THEN
    RETURN json_build_object('ok', false, 'error', 'race_lost');
  END IF;

  IF v_ride.booking_mode IS DISTINCT FROM 'scheduled'
     AND COALESCE(v_ride.is_scheduled, false) = false THEN
    RETURN json_build_object('ok', false, 'error', 'not_scheduled');
  END IF;

  v_billing := public.fn_driver_can_accept_rides(v_driver_id);
  IF COALESCE((v_billing->>'allowed')::boolean, false) = false THEN
    RETURN json_build_object(
      'ok', false, 'error', 'billing_locked',
      'message', COALESCE(v_billing->>'reason', 'Outstanding platform fees exceed market limit.')
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.driver_rate_profiles rp
    WHERE rp.driver_id = v_driver_id AND rp.is_active = true
  ) THEN
    RETURN json_build_object('ok', false, 'error', 'missing_tariff');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.driver_locations dl
    WHERE dl.driver_id = v_driver_id
      AND dl.latitude IS NOT NULL AND dl.longitude IS NOT NULL
      AND dl.updated_at > now() - interval '5 minutes'
  ) THEN
    RETURN json_build_object('ok', false, 'error', 'stale_location');
  END IF;

  IF NOT public.fn_payment_compatible(v_driver_id, v_ride.payment_methods) THEN
    RETURN json_build_object('ok', false, 'error', 'payment_incompatible');
  END IF;

  v_duration_min := COALESCE(v_ride.estimated_duration_min, 60);
  v_overlap := public.fn_driver_has_overlap(
    v_driver_id,
    v_ride.scheduled_pickup_at,
    v_duration_min
  );
  IF COALESCE(v_overlap, true) THEN
    RETURN json_build_object('ok', false, 'error', 'schedule_overlap');
  END IF;

  UPDATE public.ride_requests rr
  SET status = 'accepted',
      driver_id = v_driver_id,
      accepted_at = timezone('utc', now()),
      scheduled_confirmed_by_driver = true,
      updated_at = now()
  WHERE rr.id = p_ride_request_id
    AND rr.status = 'pending'
    AND rr.driver_id IS NULL;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RETURN json_build_object('ok', false, 'error', 'race_lost');
  END IF;

  UPDATE public.ride_request_invites i
  SET status = 'superseded'
  WHERE i.ride_request_id = p_ride_request_id
    AND i.status IN ('pending', 'wave_expired', 'expired');

  INSERT INTO public.conversations (ride_request_id, driver_id, rider_identity_id)
  VALUES (p_ride_request_id, v_driver_id, v_ride.rider_identity_id)
  ON CONFLICT (ride_request_id) DO UPDATE
  SET driver_id = EXCLUDED.driver_id
  RETURNING id INTO v_conversation_id;

  SELECT * INTO v_d FROM public.drivers d WHERE d.id = v_driver_id;
  v_rider_target := COALESCE(v_ride.rider_identity_id::text, v_ride.rider_id::text);
  PERFORM public.fn_ride_event_notify(
    'rider', v_rider_target, 'scheduled_driver_accepted',
    'Scheduled ride accepted',
    COALESCE(v_d.full_name, 'Your driver')
      || ' accepted your scheduled ride'
      || CASE
           WHEN COALESCE(v_d.vehicle_plate, '') <> ''
             THEN ' (' || v_d.vehicle_plate || ')'
           ELSE ''
         END || '.',
    jsonb_build_object(
      'type', 'scheduled_driver_accepted',
      'ride_request_id', p_ride_request_id,
      'driver_name', v_d.full_name,
      'vehicle_make', v_d.vehicle_make,
      'vehicle_model', v_d.vehicle_model,
      'vehicle_plate', v_d.vehicle_plate,
      'scheduled_pickup_at', v_ride.scheduled_pickup_at,
      'conversation_id', v_conversation_id
    ),
    'high'
  );

  PERFORM public.fn_ride_audit_append(
    p_ride_request_id, 'ride.scheduled_accepted', v_driver_id,
    jsonb_build_object('conversation_id', v_conversation_id),
    'driver', 'rpc', p_ride_request_id
  );

  RETURN json_build_object(
    'ok', true,
    'ride_id', p_ride_request_id,
    'conversation_id', v_conversation_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_process_scheduled_rides_no_driver()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_lead int;
  v_row public.ride_requests%ROWTYPE;
  v_processed int := 0;
  v_notified int := 0;
BEGIN
  v_lead := public.fn_scheduled_matching_lead_minutes();

  FOR v_row IN
    SELECT *
    FROM public.ride_requests rr
    WHERE rr.status = 'pending'
      AND rr.driver_id IS NULL
      AND (
        rr.booking_mode IS NOT DISTINCT FROM 'scheduled'
        OR COALESCE(rr.is_scheduled, false) = true
      )
      AND rr.scheduled_pickup_at IS NOT NULL
      AND rr.scheduled_pickup_at <= now() + make_interval(mins => v_lead)
  LOOP
    v_processed := v_processed + 1;

    UPDATE public.ride_requests rr
    SET status = 'cancelled',
        cancelled_by = 'system',
        cancellation_reason = 'no_driver_scheduled',
        updated_at = now()
    WHERE rr.id = v_row.id
      AND rr.status = 'pending'
      AND rr.driver_id IS NULL;

    IF FOUND THEN
      v_notified := v_notified + 1;
      PERFORM public.fn_ride_event_notify(
        'rider',
        COALESCE(v_row.rider_identity_id::text, v_row.rider_id::text),
        'scheduled_no_driver',
        'No driver for your scheduled ride',
        'Sorry, we could not find a taxi for your scheduled ride. Please try again or adjust your booking.',
        jsonb_build_object(
          'type', 'scheduled_no_driver',
          'ride_request_id', v_row.id,
          'scheduled_pickup_at', v_row.scheduled_pickup_at
        ),
        'high'
      );
      PERFORM public.fn_ride_audit_append(
        v_row.id, 'ride.scheduled_no_driver', NULL,
        jsonb_build_object('scheduled_pickup_at', v_row.scheduled_pickup_at),
        'system', 'cron', v_row.id
      );
    END IF;
  END LOOP;

  RETURN json_build_object(
    'ok', true,
    'processed', v_processed,
    'notified', v_notified,
    'lead_minutes', v_lead
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_driver_accept_scheduled_ride(uuid) TO authenticated;

DO $$
BEGIN
  IF to_regclass('cron.job') IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM cron.job WHERE jobname = 'heycaby_scheduled_no_driver_notify'
    ) THEN
      EXECUTE
        'SELECT cron.schedule(' ||
        quote_literal('heycaby_scheduled_no_driver_notify') || ', ' ||
        quote_literal('*/5 * * * *') || ', ' ||
        quote_literal('SELECT public.fn_process_scheduled_rides_no_driver();') ||
        ')';
    END IF;
  END IF;
END $$;
