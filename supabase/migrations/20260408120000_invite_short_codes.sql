-- Short public invite codes (7 chars, mixed letters + digits) for TAF links.
-- URLs: https://heycaby.nl/i/{code} — use fn_lookup_invite_code(code) on the web app.

CREATE TABLE IF NOT EXISTS public.invite_codes (
  code text NOT NULL PRIMARY KEY,
  CONSTRAINT invite_codes_code_format CHECK (
    char_length(code) = 7
    AND code ~ '^[a-zA-Z0-9]{7}$'
  ),
  rider_identity_id uuid UNIQUE REFERENCES public.rider_identities (id) ON DELETE CASCADE,
  driver_id uuid UNIQUE REFERENCES public.drivers (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT invite_codes_one_target CHECK (
    (rider_identity_id IS NOT NULL AND driver_id IS NULL)
    OR (rider_identity_id IS NULL AND driver_id IS NOT NULL)
  )
);

COMMENT ON TABLE public.invite_codes IS
  'Maps 7-char invite codes to rider identity or driver; globally unique codes for /i/{code} URLs.';

ALTER TABLE public.invite_codes ENABLE ROW LEVEL SECURITY;

-- No policies: clients use SECURITY DEFINER RPCs only.

CREATE OR REPLACE FUNCTION public._random_invite_code_7 ()
RETURNS text
LANGUAGE sql
VOLATILE
SET search_path = public
AS $$
  SELECT string_agg(
    substr(
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
      1 + (floor(random() * 62))::int,
      1
    ),
    ''
  )
  FROM generate_series(1, 7);
$$;

CREATE OR REPLACE FUNCTION public.fn_ensure_rider_invite_code ()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_identity uuid;
  v_existing text;
  v_code text;
  k int;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT ri.id
  INTO v_identity
  FROM public.rider_identities ri
  WHERE ri.user_id = v_uid
  LIMIT 1;

  IF v_identity IS NULL THEN
    RAISE EXCEPTION 'identity_not_found';
  END IF;

  SELECT ic.code
  INTO v_existing
  FROM public.invite_codes ic
  WHERE ic.rider_identity_id = v_identity
  LIMIT 1;

  IF v_existing IS NOT NULL THEN
    RETURN v_existing;
  END IF;

  FOR k IN 1..40 LOOP
    v_code := public._random_invite_code_7();
    BEGIN
      INSERT INTO public.invite_codes (code, rider_identity_id)
      VALUES (v_code, v_identity);
      RETURN v_code;
    EXCEPTION
      WHEN unique_violation THEN
        NULL;
    END;
  END LOOP;

  RAISE EXCEPTION 'invite_code_generation_failed';
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_ensure_driver_invite_code ()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_driver uuid;
  v_existing text;
  v_code text;
  k int;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT d.id
  INTO v_driver
  FROM public.drivers d
  WHERE d.user_id = v_uid
  LIMIT 1;

  IF v_driver IS NULL THEN
    RAISE EXCEPTION 'driver_not_found';
  END IF;

  SELECT ic.code
  INTO v_existing
  FROM public.invite_codes ic
  WHERE ic.driver_id = v_driver
  LIMIT 1;

  IF v_existing IS NOT NULL THEN
    RETURN v_existing;
  END IF;

  FOR k IN 1..40 LOOP
    v_code := public._random_invite_code_7();
    BEGIN
      INSERT INTO public.invite_codes (code, driver_id)
      VALUES (v_code, v_driver);
      RETURN v_code;
    EXCEPTION
      WHEN unique_violation THEN
        NULL;
    END;
  END LOOP;

  RAISE EXCEPTION 'invite_code_generation_failed';
END;
$$;

-- For heycaby.nl (or app) landing: resolve code → ids (anon ok; codes are shareable).
CREATE OR REPLACE FUNCTION public.fn_lookup_invite_code (p_code text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_norm text;
  r jsonb;
BEGIN
  IF p_code IS NULL OR length(trim(p_code)) = 0 THEN
    RETURN NULL;
  END IF;
  v_norm := trim(p_code);
  IF v_norm !~ '^[a-zA-Z0-9]{7}$' THEN
    RETURN NULL;
  END IF;

  SELECT jsonb_build_object(
    'rider_identity_id', ic.rider_identity_id,
    'driver_id', ic.driver_id
  )
  INTO r
  FROM public.invite_codes ic
  WHERE ic.code = v_norm
  LIMIT 1;

  RETURN r;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_ensure_rider_invite_code () TO authenticated;

GRANT EXECUTE ON FUNCTION public.fn_ensure_driver_invite_code () TO authenticated;

GRANT EXECUTE ON FUNCTION public.fn_lookup_invite_code (text) TO anon, authenticated;
