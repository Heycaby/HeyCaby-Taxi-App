-- App Store review: rider email modal can use same credentials as driver (app_config).
-- Flutter calls this when user enters optional 6-digit code with the review email.

CREATE OR REPLACE FUNCTION public.fn_create_rider_session_review(p_email text, p_otp text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_enabled text;
  v_review_email text;
  v_review_otp text;
BEGIN
  IF p_email IS NULL OR length(trim(p_email)) < 3 OR p_otp IS NULL OR length(trim(p_otp)) < 4 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_params');
  END IF;

  SELECT value INTO v_enabled FROM public.app_config WHERE key = 'apple_review_enabled';
  SELECT value INTO v_review_email FROM public.app_config WHERE key = 'apple_review_email';
  SELECT value INTO v_review_otp FROM public.app_config WHERE key = 'apple_review_otp';

  IF v_enabled IS DISTINCT FROM 'true' THEN
    RETURN jsonb_build_object('success', false, 'error', 'review_disabled');
  END IF;

  IF lower(trim(p_email)) IS DISTINCT FROM lower(trim(v_review_email))
     OR trim(p_otp) IS DISTINCT FROM trim(v_review_otp) THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_credentials');
  END IF;

  RETURN public.fn_create_rider_session(trim(p_email));
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_create_rider_session_review(text, text) TO anon, authenticated;
