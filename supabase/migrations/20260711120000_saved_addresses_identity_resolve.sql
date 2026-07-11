-- Saved places failed for riders whose device session token was bound but
-- rider_identities.user_id did not match the current auth.uid() (hot restart,
-- email login on a new anonymous auth user, etc.). Resolve identity the same
-- way as fn_rider_my_rides: user_id, verified email, and push device link.

CREATE OR REPLACE FUNCTION public.fn_rider_resolve_identity_id()
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_identity_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT ri.id
  INTO v_identity_id
  FROM public.rider_identities ri
  LEFT JOIN auth.users au ON au.id = v_uid
  WHERE ri.user_id = v_uid
     OR (
       NULLIF(btrim(ri.email), '') IS NOT NULL
       AND NULLIF(btrim(au.email::text), '') IS NOT NULL
       AND lower(btrim(ri.email)) = lower(btrim(au.email::text))
     )
     OR EXISTS (
       SELECT 1
       FROM public.push_devices pd
       WHERE pd.auth_user_id = v_uid
         AND pd.app_role = 'rider'
         AND pd.rider_identity_id = ri.id
     )
     OR EXISTS (
       SELECT 1
       FROM public.rider_sessions rs
       JOIN public.ride_requests rr ON rr.rider_token = rs.session_token
       WHERE rs.user_id = v_uid
         AND rr.rider_identity_id = ri.id
     )
  ORDER BY
    CASE WHEN ri.user_id = v_uid THEN 0 ELSE 1 END,
    ri.updated_at DESC NULLS LAST,
    ri.created_at DESC
  LIMIT 1;

  RETURN v_identity_id;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_resolve_identity_id() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_rider_resolve_identity_id() TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_rider_saved_addresses_list()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_identity_id uuid;
  v_addresses jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;

  v_identity_id := public.fn_rider_resolve_identity_id();

  IF v_identity_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'rider_identity_not_found');
  END IF;

  SELECT COALESCE(jsonb_agg(to_jsonb(sa) ORDER BY sa.created_at), '[]'::jsonb)
  INTO v_addresses
  FROM public.saved_addresses sa
  WHERE sa.rider_identity_id = v_identity_id
    AND sa.type <> 'recent';

  RETURN jsonb_build_object(
    'ok', true,
    'rider_identity_id', v_identity_id,
    'addresses', v_addresses
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_rider_saved_address_add(
  p_type text,
  p_label text,
  p_full_address text,
  p_latitude double precision,
  p_longitude double precision
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_identity_id uuid;
  v_type text := lower(NULLIF(btrim(COALESCE(p_type, '')), ''));
  v_label text := NULLIF(btrim(COALESCE(p_label, '')), '');
  v_full_address text := NULLIF(btrim(COALESCE(p_full_address, '')), '');
  v_count integer;
  v_saved public.saved_addresses%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;

  v_identity_id := public.fn_rider_resolve_identity_id();

  IF v_identity_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'rider_identity_not_found');
  END IF;

  PERFORM 1
  FROM public.rider_identities ri
  WHERE ri.id = v_identity_id
  FOR UPDATE;

  IF v_type IS NULL OR v_type NOT IN ('home', 'work', 'gym', 'custom') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_type');
  END IF;
  IF v_label IS NULL OR char_length(v_label) > 80 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_label');
  END IF;
  IF v_full_address IS NULL OR char_length(v_full_address) > 500 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_address');
  END IF;
  IF p_latitude IS NULL OR NOT (p_latitude BETWEEN -90.0 AND 90.0)
     OR p_longitude IS NULL OR NOT (p_longitude BETWEEN -180.0 AND 180.0) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_coordinates');
  END IF;

  SELECT count(*) INTO v_count
  FROM public.saved_addresses sa
  WHERE sa.rider_identity_id = v_identity_id
    AND sa.type <> 'recent';

  IF v_count >= 10 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'limit_reached', 'limit', 10);
  END IF;

  INSERT INTO public.saved_addresses (
    rider_identity_id, type, label, full_address, latitude, longitude
  ) VALUES (
    v_identity_id, v_type, v_label, v_full_address, p_latitude, p_longitude
  )
  RETURNING * INTO v_saved;

  RETURN jsonb_build_object('ok', true, 'address', to_jsonb(v_saved));
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_rider_saved_address_delete(
  p_saved_address_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_identity_id uuid;
  v_deleted_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;
  IF p_saved_address_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_address_id');
  END IF;

  v_identity_id := public.fn_rider_resolve_identity_id();
  IF v_identity_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'rider_identity_not_found');
  END IF;

  DELETE FROM public.saved_addresses sa
  WHERE sa.id = p_saved_address_id
    AND sa.type <> 'recent'
    AND sa.rider_identity_id = v_identity_id
  RETURNING sa.id INTO v_deleted_id;

  IF v_deleted_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'address_not_found');
  END IF;
  RETURN jsonb_build_object('ok', true, 'deleted_id', v_deleted_id);
END;
$$;

COMMENT ON FUNCTION public.fn_rider_resolve_identity_id() IS
  'Resolves the rider identity owned by auth.uid() via user_id, email, push device, or bound session rides.';
