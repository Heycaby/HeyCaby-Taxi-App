-- Source-control the open scheduled-rides read projection currently consumed
-- by Driver. SECURITY INVOKER keeps underlying ride_requests RLS authoritative.
CREATE OR REPLACE VIEW public.scheduled_rides_available
WITH (security_invoker = true)
AS
SELECT
  rr.id,
  rr.pickup_address,
  rr.destination_address,
  rr.scheduled_pickup_at,
  rr.estimated_distance_km,
  rr.estimated_duration_min,
  rr.offered_fare,
  rr.marketplace_offered_fare,
  rr.payment_method,
  rr.payment_methods,
  rr.pickup_contact_name,
  rr.zone_id,
  bz.name_display AS pickup_zone_name,
  bz.city AS pickup_city,
  ST_Y(rr.pickup_coords::geometry) AS pickup_lat,
  ST_X(rr.pickup_coords::geometry) AS pickup_lng,
  ST_Y(rr.destination_coords::geometry) AS destination_lat,
  ST_X(rr.destination_coords::geometry) AS destination_lng,
  rr.filter_electric,
  rr.filter_pet_friendly,
  rr.filter_wheelchair,
  rr.created_at,
  rr.status
FROM public.ride_requests rr
LEFT JOIN public.bubble_zones bz ON bz.id = rr.zone_id
WHERE rr.booking_mode = 'scheduled'::public.booking_mode
  AND rr.status = 'pending'
  AND rr.scheduled_pickup_at > now()
  AND (rr.expires_at IS NULL OR rr.expires_at > now())
ORDER BY rr.scheduled_pickup_at;

COMMENT ON VIEW public.scheduled_rides_available
IS 'Open future scheduled-ride catalog. Underlying ride_requests RLS identifies authenticated Drivers; acceptance rechecks all mutable rules.';

