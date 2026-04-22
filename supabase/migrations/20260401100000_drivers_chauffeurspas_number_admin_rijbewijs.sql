-- Chauffeurspas number on drivers (for immutable-save UX + display).
-- Admin: confirm driving licence after Veriff dashboard review.
--
-- Replaces older `fn_admin_set_manual_verifications(uuid, boolean, boolean, boolean)` overload.

DROP FUNCTION IF EXISTS public.fn_admin_set_manual_verifications(uuid, boolean, boolean, boolean);

ALTER TABLE public.drivers
  ADD COLUMN IF NOT EXISTS chauffeurspas_number text;

COMMENT ON COLUMN public.drivers.chauffeurspas_number IS
  'Chauffeurspas number; treat as locked in app after first save (support to change).';

CREATE OR REPLACE FUNCTION public.fn_admin_set_manual_verifications(
  p_driver_id uuid,
  p_chauffeurspas_verified boolean DEFAULT NULL,
  p_kvk_verified boolean DEFAULT NULL,
  p_rijbewijs_verified boolean DEFAULT NULL,
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
    rijbewijs_verified = CASE
      WHEN p_rijbewijs_verified IS NOT NULL THEN p_rijbewijs_verified
      ELSE rijbewijs_verified
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
  'Admin-only: Kiwa/KvK flags, rijbewijs_verified after Veriff review, optional mark fully verified.';

REVOKE ALL ON FUNCTION public.fn_admin_set_manual_verifications FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_admin_set_manual_verifications TO authenticated;
