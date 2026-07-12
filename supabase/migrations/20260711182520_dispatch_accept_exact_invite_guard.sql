CREATE OR REPLACE FUNCTION public.trg_require_live_cohort_invite_on_accept()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.status = 'pending' AND NEW.status = 'accepted' THEN
    IF NEW.driver_id IS NULL OR NOT EXISTS (
      SELECT 1
      FROM public.ride_request_invites i
      WHERE i.ride_request_id = NEW.id
        AND i.driver_id = NEW.driver_id
        AND i.status = 'pending'
        AND i.expires_at > now()
    ) THEN
      RAISE EXCEPTION 'ride_invite_expired';
    END IF;
    IF OLD.expires_at IS NOT NULL AND OLD.expires_at <= now() THEN
      RAISE EXCEPTION 'ride_request_expired';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_require_live_cohort_invite_on_accept
  ON public.ride_requests;
CREATE TRIGGER trg_require_live_cohort_invite_on_accept
  BEFORE UPDATE OF status, driver_id ON public.ride_requests
  FOR EACH ROW EXECUTE FUNCTION public.trg_require_live_cohort_invite_on_accept();

REVOKE ALL ON FUNCTION public.trg_require_live_cohort_invite_on_accept()
  FROM PUBLIC, anon, authenticated;
