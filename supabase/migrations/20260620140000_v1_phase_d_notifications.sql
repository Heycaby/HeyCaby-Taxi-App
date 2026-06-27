-- Phase D — Backend Consolidation: in-app notifications via Supabase (not Go HTTP).
-- Normalizes legacy user_id shapes, tightens RLS, adds list/mark-read RPCs.

-- ---------------------------------------------------------------------------
-- Normalize notification user_id on insert (driver.id → auth user_id)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_notifications_normalize_user_id()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_user uuid;
BEGIN
  IF NEW.user_type = 'driver' AND NEW.user_id IS NOT NULL THEN
    SELECT d.user_id INTO v_auth_user
    FROM public.drivers d
    WHERE d.id::text = NEW.user_id
       OR d.user_id::text = NEW.user_id
    LIMIT 1;
    IF v_auth_user IS NOT NULL THEN
      NEW.user_id := v_auth_user::text;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notifications_normalize_user_id ON public.notifications;
CREATE TRIGGER trg_notifications_normalize_user_id
  BEFORE INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_notifications_normalize_user_id();

-- Backfill driver rows stored as drivers.id
UPDATE public.notifications n
SET user_id = d.user_id::text
FROM public.drivers d
WHERE n.user_type = 'driver'
  AND n.user_id = d.id::text
  AND d.user_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- RLS: drivers by auth uid; riders by auth uid OR rider_identity_id
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "Users can read own notifications" ON public.notifications;
CREATE POLICY "Users can read own notifications"
  ON public.notifications
  FOR SELECT
  TO authenticated
  USING (
    (user_type = 'driver' AND user_id = auth.uid()::text)
    OR (
      user_type = 'rider'
      AND (
        user_id = auth.uid()::text
        OR user_id IN (
          SELECT ri.id::text
          FROM public.rider_identities ri
          WHERE ri.user_id = auth.uid()
        )
      )
    )
  );

DROP POLICY IF EXISTS "Users can update own notifications (read_at)" ON public.notifications;
CREATE POLICY "Users can update own notifications (read_at)"
  ON public.notifications
  FOR UPDATE
  TO authenticated
  USING (
    (user_type = 'driver' AND user_id = auth.uid()::text)
    OR (
      user_type = 'rider'
      AND (
        user_id = auth.uid()::text
        OR user_id IN (
          SELECT ri.id::text
          FROM public.rider_identities ri
          WHERE ri.user_id = auth.uid()
        )
      )
    )
  )
  WITH CHECK (
    (user_type = 'driver' AND user_id = auth.uid()::text)
    OR (
      user_type = 'rider'
      AND (
        user_id = auth.uid()::text
        OR user_id IN (
          SELECT ri.id::text
          FROM public.rider_identities ri
          WHERE ri.user_id = auth.uid()
        )
      )
    )
  );

DROP POLICY IF EXISTS notifications_update_own ON public.notifications;

DROP POLICY IF EXISTS "Users can delete own notifications" ON public.notifications;
CREATE POLICY "Users can delete own notifications"
  ON public.notifications
  FOR DELETE
  TO authenticated
  USING (
    (user_type = 'driver' AND user_id = auth.uid()::text)
    OR (
      user_type = 'rider'
      AND (
        user_id = auth.uid()::text
        OR user_id IN (
          SELECT ri.id::text
          FROM public.rider_identities ri
          WHERE ri.user_id = auth.uid()
        )
      )
    )
  );

-- ---------------------------------------------------------------------------
-- Owner id resolution (internal)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_app_notification_owner_ids(
  p_user_type text,
  p_rider_identity_id uuid DEFAULT NULL
)
RETURNS text[]
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ids text[] := ARRAY[]::text[];
  v_uid text := auth.uid()::text;
