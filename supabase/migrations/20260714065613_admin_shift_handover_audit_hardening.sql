-- Preserve the released Shift Handover Admin/Fleet RPC and its compatibility
-- grants while making every attempted mutation observable.

CREATE OR REPLACE FUNCTION public.fn_admin_shift_handover_allowlist_set(
  p_vehicle_id uuid,
  p_driver_id uuid,
  p_add boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private
AS $$
DECLARE
  v_actor_user uuid := auth.uid();
  v_actor_driver uuid;
  v_before boolean := false;
  v_after boolean := false;
  v_changed boolean := false;
  v_correlation_id uuid := gen_random_uuid();
BEGIN
  IF p_vehicle_id IS NULL OR p_driver_id IS NULL THEN
    INSERT INTO private.domain_security_events(
      domain, event, actor_user_id, object_id, metadata
    ) VALUES (
      'fleet',
      'shift_handover_allowlist_denied',
      v_actor_user,
      p_vehicle_id,
      jsonb_build_object(
        'reason', 'invalid_target',
        'target_driver_id', p_driver_id,
        'action', CASE WHEN coalesce(p_add, true) THEN 'add' ELSE 'remove' END,
        'correlation_id', v_correlation_id
      )
    );
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'invalid_target',
      'correlation_id', v_correlation_id
    );
  END IF;

  IF public.fn_shift_handover_fleet_can_manage_vehicle(p_vehicle_id)
     IS DISTINCT FROM true THEN
    INSERT INTO private.domain_security_events(
      domain, event, actor_user_id, object_id, metadata
    ) VALUES (
      'fleet',
      'shift_handover_allowlist_denied',
      v_actor_user,
      p_vehicle_id,
      jsonb_build_object(
        'reason', 'forbidden',
        'target_driver_id', p_driver_id,
        'action', CASE WHEN coalesce(p_add, true) THEN 'add' ELSE 'remove' END,
        'correlation_id', v_correlation_id
      )
    );
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'forbidden',
      'correlation_id', v_correlation_id
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.drivers d WHERE d.id = p_driver_id) THEN
    INSERT INTO private.domain_security_events(
      domain, event, actor_user_id, object_id, metadata
    ) VALUES (
      'fleet',
      'shift_handover_allowlist_denied',
      v_actor_user,
      p_vehicle_id,
      jsonb_build_object(
        'reason', 'driver_not_found',
        'target_driver_id', p_driver_id,
        'action', CASE WHEN coalesce(p_add, true) THEN 'add' ELSE 'remove' END,
        'correlation_id', v_correlation_id
      )
    );
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'driver_not_found',
      'correlation_id', v_correlation_id
    );
  END IF;

  SELECT d.id
  INTO v_actor_driver
  FROM public.drivers d
  WHERE d.user_id = v_actor_user
  LIMIT 1;

  SELECT EXISTS (
    SELECT 1
    FROM public.taxi_vehicle_driver_allowlist av
    WHERE av.vehicle_id = p_vehicle_id
      AND av.driver_id = p_driver_id
  ) INTO v_before;

  IF coalesce(p_add, true) THEN
    INSERT INTO public.taxi_vehicle_driver_allowlist(
      vehicle_id, driver_id, added_by_driver_id
    ) VALUES (
      p_vehicle_id, p_driver_id, v_actor_driver
    )
    ON CONFLICT (vehicle_id, driver_id) DO NOTHING;
  ELSE
    DELETE FROM public.taxi_vehicle_driver_allowlist av
    WHERE av.vehicle_id = p_vehicle_id
      AND av.driver_id = p_driver_id;
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.taxi_vehicle_driver_allowlist av
    WHERE av.vehicle_id = p_vehicle_id
      AND av.driver_id = p_driver_id
  ) INTO v_after;
  v_changed := v_before IS DISTINCT FROM v_after;

  INSERT INTO private.domain_security_events(
    domain, event, actor_user_id, object_id, metadata
  ) VALUES (
    'fleet',
    'shift_handover_allowlist_changed',
    v_actor_user,
    p_vehicle_id,
    jsonb_build_object(
      'actor_driver_id', v_actor_driver,
      'target_driver_id', p_driver_id,
      'action', CASE WHEN coalesce(p_add, true) THEN 'add' ELSE 'remove' END,
      'before_present', v_before,
      'after_present', v_after,
      'changed', v_changed,
      'correlation_id', v_correlation_id
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'changed', v_changed,
    'correlation_id', v_correlation_id
  );
END;
$$;

COMMENT ON FUNCTION public.fn_admin_shift_handover_allowlist_set(uuid, uuid, boolean) IS
  'Canonical Fleet/Admin allowlist mutation with server-side authorization and correlated before/after audit events.';
