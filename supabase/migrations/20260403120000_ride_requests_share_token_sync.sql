-- Denormalized share fields on ride_requests (kept in sync from ride_shares).
ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS share_token text,
  ADD COLUMN IF NOT EXISTS share_enabled boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.sync_ride_request_share_from_ride_shares()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.ride_requests rr
  SET share_token = NEW.share_token,
      share_enabled = COALESCE(NEW.is_active, false)
  WHERE rr.id = NEW.ride_request_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ride_shares_sync_to_ride_requests ON public.ride_shares;
CREATE TRIGGER trg_ride_shares_sync_to_ride_requests
AFTER INSERT OR UPDATE OF is_active, share_token ON public.ride_shares
FOR EACH ROW
EXECUTE FUNCTION public.sync_ride_request_share_from_ride_shares();

UPDATE public.ride_requests rr
SET share_token = rs.share_token,
    share_enabled = rs.is_active
FROM public.ride_shares rs
WHERE rs.ride_request_id = rr.id AND rs.is_active = true;
