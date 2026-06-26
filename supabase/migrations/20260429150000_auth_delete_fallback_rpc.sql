-- Fallback for projects where Auth REST self-delete is disabled (DELETE /auth/v1/user => 405).
-- Allows an authenticated user to delete only their own auth.users row via SECURITY DEFINER.

CREATE OR REPLACE FUNCTION public.fn_delete_current_auth_user()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  DELETE FROM auth.users
  WHERE id = v_uid;

  RETURN jsonb_build_object('success', true, 'deleted', true);
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_delete_current_auth_user() TO authenticated;