BEGIN
  IF v_uid IS NULL OR v_uid = '' THEN
    RETURN v_ids;
  END IF;

  IF lower(trim(p_user_type)) = 'driver' THEN
    v_ids := array_append(v_ids, v_uid);
    SELECT array_agg(DISTINCT x) INTO v_ids
    FROM (
      SELECT unnest(v_ids) AS x
      UNION
      SELECT d.id::text FROM public.drivers d WHERE d.user_id = auth.uid()
    ) s
    WHERE x IS NOT NULL;
    RETURN COALESCE(v_ids, ARRAY[v_uid]);
  END IF;

  IF lower(trim(p_user_type)) = 'rider' THEN
    v_ids := array_append(v_ids, v_uid);
    IF p_rider_identity_id IS NOT NULL THEN
      IF EXISTS (
        SELECT 1 FROM public.rider_identities ri
        WHERE ri.id = p_rider_identity_id
          AND (ri.user_id = auth.uid() OR ri.user_id IS NULL)
      ) THEN
        v_ids := array_append(v_ids, p_rider_identity_id::text);
      END IF;
    END IF;
    SELECT array_agg(DISTINCT x) INTO v_ids
    FROM (
      SELECT unnest(v_ids) AS x
      UNION
      SELECT ri.id::text FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
    ) s
    WHERE x IS NOT NULL;
    RETURN COALESCE(v_ids, ARRAY[v_uid]);
  END IF;

  RETURN v_ids;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_app_notification_owner_ids(text, uuid) FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- List / mark read RPCs
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_app_notifications_list(
  p_user_type text,
  p_unread_only boolean DEFAULT false,
  p_limit int DEFAULT 30,
  p_rider_identity_id uuid DEFAULT NULL
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
  v_rows jsonb;
BEGIN
  v_ids := public.fn_app_notification_owner_ids(p_user_type, p_rider_identity_id);
  IF v_ids IS NULL OR array_length(v_ids, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated', 'notifications', '[]'::jsonb);
  END IF;

  v_lim := GREATEST(1, LEAST(COALESCE(p_limit, 30), 100));

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
      AND (NOT p_unread_only OR n.read_at IS NULL)
    ORDER BY n.created_at DESC
    LIMIT v_lim
  ) q;

  RETURN jsonb_build_object('ok', true, 'notifications', v_rows);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_app_notifications_list(text, boolean, int, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_app_notifications_list(text, boolean, int, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_app_notification_mark_read(p_notification_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.notifications%ROWTYPE;
  v_ids text[];
BEGIN
  IF p_notification_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_id');
  END IF;

  SELECT * INTO v_row
  FROM public.notifications n
  WHERE n.id = p_notification_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_found');
  END IF;

  IF v_row.user_type = 'rider'
     AND v_row.user_id ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
  THEN
    v_ids := public.fn_app_notification_owner_ids('rider', v_row.user_id::uuid);
  ELSE
    v_ids := public.fn_app_notification_owner_ids(v_row.user_type, NULL);
  END IF;

  IF NOT (v_row.user_id = ANY (v_ids)) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'forbidden');
  END IF;

  UPDATE public.notifications
  SET read_at = timezone('utc', now())
  WHERE id = p_notification_id
    AND read_at IS NULL;

  RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_app_notification_mark_read(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_app_notification_mark_read(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_app_notifications_mark_all_read(
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
  v_updated int;
BEGIN
  v_ids := public.fn_app_notification_owner_ids(p_user_type, p_rider_identity_id);
  IF v_ids IS NULL OR array_length(v_ids, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;

  UPDATE public.notifications n
  SET read_at = timezone('utc', now())
  WHERE n.user_type = lower(trim(p_user_type))
    AND n.user_id = ANY (v_ids)
    AND n.read_at IS NULL;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'updated', v_updated);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_app_notifications_mark_all_read(text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_app_notifications_mark_all_read(text, uuid) TO authenticated;

COMMENT ON FUNCTION public.fn_app_notifications_list(text, boolean, int, uuid) IS
  'Phase D: list in-app notifications for driver or rider (Supabase-first).';
COMMENT ON FUNCTION public.fn_app_notification_mark_read(uuid) IS
  'Phase D: mark one notification read.';
COMMENT ON FUNCTION public.fn_app_notifications_mark_all_read(text, uuid) IS
  'Phase D: mark all notifications read for current user.';

-- Enable Realtime for in-app notification delivery (RLS-scoped per client).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END $$;
