-- Saved places contain private location data. Bind every client operation to
-- the authenticated rider identity and keep the saved-place limit server-side.

ALTER TABLE public.saved_addresses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS riders_delete_saved_addresses ON public.saved_addresses;
DROP POLICY IF EXISTS riders_insert_saved_addresses ON public.saved_addresses;
DROP POLICY IF EXISTS riders_select_saved_addresses ON public.saved_addresses;
DROP POLICY IF EXISTS riders_update_saved_addresses ON public.saved_addresses;
DROP POLICY IF EXISTS service_role_manage_saved_addresses ON public.saved_addresses;

CREATE POLICY riders_select_own_saved_addresses
ON public.saved_addresses FOR SELECT TO authenticated
USING (rider_identity_id IN (
  SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
));

CREATE POLICY riders_insert_own_saved_addresses
ON public.saved_addresses FOR INSERT TO authenticated
WITH CHECK (rider_identity_id IN (
  SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
));

CREATE POLICY riders_update_own_saved_addresses
ON public.saved_addresses FOR UPDATE TO authenticated
USING (rider_identity_id IN (
  SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
))
WITH CHECK (rider_identity_id IN (
  SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
));

CREATE POLICY riders_delete_own_saved_addresses
ON public.saved_addresses FOR DELETE TO authenticated
USING (rider_identity_id IN (
  SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
));

CREATE POLICY service_role_manage_saved_addresses
ON public.saved_addresses FOR ALL TO service_role
USING (true) WITH CHECK (true);

REVOKE ALL ON TABLE public.saved_addresses FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.saved_addresses TO authenticated;
GRANT ALL ON TABLE public.saved_addresses TO service_role;

CREATE OR REPLACE FUNCTION public.fn_rider_saved_addresses_list()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_identity_id uuid;
  v_addresses jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;

  SELECT ri.id INTO v_identity_id
  FROM public.rider_identities ri
  WHERE ri.user_id = v_uid
  ORDER BY ri.updated_at DESC NULLS LAST, ri.created_at DESC
  LIMIT 1;

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
  v_uid uuid := auth.uid();
  v_identity_id uuid;
  v_type text := lower(NULLIF(btrim(COALESCE(p_type, '')), ''));
  v_label text := NULLIF(btrim(COALESCE(p_label, '')), '');
  v_full_address text := NULLIF(btrim(COALESCE(p_full_address, '')), '');
  v_count integer;
  v_saved public.saved_addresses%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;

  -- Serialize additions for one rider so concurrent requests cannot exceed 10.
  SELECT ri.id INTO v_identity_id
  FROM public.rider_identities ri
  WHERE ri.user_id = v_uid
  ORDER BY ri.updated_at DESC NULLS LAST, ri.created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF v_identity_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'rider_identity_not_found');
  END IF;
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
  v_uid uuid := auth.uid();
  v_deleted_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;
  IF p_saved_address_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_address_id');
  END IF;

  DELETE FROM public.saved_addresses sa
  WHERE sa.id = p_saved_address_id
    AND sa.type <> 'recent'
    AND sa.rider_identity_id IN (
      SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = v_uid
    )
  RETURNING sa.id INTO v_deleted_id;

  IF v_deleted_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'address_not_found');
  END IF;
  RETURN jsonb_build_object('ok', true, 'deleted_id', v_deleted_id);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_saved_addresses_list() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_rider_saved_address_add(text, text, text, double precision, double precision) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_rider_saved_address_delete(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_rider_saved_addresses_list() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_rider_saved_address_add(text, text, text, double precision, double precision) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_rider_saved_address_delete(uuid) TO authenticated;

COMMENT ON FUNCTION public.fn_rider_saved_addresses_list() IS
  'Lists non-recent saved places for the rider identity owned by auth.uid().';
COMMENT ON FUNCTION public.fn_rider_saved_address_add(text, text, text, double precision, double precision) IS
  'Adds one validated saved place for auth.uid(); enforces the 10-place limit.';
COMMENT ON FUNCTION public.fn_rider_saved_address_delete(uuid) IS
  'Deletes one non-recent saved place only when auth.uid() owns it.';
