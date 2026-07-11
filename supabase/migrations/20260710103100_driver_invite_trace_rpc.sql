-- Participant-scoped observability for incoming invite opens and views.

CREATE OR REPLACE FUNCTION public.fn_driver_trace_invite(
  p_invite_id uuid,
  p_event text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride_id uuid;
  v_driver_id uuid;
  v_actor_id uuid := auth.uid();
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'unauthorized' USING ERRCODE = '42501';
  END IF;
  IF p_event NOT IN ('opened', 'viewed') THEN
    RAISE EXCEPTION 'invalid_event' USING ERRCODE = '22023';
  END IF;

  SELECT rri.ride_request_id, rri.driver_id
  INTO v_ride_id, v_driver_id
  FROM public.ride_request_invites rri
  JOIN public.drivers d ON d.id = rri.driver_id
  WHERE rri.id = p_invite_id
    AND d.user_id = v_actor_id
  LIMIT 1;

  IF v_ride_id IS NULL THEN
    RAISE EXCEPTION 'invite_not_found' USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.ride_audit_log (
    ride_id,
    event,
    actor_id,
    actor_type,
    source,
    metadata
  ) VALUES (
    v_ride_id,
    'invite.' || p_event,
    v_actor_id,
    'driver',
    'driver_app',
    jsonb_build_object(
      'invite_id', p_invite_id,
      'driver_id', v_driver_id
    )
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_trace_invite(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_trace_invite(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.fn_driver_trace_invite(uuid, text) TO authenticated;
