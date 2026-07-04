-- Clear already-read in-app notifications for the current authenticated user.
-- This keeps unread/urgent notifications visible until the user has explicitly
-- marked them read, then lets the app remove old read items from the feed.

CREATE OR REPLACE FUNCTION public.fn_app_notifications_clear_read(
  p_user_type text,
  p_rider_identity_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ids text[];
  v_deleted int;
BEGIN
  v_ids := public.fn_app_notification_owner_ids(p_user_type, p_rider_identity_id);
  IF v_ids IS NULL OR array_length(v_ids, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;

  DELETE FROM public.notifications n
  WHERE n.user_type = lower(trim(p_user_type))
    AND n.user_id = ANY (v_ids)
    AND n.read_at IS NOT NULL;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'deleted', v_deleted);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_app_notifications_clear_read(text, uuid)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_app_notifications_clear_read(text, uuid)
  TO authenticated;

COMMENT ON FUNCTION public.fn_app_notifications_clear_read(text, uuid) IS
  'Clear already-read in-app notifications for the current driver or rider.';
