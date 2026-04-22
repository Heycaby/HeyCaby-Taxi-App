-- Admin manual verification for chauffeurspas (Kiwa) + KvK — uses EXISTING `drivers` columns only.
-- No new tables. Staff must have app_metadata.role = 'admin' (or 'super_admin') on their auth user.
--
-- Apply in Supabase SQL Editor or: supabase db push / migration run.
-- After deploy: Dashboard → Authentication → Users → App metadata: {"role":"admin"}

CREATE OR REPLACE FUNCTION public.fn_admin_set_manual_verifications(
  p_driver_id uuid,
  p_chauffeurspas_verified boolean DEFAULT NULL,
  p_kvk_verified boolean DEFAULT NULL,
  p_mark_fully_verified boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM auth.users u
    WHERE u.id = auth.uid()
      AND coalesce(u.raw_app_meta_data->>'role', u.raw_user_meta_data->>'role', '')
         IN ('admin', 'super_admin')
  )
  INTO v_ok;

  IF NOT coalesce(v_ok, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.drivers d WHERE d.id = p_driver_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'driver_not_found');
  END IF;

  UPDATE public.drivers
  SET
    chauffeurspas_verified = CASE
      WHEN p_chauffeurspas_verified IS NOT NULL THEN p_chauffeurspas_verified
      ELSE chauffeurspas_verified
    END,
    kvk_verified = CASE
      WHEN p_kvk_verified IS NOT NULL THEN p_kvk_verified
      ELSE kvk_verified
    END,
    profile_status = CASE
      WHEN p_mark_fully_verified THEN 'verified'
      ELSE profile_status
    END,
    compliance_status = CASE
      WHEN p_mark_fully_verified THEN 'compliant'
      ELSE compliance_status
    END,
    congratulations_modal_shown = CASE
      WHEN p_mark_fully_verified THEN false
      ELSE congratulations_modal_shown
    END
  WHERE id = p_driver_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

COMMENT ON FUNCTION public.fn_admin_set_manual_verifications IS
  'Admin-only: set manual Kiwa/KvK flags and optionally mark driver verified + compliant (drivers table).';

REVOKE ALL ON FUNCTION public.fn_admin_set_manual_verifications FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_admin_set_manual_verifications TO authenticated;