GRANT SELECT ON public.scheduled_rides_available TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.fn_driver_accept_scheduled_ride(
  p_ride_request_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
  v_billing jsonb;
  v_eligibility jsonb;
  v_ride public.ride_requests%ROWTYPE;
  v_driver public.drivers%ROWTYPE;
  v_conversation_id uuid;
  v_duration_min numeric;
  v_overlap boolean;
  v_reject jsonb;
BEGIN
  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'not_a_driver',
      'reason', 'not_a_driver',
      'message', 'Driver profile not found for this account.'
    )::json;
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'ride_not_found',
      'reason', 'ride_not_found',
      'message', 'This scheduled ride no longer exists.'
    )::json;
  END IF;

  IF v_ride.status = 'cancelled' THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'ride_cancelled',
      'reason', 'ride_cancelled',
      'message', 'The rider cancelled this scheduled trip.'
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.scheduled_accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  IF v_ride.status = 'accepted' AND v_ride.driver_id = v_driver_id THEN
    SELECT c.id INTO v_conversation_id
    FROM public.conversations c
    WHERE c.ride_request_id = p_ride_request_id;
    RETURN json_build_object(
      'ok', true,
      'already_accepted', true,
      'ride_id', p_ride_request_id,
      'conversation_id', v_conversation_id
    );
  END IF;

  IF v_ride.status <> 'pending' OR v_ride.driver_id IS NOT NULL THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'race_lost',
      'reason', 'ride_not_pending',
      'message', 'Another driver already accepted this scheduled ride.'
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.scheduled_accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  IF v_ride.booking_mode::text IS DISTINCT FROM 'scheduled'
     AND COALESCE(v_ride.is_scheduled, false) IS NOT TRUE THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'not_scheduled',
      'reason', 'not_scheduled',
      'message', 'This is not a scheduled ride.'
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.scheduled_accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  IF v_ride.expires_at IS NOT NULL AND v_ride.expires_at <= now() THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'ride_expired',
      'reason', 'ride_expired',
      'message', 'This scheduled ride is no longer available.'
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.scheduled_accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  IF v_ride.scheduled_pickup_at IS NULL
     OR v_ride.scheduled_pickup_at <= now() THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'scheduled_departed',
      'reason', 'scheduled_departed',
      'message', 'The pickup time for this scheduled ride has passed.'
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.scheduled_accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  v_billing := public.fn_driver_can_accept_rides(v_driver_id);
  IF COALESCE((v_billing->>'allowed')::boolean, false) IS NOT TRUE THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'billing_locked',
      'reason', 'billing_locked',
      'message', COALESCE(
        v_billing->>'reason',
        'Outstanding platform fees exceed market limit.'
      ),
      'details', v_billing
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.scheduled_accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.driver_rate_profiles rp
    WHERE rp.driver_id = v_driver_id
      AND rp.is_active = true
  ) THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'missing_tariff',
      'reason', 'missing_tariff',
      'message', 'Set your tariff before accepting rides.'
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.scheduled_accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.driver_locations dl
    WHERE dl.driver_id = v_driver_id
      AND dl.latitude IS NOT NULL
      AND dl.longitude IS NOT NULL
      AND dl.updated_at > now() - interval '5 minutes'
  ) THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'stale_location',
      'reason', 'gps_stale',
      'message', 'Your GPS location is stale. Enable location and try again.'
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.scheduled_accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  IF NOT public.fn_payment_compatible(v_driver_id, v_ride.payment_methods) THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'payment_incompatible',
      'reason', 'payment_mismatch',
      'message', 'This ride uses a payment method you do not support.'
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.scheduled_accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  -- Scheduled rides are an open authenticated marketplace, not an exact-invite
  -- surface. Online presence and a queued next ride do not block future work;
  -- readiness, compliance, vehicle/accessibility fit remain mandatory.
  v_eligibility := public.fn_driver_accept_runtime_eligibility(
    v_driver_id,
    v_ride,
    false,
    false
  );
  IF COALESCE((v_eligibility->>'eligible')::boolean, false) IS NOT TRUE THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'driver_not_eligible',
      'reason', COALESCE(v_eligibility->>'reason', 'driver_not_eligible'),
      'message', COALESCE(
        v_eligibility->>'message',
        'You are no longer eligible for this scheduled ride.'
      ),
      'details', v_eligibility - 'message'
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.scheduled_accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  v_duration_min := COALESCE(v_ride.estimated_duration_min, 60);
  v_overlap := public.fn_driver_has_overlap(
    v_driver_id,
    v_ride.scheduled_pickup_at,
    v_duration_min
  );
  IF COALESCE(v_overlap, true) THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'schedule_overlap',
      'reason', 'schedule_overlap',
      'message', 'This ride overlaps another scheduled ride.'
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.scheduled_accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
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
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'race_lost',
      'reason', 'database_conflict',
      'message', 'Another driver accepted this scheduled ride first.'
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.scheduled_accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  UPDATE public.ride_request_invites i
  SET status = 'superseded'
  WHERE i.ride_request_id = p_ride_request_id
    AND i.status IN ('pending', 'wave_expired', 'expired');

  INSERT INTO public.conversations (
    ride_request_id,
    driver_id,
    rider_identity_id
  )
  VALUES (
    p_ride_request_id,
    v_driver_id,
    v_ride.rider_identity_id
  )
  ON CONFLICT (ride_request_id) DO UPDATE
  SET driver_id = EXCLUDED.driver_id
  RETURNING id INTO v_conversation_id;

  SELECT * INTO v_driver
  FROM public.drivers d
  WHERE d.id = v_driver_id;

  PERFORM public.fn_ride_notify_rider(
    p_ride_request_id,
    'scheduled_driver_accepted',
    'Scheduled ride accepted',
    COALESCE(v_driver.full_name, 'Your driver')
      || ' accepted your scheduled ride'
      || CASE
           WHEN COALESCE(v_driver.vehicle_plate, '') <> ''
             THEN ' (' || v_driver.vehicle_plate || ')'
           ELSE ''
         END || '.',
    jsonb_build_object(
      'type', 'scheduled_driver_accepted',
      'driver_name', v_driver.full_name,
      'vehicle_make', v_driver.vehicle_make,
      'vehicle_model', v_driver.vehicle_model,
      'vehicle_plate', v_driver.vehicle_plate,
      'scheduled_pickup_at', v_ride.scheduled_pickup_at,
      'conversation_id', v_conversation_id
    ),
    'high'
  );

  PERFORM public.fn_ride_audit_append(
    p_ride_request_id,
    'ride.scheduled_accepted',
    v_driver_id,
    jsonb_build_object('conversation_id', v_conversation_id),
    'driver',
    'rpc',
    p_ride_request_id
  );

  RETURN json_build_object(
    'ok', true,
    'ride_id', p_ride_request_id,
    'conversation_id', v_conversation_id
  );
END;
$$;

COMMENT ON FUNCTION public.fn_driver_accept_scheduled_ride(uuid)
IS 'Atomic open-marketplace scheduled acceptance with actor binding, future/expiry checks, shared ride-fit eligibility, overlap guard, Rider notify, and audit.';

REVOKE ALL ON FUNCTION public.fn_driver_accept_scheduled_ride(uuid)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_driver_accept_scheduled_ride(uuid)
TO authenticated;
