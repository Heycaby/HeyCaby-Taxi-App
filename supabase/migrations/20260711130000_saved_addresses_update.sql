-- Allow riders to update saved place label, type, and address coordinates.

CREATE OR REPLACE FUNCTION public.fn_rider_saved_address_update(
  p_saved_address_id uuid,
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
  v_saved public.saved_addresses%ROWTYPE;
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

  UPDATE public.saved_addresses sa
  SET
    type = v_type,
    label = v_label,
    full_address = v_full_address,
    latitude = p_latitude,
    longitude = p_longitude,
    updated_at = now()
  WHERE sa.id = p_saved_address_id
    AND sa.type <> 'recent'
    AND sa.rider_identity_id = v_identity_id
  RETURNING * INTO v_saved;

  IF v_saved.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'address_not_found');
  END IF;

  RETURN jsonb_build_object('ok', true, 'address', to_jsonb(v_saved));
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_saved_address_update(uuid, text, text, text, double precision, double precision) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_rider_saved_address_update(uuid, text, text, text, double precision, double precision) TO authenticated;

COMMENT ON FUNCTION public.fn_rider_saved_address_update(uuid, text, text, text, double precision, double precision) IS
  'Updates a saved place owned by the resolved rider identity (label, type, address, coordinates).';
