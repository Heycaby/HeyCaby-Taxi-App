-- Prevent the same Auth identity from silently creating a fresh driver after
-- requesting deletion. Broader cross-identity matching must use a separately
-- configured keyed hash and an approved retention basis; raw identifiers do
-- not belong in the former-account registry.

CREATE OR REPLACE FUNCTION public.trg_driver_prevent_deleted_identity_reuse()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.user_id IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.driver_account_deletion_jobs j
    WHERE j.former_auth_user_id = NEW.user_id
      AND j.status IN (
        'pending', 'processing', 'awaiting_retention_policy', 'completed'
      )
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'previous_account_review_required';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_driver_prevent_deleted_identity_reuse
  ON public.drivers;
CREATE TRIGGER trg_driver_prevent_deleted_identity_reuse
  BEFORE INSERT OR UPDATE OF user_id ON public.drivers
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_driver_prevent_deleted_identity_reuse();

REVOKE ALL ON FUNCTION public.trg_driver_prevent_deleted_identity_reuse()
  FROM PUBLIC;
