ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS driver_cancel_reason_code text,
  ADD COLUMN IF NOT EXISTS driver_cancel_details text,
  ADD COLUMN IF NOT EXISTS rider_paid_before_cancel_cents integer,
  ADD COLUMN IF NOT EXISTS driver_waived_cancel_balance boolean,
  ADD COLUMN IF NOT EXISTS driver_paused_after_cancel boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.fn_driver_ride_action_proximity(
  p_ride_request_id uuid,
  p_action text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_ride public.ride_requests%ROWTYPE;
  v_lat double precision;
  v_lng double precision;
  v_target geography;
  v_distance_m integer;
  v_limit_m integer;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_a_driver');
  END IF;
  IF p_action NOT IN ('arrive_pickup', 'complete_dropoff') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_action');
  END IF;

  SELECT * INTO v_ride FROM public.ride_requests
  WHERE id = p_ride_request_id AND driver_id = v_driver_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  SELECT latitude, longitude INTO v_lat, v_lng
  FROM public.driver_locations
  WHERE driver_id = v_driver_id
  ORDER BY updated_at DESC NULLS LAST
  LIMIT 1;
  IF v_lat IS NULL OR v_lng IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'driver_location_unavailable');
  END IF;

  v_target := CASE WHEN p_action = 'arrive_pickup'
    THEN v_ride.pickup_coords ELSE v_ride.destination_coords END;
  v_limit_m := CASE WHEN p_action = 'arrive_pickup' THEN 500 ELSE 750 END;
  IF v_target IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'target_location_unavailable');
  END IF;

  v_distance_m := round(ST_Distance(
    ST_SetSRID(ST_MakePoint(v_lng, v_lat), 4326)::geography,
    v_target
  ));
  RETURN jsonb_build_object(
    'ok', true,
    'allowed', v_distance_m <= v_limit_m,
    'action', p_action,
    'distance_m', v_distance_m,
    'limit_m', v_limit_m,
    'error', CASE
      WHEN v_distance_m <= v_limit_m THEN NULL
      WHEN p_action = 'arrive_pickup' THEN 'too_far_from_pickup'
      ELSE 'too_far_from_dropoff'
    END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_ride_action_proximity(uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_driver_ride_action_proximity(uuid, text)
  TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.fn_driver_ride_cancel_v2(
  p_ride_request_id uuid,
  p_reason_code text,
  p_details text DEFAULT NULL,
  p_rider_paid_cents integer DEFAULT 0,
  p_waive_remaining boolean DEFAULT false,
  p_pause_new_requests boolean DEFAULT false
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_reason text;
  v_result jsonb;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_a_driver');
  END IF;
  IF p_reason_code NOT IN (
    'changed_mind', 'vehicle_problem', 'safety_concern',
    'rider_requested', 'route_or_destination_issue', 'other'
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_cancel_reason');
  END IF;
  IF COALESCE(p_rider_paid_cents, 0) < 0 OR COALESCE(p_rider_paid_cents, 0) > 10000000 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_paid_amount');
  END IF;

  v_reason := p_reason_code || CASE
    WHEN NULLIF(btrim(COALESCE(p_details, '')), '') IS NULL THEN ''
    ELSE ': ' || left(btrim(p_details), 300)
  END;
  v_result := public.fn_driver_ride_cancel(p_ride_request_id, v_reason);
  IF COALESCE((v_result->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN v_result;
  END IF;

  UPDATE public.ride_requests
  SET driver_cancel_reason_code = p_reason_code,
      driver_cancel_details = NULLIF(left(btrim(COALESCE(p_details, '')), 300), ''),
      rider_paid_before_cancel_cents = COALESCE(p_rider_paid_cents, 0),
      driver_waived_cancel_balance = COALESCE(p_waive_remaining, false),
      driver_paused_after_cancel = COALESCE(p_pause_new_requests, false),
      updated_at = timezone('utc', now())
  WHERE id = p_ride_request_id AND driver_id = v_driver_id;

  IF COALESCE(p_pause_new_requests, false) THEN
    UPDATE public.drivers
    SET status = 'on_break', updated_at = timezone('utc', now())
    WHERE id = v_driver_id;
  END IF;

  PERFORM public.fn_ride_audit_append(
    p_ride_request_id,
    'ride.driver_cancel_settlement',
    v_driver_id,
    jsonb_build_object(
      'reason_code', p_reason_code,
      'rider_paid_cents', COALESCE(p_rider_paid_cents, 0),
      'waived_remaining', COALESCE(p_waive_remaining, false),
      'paused_new_requests', COALESCE(p_pause_new_requests, false)
    ),
    'driver', 'rpc', p_ride_request_id
  );

  RETURN v_result || jsonb_build_object(
    'rider_paid_cents', COALESCE(p_rider_paid_cents, 0),
    'waived_remaining', COALESCE(p_waive_remaining, false),
    'paused_new_requests', COALESCE(p_pause_new_requests, false)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_ride_cancel_v2(uuid, text, text, integer, boolean, boolean)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_driver_ride_cancel_v2(uuid, text, text, integer, boolean, boolean)
  TO authenticated, service_role;

-- The same feedback loop remains available when a ride ended by cancellation.
-- Preserve the current rating implementation and widen only its status guard.
DO $$
DECLARE
  v_definition text;
BEGIN
  SELECT pg_get_functiondef(
    'public.fn_driver_rate_rider(uuid,smallint,text)'::regprocedure
  ) INTO v_definition;
  IF position('rr.status = ''completed''' IN v_definition) > 0 THEN
    v_definition := replace(
      v_definition,
      'rr.status = ''completed''',
      'rr.status IN (''completed'', ''cancelled'')'
    );
    EXECUTE v_definition;
  END IF;
END $$;
