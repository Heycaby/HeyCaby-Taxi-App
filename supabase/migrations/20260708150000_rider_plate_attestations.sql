-- Rider plate attestation: one row per ride — rider confirms expected plate before boarding.

CREATE TABLE IF NOT EXISTS public.rider_plate_attestations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_request_id uuid NOT NULL UNIQUE
    REFERENCES public.ride_requests(id) ON DELETE CASCADE,
  rider_identity_id uuid NOT NULL
    REFERENCES public.rider_identities(id) ON DELETE CASCADE,
  driver_id uuid REFERENCES public.drivers(id) ON DELETE SET NULL,
  expected_plate text NOT NULL DEFAULT '',
  expected_plate_normalized text NOT NULL DEFAULT '',
  ride_status text NOT NULL DEFAULT '',
  outcome text NOT NULL DEFAULT 'confirmed'
    CHECK (outcome IN ('confirmed', 'reported_mismatch')),
  verified_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_rider_plate_attestations_rider
  ON public.rider_plate_attestations (rider_identity_id, verified_at DESC);

CREATE INDEX IF NOT EXISTS idx_rider_plate_attestations_driver
  ON public.rider_plate_attestations (driver_id, verified_at DESC)
  WHERE driver_id IS NOT NULL;

COMMENT ON TABLE public.rider_plate_attestations IS
  'Rider self-attestation that they verified the assigned vehicle plate for a ride (once per ride_request_id).';

ALTER TABLE public.rider_plate_attestations ENABLE ROW LEVEL SECURITY;

CREATE POLICY rider_plate_attestations_select_own
  ON public.rider_plate_attestations
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.rider_identities ri
      WHERE ri.id = rider_plate_attestations.rider_identity_id
        AND ri.user_id = auth.uid()
    )
  );

-- Writes go through SECURITY DEFINER RPC only.
CREATE POLICY rider_plate_attestations_no_direct_insert
  ON public.rider_plate_attestations
  FOR INSERT
  TO authenticated
  WITH CHECK (false);

CREATE POLICY rider_plate_attestations_no_direct_update
  ON public.rider_plate_attestations
  FOR UPDATE
  TO authenticated
  USING (false);

CREATE OR REPLACE FUNCTION public.fn_rider_attest_plate(
  p_ride_request_id uuid,
  p_expected_plate text DEFAULT NULL,
  p_outcome text DEFAULT 'confirmed'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_plate text;
  v_plate_norm text;
  v_outcome text;
  v_row public.rider_plate_attestations%ROWTYPE;
  v_auth_ok boolean;
BEGIN
  IF p_ride_request_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'missing_ride_id');
  END IF;

  v_outcome := lower(trim(COALESCE(p_outcome, 'confirmed')));
  IF v_outcome NOT IN ('confirmed', 'reported_mismatch') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'invalid_outcome');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests
  WHERE id = p_ride_request_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'ride_not_found');
  END IF;

  IF v_ride.rider_identity_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'no_rider_identity');
  END IF;

  IF auth.uid() IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.rider_identities ri
      WHERE ri.id = v_ride.rider_identity_id
        AND ri.user_id = auth.uid()
    ) INTO v_auth_ok;
    IF NOT v_auth_ok THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'not_authorized');
    END IF;
  END IF;

  IF v_ride.status NOT IN (
    'driver_found', 'assigned', 'accepted', 'driver_arrived', 'arrived', 'in_progress'
  ) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'ride_not_active', 'status', v_ride.status);
  END IF;

  IF v_ride.driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'no_driver_assigned');
  END IF;

  v_plate := trim(COALESCE(
    NULLIF(p_expected_plate, ''),
    (SELECT d.vehicle_plate FROM public.drivers d WHERE d.id = v_ride.driver_id),
    ''
  ));
  v_plate_norm := upper(regexp_replace(v_plate, '[\s\-]', '', 'g'));

  INSERT INTO public.rider_plate_attestations (
    ride_request_id,
    rider_identity_id,
    driver_id,
    expected_plate,
    expected_plate_normalized,
    ride_status,
    outcome,
    verified_at,
    updated_at
  ) VALUES (
    p_ride_request_id,
    v_ride.rider_identity_id,
    v_ride.driver_id,
    v_plate,
    v_plate_norm,
    v_ride.status,
    v_outcome,
    timezone('utc', now()),
    timezone('utc', now())
  )
  ON CONFLICT (ride_request_id) DO UPDATE SET
    driver_id = EXCLUDED.driver_id,
    expected_plate = EXCLUDED.expected_plate,
    expected_plate_normalized = EXCLUDED.expected_plate_normalized,
    ride_status = EXCLUDED.ride_status,
    outcome = EXCLUDED.outcome,
    verified_at = EXCLUDED.verified_at,
    updated_at = timezone('utc', now())
  RETURNING * INTO v_row;

  INSERT INTO public.ride_audit_log (
    ride_id,
    event,
    actor_id,
    actor_type,
    occurred_at,
    metadata,
    source
  ) VALUES (
    p_ride_request_id,
    'rider.plate_attested',
    v_ride.rider_identity_id,
    'rider',
    timezone('utc', now()),
    jsonb_build_object(
      'ride_request_id', p_ride_request_id,
      'driver_id', v_ride.driver_id,
      'expected_plate', v_plate,
      'expected_plate_normalized', v_plate_norm,
      'outcome', v_outcome,
      'ride_status', v_ride.status,
      'attestation_id', v_row.id
    ),
    'fn_rider_attest_plate'
  );

  RETURN jsonb_build_object(
    'ok', true,
    'attestation_id', v_row.id,
    'ride_request_id', v_row.ride_request_id,
    'expected_plate', v_row.expected_plate,
    'outcome', v_row.outcome,
    'verified_at', v_row.verified_at
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_rider_plate_attestation_for_ride(
  p_ride_request_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_row public.rider_plate_attestations%ROWTYPE;
  v_auth_ok boolean;
BEGIN
  IF p_ride_request_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'missing_ride_id');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests
  WHERE id = p_ride_request_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'ride_not_found');
  END IF;

  IF v_ride.rider_identity_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'no_rider_identity');
  END IF;

  IF auth.uid() IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.rider_identities ri
      WHERE ri.id = v_ride.rider_identity_id
        AND ri.user_id = auth.uid()
    ) INTO v_auth_ok;
    IF NOT v_auth_ok THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'not_authorized');
    END IF;
  END IF;

  SELECT * INTO v_row
  FROM public.rider_plate_attestations
  WHERE ride_request_id = p_ride_request_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'verified', false);
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'verified', true,
    'attestation_id', v_row.id,
    'expected_plate', v_row.expected_plate,
    'outcome', v_row.outcome,
    'verified_at', v_row.verified_at,
    'ride_status', v_row.ride_status
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.fn_rider_attest_plate(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_rider_plate_attestation_for_ride(uuid) TO authenticated;
