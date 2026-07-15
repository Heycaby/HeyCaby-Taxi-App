-- Booking creation command authority.
--
-- The current Rider app must not construct a mutable ride_requests row through
-- the Data API. This additive command binds the booking to auth.uid(), accepts
-- only booking-input fields, owns the initial lifecycle/fare snapshot, and is
-- retry-safe. The legacy INSERT policy is intentionally retained until the
-- minimum supported Rider version is decided.

ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS rider_create_request_id uuid,
  ADD COLUMN IF NOT EXISTS rider_create_payload_hash text;

CREATE UNIQUE INDEX IF NOT EXISTS ride_requests_rider_create_idempotency_uidx
  ON public.ride_requests (rider_token, rider_create_request_id)
  WHERE rider_create_request_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.fn_rider_create_ride(p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_request_id uuid;
  v_rider_token text;
  v_rider_identity_id uuid;
  v_pickup_address text;
  v_destination_address text;
  v_pickup_contact_name text;
  v_pickup_lat double precision;
  v_pickup_lng double precision;
  v_destination_lat double precision;
  v_destination_lng double precision;
  v_estimated_distance_km numeric;
  v_estimated_duration_min numeric;
  v_booking_mode public.booking_mode;
  v_vehicle_category public.vehicle_category;
  v_vehicle_categories text[];
  v_payment_methods text[];
  v_scheduled_pickup_at timestamptz;
  v_preferred_driver_id uuid;
  v_named_fare numeric;
  v_quote numeric;
  v_fare numeric;
  v_pet_friendly boolean;
  v_favorites_first boolean;
  v_favorites_only boolean;
  v_payload_hash text := md5(COALESCE(p_payload, '{}'::jsonb)::text);
  v_existing public.ride_requests%ROWTYPE;
  v_created public.ride_requests%ROWTYPE;
BEGIN
  IF v_actor IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'unauthorized');
  END IF;

  IF p_payload IS NULL OR jsonb_typeof(p_payload) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_payload');
  END IF;

  BEGIN
    v_request_id := NULLIF(btrim(p_payload->>'request_id'), '')::uuid;
    v_rider_token := NULLIF(btrim(p_payload->>'rider_token'), '');
    v_rider_identity_id :=
      NULLIF(btrim(p_payload->>'rider_identity_id'), '')::uuid;
    v_pickup_lat := NULLIF(btrim(p_payload->>'pickup_lat'), '')::double precision;
    v_pickup_lng := NULLIF(btrim(p_payload->>'pickup_lng'), '')::double precision;
    v_destination_lat :=
      NULLIF(btrim(p_payload->>'destination_lat'), '')::double precision;
    v_destination_lng :=
      NULLIF(btrim(p_payload->>'destination_lng'), '')::double precision;
    v_estimated_distance_km :=
      NULLIF(btrim(p_payload->>'estimated_distance_km'), '')::numeric;
    v_estimated_duration_min :=
      NULLIF(btrim(p_payload->>'estimated_duration_min'), '')::numeric;
    v_booking_mode := COALESCE(
      NULLIF(btrim(p_payload->>'booking_mode'), ''),
      'instant'
    )::public.booking_mode;
    v_vehicle_category := COALESCE(
      NULLIF(btrim(p_payload->>'vehicle_category'), ''),
      'standard'
    )::public.vehicle_category;
    v_scheduled_pickup_at :=
      NULLIF(btrim(p_payload->>'scheduled_pickup_at'), '')::timestamptz;
    v_preferred_driver_id :=
      NULLIF(btrim(p_payload->>'preferred_driver_id'), '')::uuid;
    v_named_fare :=
      NULLIF(btrim(p_payload->>'marketplace_offered_fare'), '')::numeric;
    v_quote := NULLIF(btrim(p_payload->>'quoted_fare'), '')::numeric;
  EXCEPTION WHEN invalid_text_representation OR datetime_field_overflow
    OR numeric_value_out_of_range THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_payload');
  END;

  v_pickup_address := NULLIF(btrim(p_payload->>'pickup_address'), '');
  v_destination_address := NULLIF(btrim(p_payload->>'destination_address'), '');
  v_pickup_contact_name := NULLIF(btrim(p_payload->>'pickup_contact_name'), '');
  v_pet_friendly := COALESCE((p_payload->>'pet_friendly')::boolean, false);
  v_favorites_only := COALESCE((p_payload->>'favorites_only')::boolean, false);
  v_favorites_first :=
    v_favorites_only OR COALESCE((p_payload->>'favorites_first')::boolean, false);

  IF v_request_id IS NULL OR v_rider_token IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_booking_identity');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.rider_sessions rs
    WHERE rs.session_token = v_rider_token
      AND rs.user_id = v_actor
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'rider_session_mismatch');
  END IF;

  IF v_rider_identity_id IS NULL THEN
    SELECT ri.id
    INTO v_rider_identity_id
    FROM public.rider_identities ri
    WHERE ri.user_id = v_actor
    ORDER BY ri.created_at DESC
    LIMIT 1;
  ELSIF NOT EXISTS (
    SELECT 1
    FROM public.rider_identities ri
    WHERE ri.id = v_rider_identity_id
      AND (
        ri.user_id = v_actor
        OR (
          ri.user_id IS NULL
          AND ri.email_verified_at IS NOT NULL
          AND lower(ri.email) = lower(COALESCE(auth.jwt()->>'email', ''))
        )
      )
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'rider_identity_mismatch');
  END IF;

  SELECT rr.*
  INTO v_existing
  FROM public.ride_requests rr
  WHERE rr.rider_token = v_rider_token
    AND rr.rider_create_request_id = v_request_id;

  IF FOUND THEN
    IF v_existing.rider_create_payload_hash IS DISTINCT FROM v_payload_hash THEN
      RETURN jsonb_build_object('ok', false, 'error', 'idempotency_conflict');
    END IF;
    RETURN jsonb_build_object(
      'ok', true,
      'duplicate', true,
      'id', v_existing.id,
      'status', v_existing.status,
      'created_at', v_existing.created_at,
      'booking_mode', v_existing.booking_mode
    );
  END IF;

  IF v_pickup_address IS NULL OR length(v_pickup_address) > 500
     OR v_destination_address IS NULL OR length(v_destination_address) > 500
     OR v_pickup_contact_name IS NULL OR length(v_pickup_contact_name) > 100 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_booking_text');
  END IF;

  IF v_pickup_lat IS NULL OR v_pickup_lng IS NULL
     OR v_destination_lat IS NULL OR v_destination_lng IS NULL
     OR v_pickup_lat NOT BETWEEN -90 AND 90
     OR v_destination_lat NOT BETWEEN -90 AND 90
     OR v_pickup_lng NOT BETWEEN -180 AND 180
     OR v_destination_lng NOT BETWEEN -180 AND 180 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_coordinates');
  END IF;

  IF v_estimated_distance_km IS NULL
     OR v_estimated_distance_km <= 0
     OR v_estimated_distance_km > 500
     OR v_estimated_duration_min IS NULL
     OR v_estimated_duration_min <= 0
     OR v_estimated_duration_min > 1440 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_route_estimate');
  END IF;

  IF v_booking_mode = 'scheduled' AND v_scheduled_pickup_at IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'scheduled_pickup_required');
  END IF;

  IF jsonb_typeof(COALESCE(p_payload->'vehicle_categories', '[]'::jsonb)) <> 'array'
     OR jsonb_typeof(COALESCE(p_payload->'payment_methods', '[]'::jsonb)) <> 'array' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_array_payload');
  END IF;

  SELECT COALESCE(array_agg(DISTINCT value), ARRAY[]::text[])
  INTO v_vehicle_categories
  FROM jsonb_array_elements_text(
    COALESCE(p_payload->'vehicle_categories', '[]'::jsonb)
  );
  IF cardinality(v_vehicle_categories) = 0 THEN
    v_vehicle_categories := ARRAY[v_vehicle_category::text];
  END IF;
  IF cardinality(v_vehicle_categories) > 3
     OR EXISTS (
       SELECT 1 FROM unnest(v_vehicle_categories) value
       WHERE value NOT IN ('standard', 'comfort', 'xl', 'wheelchair', 'electric', 'taxibus')
     ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_vehicle_categories');
  END IF;

  SELECT COALESCE(array_agg(DISTINCT value), ARRAY[]::text[])
  INTO v_payment_methods
  FROM jsonb_array_elements_text(
    COALESCE(p_payload->'payment_methods', '[]'::jsonb)
  );
  IF cardinality(v_payment_methods) = 0 THEN
    v_payment_methods := ARRAY['cash']::text[];
  END IF;
  IF EXISTS (
    SELECT 1 FROM unnest(v_payment_methods) value
    WHERE value NOT IN ('cash', 'pin', 'tikkie')
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_payment_methods');
  END IF;

  IF v_preferred_driver_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.drivers d WHERE d.id = v_preferred_driver_id
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'preferred_driver_not_found');
  END IF;

  IF v_booking_mode IN ('marketplace', 'terug') THEN
    IF v_named_fare IS NULL OR v_named_fare <= 0 OR v_named_fare > 10000 THEN
      RETURN jsonb_build_object('ok', false, 'error', 'named_fare_required');
    END IF;
    v_fare := v_named_fare;
  ELSIF v_quote IS NOT NULL THEN
    IF v_quote <= 0 OR v_quote > 10000 THEN
      RETURN jsonb_build_object('ok', false, 'error', 'invalid_quote');
    END IF;
    v_fare := v_quote;
  END IF;

  INSERT INTO public.ride_requests (
    pickup_address,
    pickup_coords,
    pickup_lat,
    pickup_lng,
    destination_address,
    destination_coords,
    destination_lat,
    destination_lng,
    status,
    booking_mode,
    vehicle_category,
    vehicle_categories,
    pet_friendly,
    estimated_distance_km,
    estimated_duration_min,
    pickup_contact_name,
    scheduled_pickup_at,
    rider_token,
    rider_identity_id,
    marketplace_offered_fare,
    offered_fare,
    quoted_fare,
    estimated_fare,
    preferred_driver_id,
    payment_methods,
    favorites_first,
    favorites_only,
    rider_create_request_id,
    rider_create_payload_hash
  ) VALUES (
    v_pickup_address,
    format('SRID=4326;POINT(%s %s)', v_pickup_lng, v_pickup_lat)::public.geography,
    v_pickup_lat,
    v_pickup_lng,
    v_destination_address,
    format('SRID=4326;POINT(%s %s)', v_destination_lng, v_destination_lat)::public.geography,
    v_destination_lat,
    v_destination_lng,
    'pending',
    v_booking_mode,
    v_vehicle_category,
    v_vehicle_categories,
    v_pet_friendly,
    v_estimated_distance_km,
    v_estimated_duration_min,
    v_pickup_contact_name,
    v_scheduled_pickup_at,
    v_rider_token,
    v_rider_identity_id,
    CASE WHEN v_booking_mode IN ('marketplace', 'terug') THEN v_fare END,
    v_fare,
    v_fare,
    v_fare,
    v_preferred_driver_id,
    v_payment_methods,
    v_favorites_first,
    v_favorites_only,
    v_request_id,
    v_payload_hash
  )
  ON CONFLICT (rider_token, rider_create_request_id)
    WHERE rider_create_request_id IS NOT NULL
  DO NOTHING
  RETURNING * INTO v_created;

  IF NOT FOUND THEN
    SELECT rr.*
    INTO v_existing
    FROM public.ride_requests rr
    WHERE rr.rider_token = v_rider_token
      AND rr.rider_create_request_id = v_request_id;

    IF NOT FOUND OR v_existing.rider_create_payload_hash IS DISTINCT FROM v_payload_hash THEN
      RETURN jsonb_build_object('ok', false, 'error', 'idempotency_conflict');
    END IF;
    v_created := v_existing;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'duplicate', false,
    'id', v_created.id,
    'status', v_created.status,
    'created_at', v_created.created_at,
    'booking_mode', v_created.booking_mode
  );
EXCEPTION
  WHEN invalid_text_representation OR datetime_field_overflow
    OR numeric_value_out_of_range THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_payload');
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_create_ride(jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_rider_create_ride(jsonb)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_rider_create_ride(jsonb) IS
  'Canonical authenticated Rider booking command. Actor-bound, field-limited, and idempotent by rider token plus request_id. Legacy direct INSERT remains only for released-app compatibility.';
