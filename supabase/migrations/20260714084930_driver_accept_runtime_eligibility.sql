-- Canonical accept-time Driver eligibility projection.
--
-- Dispatch decides who should receive an invite. This helper rechecks the
-- mutable, non-financial predicates immediately before an invite is accepted.
-- Billing, tariff, GPS freshness and payment compatibility retain their
-- existing dedicated error contracts in fn_driver_accept_ride_invite.
CREATE OR REPLACE FUNCTION public.fn_driver_accept_runtime_eligibility(
  p_driver_id uuid,
  p_ride public.ride_requests
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

  IF v_driver.status::text IS DISTINCT FROM 'available' THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'reason', 'driver_offline',
      'message', 'Go online before accepting a ride.',
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

  IF public.fn_driver_has_queued_taxi_terug(p_driver_id) THEN
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

  IF COALESCE(p_ride.pet_friendly, false)
     AND NOT COALESCE(v_driver.accepts_pets, false) THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'reason', 'pets_not_supported',
      'message', 'This ride requires a pet-friendly vehicle.'
    );
  END IF;

  RETURN jsonb_build_object('eligible', true, 'reason', 'eligible');
END;
$$;

COMMENT ON FUNCTION public.fn_driver_accept_runtime_eligibility(uuid, public.ride_requests)
IS 'Internal acceptance-time recheck for mutable Driver readiness, presence, compliance, queue and ride-fit predicates.';

REVOKE ALL ON FUNCTION public.fn_driver_accept_runtime_eligibility(
  uuid, public.ride_requests
) FROM PUBLIC, anon, authenticated;
