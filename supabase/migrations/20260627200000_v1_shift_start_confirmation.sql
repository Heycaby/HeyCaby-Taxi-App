-- Shift-start confirmation alias + audit reason rename (additive; keeps p_shared_fleet_ack).

DROP FUNCTION IF EXISTS public.fn_driver_onboarding_v2_claim_plate(uuid, text, text, jsonb, text, boolean);

CREATE OR REPLACE FUNCTION public.fn_driver_onboarding_v2_claim_plate(
  p_user_id uuid,
  p_vehicle_plate text,
  p_vehicle_plate_entered text DEFAULT NULL,
  p_rdw_snapshot jsonb DEFAULT '{}'::jsonb,
  p_vehicle_verification_status text DEFAULT 'rdw_verified_taxi',
  p_shared_fleet_ack boolean DEFAULT false,
  p_confirm_shift_start boolean DEFAULT NULL
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
  v_active_session jsonb;
  v_verification_status public.vehicle_verification_status;
  v_shift_ack boolean;
BEGIN
  v_shift_ack := COALESCE(p_confirm_shift_start, p_shared_fleet_ack, false);

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

  v_verification_status := COALESCE(
    NULLIF(trim(p_vehicle_verification_status), ''),
    'rdw_verified_taxi'
  )::public.vehicle_verification_status;

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

  v_active_session := NULL;

  IF v_vehicle_id IS NOT NULL THEN
    SELECT
      tvs.driver_id,
      jsonb_build_object(
        'started_at', tvs.started_at,
        'status_label', CASE
          WHEN d.status::text IN ('available', 'on_ride') THEN 'online'
          ELSE 'offline'
        END
      )
    INTO v_active_session_driver, v_active_session
    FROM public.taxi_vehicle_sessions tvs
    JOIN public.drivers d ON d.id = tvs.driver_id
    WHERE tvs.vehicle_id = v_vehicle_id
      AND tvs.is_active = true
      AND tvs.ended_at IS NULL
      AND tvs.driver_id <> v_driver_id
    LIMIT 1;

    IF v_active_session_driver IS NOT NULL AND NOT v_shift_ack THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'vehicle_session_active',
        'shared_prompt', true,
        'shift_start_prompt', true,
        'active_session', v_active_session
      );
    END IF;

    IF v_active_session_driver IS NOT NULL AND v_shift_ack THEN
      UPDATE public.taxi_vehicle_sessions
      SET is_active = false,
          ended_at = timezone('utc', now()),
          ended_reason = 'shift_handover'
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

  IF v_other_driver IS NOT NULL AND NOT v_shift_ack THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'plate_linked',
      'shared_prompt', true,
      'shift_start_prompt', true,
      'active_session', NULL
    );
  END IF;

  IF v_other_driver IS NOT NULL AND v_shift_ack THEN
    UPDATE public.taxi_vehicles
    SET is_shared_fleet = true,
        updated_at = timezone('utc', now())
    WHERE id = v_vehicle_id;
  END IF;

  UPDATE public.drivers d
  SET vehicle_plate = v_plate_norm,
      vehicle_plate_entered = v_plate_display,
      taxi_vehicle_id = v_vehicle_id,
      vehicle_verification_status = v_verification_status,
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
      'shared_prompt', true,
      'shift_start_prompt', true,
      'active_session', NULL
    );
  WHEN invalid_text_representation THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'invalid_verification_status'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_onboarding_v2_claim_plate(uuid, text, text, jsonb, text, boolean, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_onboarding_v2_claim_plate(uuid, text, text, jsonb, text, boolean, boolean) TO authenticated;

COMMENT ON FUNCTION public.fn_driver_onboarding_v2_claim_plate(uuid, text, text, jsonb, text, boolean, boolean) IS
  'Plate claim V2. p_confirm_shift_start (preferred) or legacy p_shared_fleet_ack ends prior vehicle session with shift_handover.';
