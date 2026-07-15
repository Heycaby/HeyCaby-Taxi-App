-- Share one ride-fit policy between live exact-invite acceptance and the
-- intentionally open scheduled-rides marketplace. Presence and existing
-- next-ride reservation checks are context switches; readiness, compliance,
-- vehicle fit and accessibility requirements are common backend truth.
CREATE OR REPLACE FUNCTION public.fn_driver_accept_runtime_eligibility(
  p_driver_id uuid,
  p_ride public.ride_requests,
  p_require_online boolean,
  p_block_queued_taxi_terug boolean
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver public.drivers%ROWTYPE;
  v_readiness jsonb;
  v_vehicle_matches boolean;
  v_pet_required boolean;
  v_electric_required boolean;
  v_wheelchair_required boolean;
BEGIN
  SELECT * INTO v_driver
  FROM public.drivers d
  WHERE d.id = p_driver_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'reason', 'driver_not_found',
      'message', 'Driver profile not found for this account.'
    );
  END IF;

  IF COALESCE(p_require_online, true)
     AND v_driver.status::text IS DISTINCT FROM 'available' THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'reason', 'driver_offline',
      'message', 'Go online before accepting a live ride.',
      'operational_status', v_driver.status::text
    );
  END IF;

  IF lower(COALESCE(v_driver.compliance_status, '')) = 'suspended' THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'reason', 'driver_suspended',
      'message', 'Your Driver account is currently suspended.'
    );
  END IF;

  v_readiness := public.fn_driver_readiness_eval(p_driver_id);
  IF COALESCE((v_readiness->>'can_go_online')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'reason', 'driver_not_ready',
      'message', COALESCE(
        NULLIF(v_readiness->>'status_message', ''),
        'Complete your Driver requirements before accepting rides.'
      ),
      'missing_docs', COALESCE(v_readiness->'missing_docs', '[]'::jsonb),
      'review_status', COALESCE(v_readiness->>'review_status', 'none')
    );
  END IF;

  IF COALESCE(p_block_queued_taxi_terug, true)
     AND public.fn_driver_has_queued_taxi_terug(p_driver_id) THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'reason', 'queued_taxi_terug',
      'message', 'You already have a Taxi Terug ride reserved next.'
    );
  END IF;

  v_vehicle_matches := CASE
    WHEN p_ride.vehicle_categories IS NOT NULL
         AND cardinality(p_ride.vehicle_categories) > 0
      THEN lower(trim(both from COALESCE(v_driver.vehicle_category::text, '')))
        = ANY (
          SELECT lower(trim(both from category))
          FROM unnest(p_ride.vehicle_categories) AS category
        )
    WHEN p_ride.vehicle_category IS NULL
         OR trim(both from p_ride.vehicle_category::text) = ''
      THEN true
    ELSE lower(trim(both from COALESCE(v_driver.vehicle_category::text, '')))
      = lower(trim(both from p_ride.vehicle_category::text))
  END;

  IF NOT COALESCE(v_vehicle_matches, false) THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'reason', 'vehicle_mismatch',
      'message', 'Your active vehicle does not match this ride.',
      'driver_vehicle_category', v_driver.vehicle_category::text,
      'ride_vehicle_category', p_ride.vehicle_category::text,
      'ride_vehicle_categories', to_jsonb(p_ride.vehicle_categories)
    );
  END IF;

  v_electric_required := COALESCE(p_ride.filter_electric, false);
  IF v_electric_required
     AND lower(COALESCE(v_driver.vehicle_category::text, '')) <> 'electric'
     AND lower(COALESCE(v_driver.vehicle_type, '')) NOT LIKE '%electric%' THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'reason', 'electric_vehicle_required',
      'message', 'This ride requires an electric taxi.'
    );
  END IF;

  v_wheelchair_required := COALESCE(p_ride.filter_wheelchair, false);
  IF v_wheelchair_required
     AND NOT COALESCE(v_driver.is_wheelchair_accessible, false)
     AND NOT COALESCE(v_driver.wheelchair_accessible, false)
     AND lower(COALESCE(v_driver.vehicle_category::text, '')) <> 'wheelchair' THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'reason', 'wheelchair_vehicle_required',
      'message', 'This ride requires a wheelchair-accessible taxi.'
    );
  END IF;

  v_pet_required := COALESCE(p_ride.pet_friendly, false)
    OR COALESCE(p_ride.filter_pet_friendly, false);
  IF v_pet_required
     AND NOT COALESCE(v_driver.accepts_pets, false)
     AND NOT COALESCE(v_driver.is_pet_friendly, false) THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'reason', 'pets_not_supported',
      'message', 'This ride requires a pet-friendly vehicle.'
    );
  END IF;

  RETURN jsonb_build_object('eligible', true, 'reason', 'eligible');
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_accept_runtime_eligibility(
  p_driver_id uuid,
  p_ride public.ride_requests
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.fn_driver_accept_runtime_eligibility(
    p_driver_id,
    p_ride,
    true,
    true
  );
$$;

COMMENT ON FUNCTION public.fn_driver_accept_runtime_eligibility(
  uuid, public.ride_requests, boolean, boolean
)
IS 'Internal shared ride-fit projection. Context flags distinguish live presence/queue rules from future scheduled acceptance.';

COMMENT ON FUNCTION public.fn_driver_accept_runtime_eligibility(
  uuid, public.ride_requests
)
IS 'Internal live-ride eligibility wrapper requiring online presence and no queued Taxi Terug reservation.';

REVOKE ALL ON FUNCTION public.fn_driver_accept_runtime_eligibility(
  uuid, public.ride_requests, boolean, boolean
) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_driver_accept_runtime_eligibility(
  uuid, public.ride_requests
) FROM PUBLIC, anon, authenticated;
