-- Fix driver self-delete flow:
-- `fn_delete_driver_owned_data` must remove child rows that reference `drivers.id`
-- before deleting from `public.drivers`.

CREATE OR REPLACE FUNCTION public.fn_delete_driver_owned_data()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_driver_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT d.id
  INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = v_uid
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('success', true, 'deleted', false, 'reason', 'driver_not_found');
  END IF;

  -- Legacy table in production can reference drivers without ON DELETE CASCADE.
  IF to_regclass('public.driver_email_events') IS NOT NULL THEN
    DELETE FROM public.driver_email_events
    WHERE driver_id = v_driver_id;
  END IF;

  DELETE FROM public.drivers
  WHERE id = v_driver_id;

  RETURN jsonb_build_object('success', true, 'deleted', true);
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_delete_driver_owned_data() TO authenticated;
