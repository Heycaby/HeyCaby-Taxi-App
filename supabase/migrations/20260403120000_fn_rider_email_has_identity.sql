-- Allow the rider app to check whether an email already has a verified identity
-- (skip OTP) vs new email (Supabase Auth OTP required first).

CREATE OR REPLACE FUNCTION public.fn_rider_email_has_identity(p_email text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.rider_identities ri
    WHERE ri.email IS NOT NULL
      AND lower(trim(ri.email)) = lower(trim(p_email))
    LIMIT 1
  );
$$;

GRANT EXECUTE ON FUNCTION public.fn_rider_email_has_identity(text) TO anon, authenticated;
