-- In-app notifications: keep last 24 hours, purge older rows on list, allow bulk delete.

DROP FUNCTION IF EXISTS public.fn_app_notifications_list(text, boolean, int, uuid);

CREATE OR REPLACE FUNCTION public.fn_app_notifications_list(
  p_user_type text,
  p_unread_only boolean DEFAULT false,
  p_limit int DEFAULT 30,
  p_rider_identity_id uuid DEFAULT NULL,
  p_max_age_hours int DEFAULT 24
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ids text[];
  v_lim int;
  v_max_age int;
  v_rows jsonb;
  v_purged int;
BEGIN
  v_ids := public.fn_app_notification_owner_ids(p_user_type, p_rider_identity_id);
  IF v_ids IS NULL OR array_length(v_ids, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated', 'notifications', '[]'::jsonb);
  END IF;

  v_lim := GREATEST(1, LEAST(COALESCE(p_limit, 30), 100));
  v_max_age := GREATEST(1, LEAST(COALESCE(p_max_age_hours, 24), 168));

  DELETE FROM public.notifications n
  WHERE n.user_type = lower(trim(p_user_type))
    AND n.user_id = ANY (v_ids)
    AND n.created_at < now() - make_interval(hours => v_max_age);
  GET DIAGNOSTICS v_purged = ROW_COUNT;

  SELECT COALESCE(jsonb_agg(row_data ORDER BY sort_at DESC), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT
      n.created_at AS sort_at,
      jsonb_build_object(
        'id', n.id,
        'title', n.title,
        'body', n.body,
        'category', n.category,
        'priority', n.priority,
        'read_at', n.read_at,
        'created_at', n.created_at,
        'data', COALESCE(n.data, '{}'::jsonb),
        'user_type', n.user_type,
        'channel', n.channel
      ) AS row_data
    FROM public.notifications n
    WHERE n.user_type = lower(trim(p_user_type))
      AND n.user_id = ANY (v_ids)
      AND n.created_at >= now() - make_interval(hours => v_max_age)
      AND (NOT p_unread_only OR n.read_at IS NULL)
    ORDER BY n.created_at DESC
    LIMIT v_lim
  ) q;

  RETURN jsonb_build_object(
    'ok', true,
    'notifications', v_rows,
    'purged', v_purged,
    'max_age_hours', v_max_age
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_app_notifications_delete_all(
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
    AND n.user_id = ANY (v_ids);

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'deleted', v_deleted);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_app_notifications_delete_ids(
  p_notification_ids uuid[],
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
  IF p_notification_ids IS NULL OR array_length(p_notification_ids, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_ids');
  END IF;

  v_ids := public.fn_app_notification_owner_ids(p_user_type, p_rider_identity_id);
  IF v_ids IS NULL OR array_length(v_ids, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;

  DELETE FROM public.notifications n
  WHERE n.id = ANY (p_notification_ids)
    AND n.user_type = lower(trim(p_user_type))
    AND n.user_id = ANY (v_ids);

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'deleted', v_deleted);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_app_notifications_list(text, boolean, int, uuid, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_app_notifications_list(text, boolean, int, uuid, int) TO authenticated;

REVOKE ALL ON FUNCTION public.fn_app_notifications_delete_all(text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_app_notifications_delete_all(text, uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.fn_app_notifications_delete_ids(uuid[], text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_app_notifications_delete_ids(uuid[], text, uuid) TO authenticated;

COMMENT ON FUNCTION public.fn_app_notifications_list(text, boolean, int, uuid, int) IS
  'List in-app notifications for the current user; purges rows older than p_max_age_hours (default 24).';

COMMENT ON FUNCTION public.fn_app_notifications_delete_all(text, uuid) IS
  'Delete all in-app notifications for the current driver or rider.';

COMMENT ON FUNCTION public.fn_app_notifications_delete_ids(uuid[], text, uuid) IS
  'Delete selected in-app notifications owned by the current user.';
