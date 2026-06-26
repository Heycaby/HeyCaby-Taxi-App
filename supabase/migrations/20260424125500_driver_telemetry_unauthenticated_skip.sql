-- Make telemetry RPC explicit and safe for unauthenticated contexts.
-- No schema/table changes. Function-only replacement.

CREATE OR REPLACE FUNCTION public.fn_driver_log_client_telemetry(
  p_scope text,
  p_event text,
  p_detail text DEFAULT NULL,
  p_extra jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_driver_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', true,
      'skipped', 'unauthenticated'
    );
  END IF;

  SELECT d.id
  INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = v_user_id
  LIMIT 1;

  INSERT INTO public.driver_client_telemetry_events(
    user_id,
    driver_id,
    scope,
    event,
    detail,
    extra
  )
  VALUES (
    v_user_id,
    v_driver_id,
    COALESCE(NULLIF(trim(p_scope), ''), 'unknown'),
    COALESCE(NULLIF(trim(p_event), ''), 'unknown'),
    p_detail,
    p_extra
  );

  RETURN jsonb_build_object('ok', true);
END;
$$;
