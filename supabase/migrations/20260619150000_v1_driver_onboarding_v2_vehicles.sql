-- Driver Onboarding V2: vehicle registry + sessions + plate-first claim RPC.

CREATE TABLE IF NOT EXISTS public.taxi_vehicles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plate_normalized text NOT NULL,
  plate_display text,
  rdw_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_shared_fleet boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT taxi_vehicles_plate_normalized_unique UNIQUE (plate_normalized)
);

CREATE TABLE IF NOT EXISTS public.taxi_vehicle_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id uuid NOT NULL REFERENCES public.taxi_vehicles(id) ON DELETE CASCADE,
  driver_id uuid NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  started_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  ended_at timestamptz,
  ended_reason text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE UNIQUE INDEX IF NOT EXISTS taxi_vehicle_sessions_one_active_per_vehicle
  ON public.taxi_vehicle_sessions (vehicle_id)
  WHERE is_active = true AND ended_at IS NULL;

CREATE INDEX IF NOT EXISTS taxi_vehicle_sessions_driver_active_idx
  ON public.taxi_vehicle_sessions (driver_id, started_at DESC)
  WHERE is_active = true AND ended_at IS NULL;

ALTER TABLE public.drivers
  ADD COLUMN IF NOT EXISTS taxi_vehicle_id uuid REFERENCES public.taxi_vehicles(id);

ALTER TABLE public.drivers DROP CONSTRAINT IF EXISTS drivers_vehicle_plate_unique;

-- Enable V2 readiness (plate + terms first; progressive docs later).
UPDATE public.app_config
SET value = (
  jsonb_set(
    COALESCE(value::jsonb, '{}'::jsonb),
    '{driver_onboarding_v2}',
    'true'::jsonb,
    true
  )
)::text
WHERE key = 'feature_flags';

