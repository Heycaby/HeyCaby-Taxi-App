-- Preserve the originally booked destination so rider/driver UIs can show edits.
ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS booked_destination_address text,
  ADD COLUMN IF NOT EXISTS booked_destination_lat double precision,
  ADD COLUMN IF NOT EXISTS booked_destination_lng double precision;

UPDATE public.ride_requests
SET
  booked_destination_address = destination_address,
  booked_destination_lat = destination_lat,
  booked_destination_lng = destination_lng
WHERE booked_destination_address IS NULL;

CREATE OR REPLACE FUNCTION public.trg_ride_requests_capture_booked_destination()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.booked_destination_address := NEW.destination_address;
    NEW.booked_destination_lat := NEW.destination_lat;
    NEW.booked_destination_lng := NEW.destination_lng;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS ride_requests_capture_booked_destination ON public.ride_requests;
CREATE TRIGGER ride_requests_capture_booked_destination
  BEFORE INSERT ON public.ride_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_ride_requests_capture_booked_destination();