CREATE OR REPLACE FUNCTION public.fn_driver_onboarding_v2_claim_plate(
  p_user_id uuid,
  p_vehicle_plate text,
  p_vehicle_plate_entered text DEFAULT NULL,
  p_rdw_snapshot jsonb DEFAULT '{}'::jsonb,
  p_vehicle_verification_status text DEFAULT 'rdw_verified_taxi',
  p_shared_fleet_ack boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_plate_norm text;
  v_plate_display text;
  v_vehicle_id uuid;
  v_other_driver uuid;
  v_active_session_driver uuid;
BEGIN
  IF p_user_id IS NULL OR p_vehicle_plate IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_input');
  END IF;

  IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  v_plate_norm := upper(regexp_replace(trim(p_vehicle_plate), '[\s\-]', '', 'g'));
  v_plate_display := COALESCE(NULLIF(trim(p_vehicle_plate_entered), ''), v_plate_norm);
  IF length(v_plate_norm) < 4 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_plate');
  END IF;

  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = p_user_id
  LIMIT 1;
  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'driver_not_found');
  END IF;

  SELECT tv.id INTO v_vehicle_id
  FROM public.taxi_vehicles tv
  WHERE tv.plate_normalized = v_plate_norm
  LIMIT 1;

  IF v_vehicle_id IS NOT NULL THEN
    SELECT tvs.driver_id INTO v_active_session_driver
    FROM public.taxi_vehicle_sessions tvs
    WHERE tvs.vehicle_id = v_vehicle_id
      AND tvs.is_active = true
      AND tvs.ended_at IS NULL
      AND tvs.driver_id <> v_driver_id
    LIMIT 1;

    IF v_active_session_driver IS NOT NULL AND NOT COALESCE(p_shared_fleet_ack, false) THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'vehicle_session_active',
        'shared_prompt', true
      );
    END IF;

    IF v_active_session_driver IS NOT NULL AND COALESCE(p_shared_fleet_ack, false) THEN
      UPDATE public.taxi_vehicle_sessions
      SET is_active = false,
          ended_at = timezone('utc', now()),
          ended_reason = 'takeover'
      WHERE vehicle_id = v_vehicle_id
        AND is_active = true
        AND ended_at IS NULL
        AND driver_id <> v_driver_id;
      UPDATE public.taxi_vehicles
      SET is_shared_fleet = true,
          updated_at = timezone('utc', now())
      WHERE id = v_vehicle_id;
    END IF;
  ELSE
    INSERT INTO public.taxi_vehicles (plate_normalized, plate_display, rdw_snapshot)
    VALUES (v_plate_norm, v_plate_display, COALESCE(p_rdw_snapshot, '{}'::jsonb))
    RETURNING id INTO v_vehicle_id;
  END IF;

  SELECT d.id INTO v_other_driver
  FROM public.drivers d
  WHERE upper(regexp_replace(trim(COALESCE(d.vehicle_plate, '')), '[\s\-]', '', 'g')) = v_plate_norm
    AND d.id <> v_driver_id
  LIMIT 1;

  IF v_other_driver IS NOT NULL AND NOT COALESCE(p_shared_fleet_ack, false) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'plate_linked',
      'shared_prompt', true
    );
  END IF;

  IF v_other_driver IS NOT NULL AND COALESCE(p_shared_fleet_ack, false) THEN
    UPDATE public.taxi_vehicles
    SET is_shared_fleet = true,
        updated_at = timezone('utc', now())
    WHERE id = v_vehicle_id;
  END IF;

  UPDATE public.drivers d
  SET vehicle_plate = v_plate_norm,
      vehicle_plate_entered = v_plate_display,
      taxi_vehicle_id = v_vehicle_id,
      vehicle_verification_status = COALESCE(p_vehicle_verification_status, 'rdw_verified_taxi'),
      rdw_merk = COALESCE(p_rdw_snapshot->>'merk', d.rdw_merk),
      rdw_handelsbenaming = COALESCE(p_rdw_snapshot->>'handelsbenaming', d.rdw_handelsbenaming),
      rdw_voertuigsoort = COALESCE(p_rdw_snapshot->>'voertuigsoort', d.rdw_voertuigsoort),
      rdw_eerste_kleur = COALESCE(p_rdw_snapshot->>'eerste_kleur', d.rdw_eerste_kleur),
      rdw_apk_vervaldatum = COALESCE(p_rdw_snapshot->>'vervaldatum_apk', d.rdw_apk_vervaldatum),
      updated_at = timezone('utc', now())
  WHERE d.id = v_driver_id;

  UPDATE public.taxi_vehicle_sessions
  SET is_active = false,
      ended_at = timezone('utc', now()),
      ended_reason = 'replaced'
  WHERE driver_id = v_driver_id
    AND is_active = true
    AND ended_at IS NULL;

  INSERT INTO public.taxi_vehicle_sessions (vehicle_id, driver_id, is_active)
  VALUES (v_vehicle_id, v_driver_id, true);

  RETURN jsonb_build_object(
    'success', true,
    'vehicle_id', v_vehicle_id,
    'plate', v_plate_norm
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'plate_conflict',
      'shared_prompt', true
    );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_onboarding_v2_claim_plate(uuid, text, text, jsonb, text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_onboarding_v2_claim_plate(uuid, text, text, jsonb, text, boolean) TO authenticated;

ALTER TABLE public.taxi_vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.taxi_vehicle_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS taxi_vehicles_select_driver ON public.taxi_vehicles;
CREATE POLICY taxi_vehicles_select_driver ON public.taxi_vehicles
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.drivers d
      WHERE d.user_id = auth.uid() AND d.taxi_vehicle_id = taxi_vehicles.id
    )
  );

DROP POLICY IF EXISTS taxi_vehicle_sessions_select_driver ON public.taxi_vehicle_sessions;
CREATE POLICY taxi_vehicle_sessions_select_driver ON public.taxi_vehicle_sessions
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.drivers d
      WHERE d.user_id = auth.uid() AND d.id = taxi_vehicle_sessions.driver_id
    )
  );
