-- Link completed `rides` rows to the originating `ride_requests` row (for rider reports, etc.).
ALTER TABLE public.rides
  ADD COLUMN IF NOT EXISTS ride_request_id uuid REFERENCES public.ride_requests(id);

CREATE INDEX IF NOT EXISTS idx_rides_ride_request_id ON public.rides(ride_request_id);

COMMENT ON COLUMN public.rides.ride_request_id IS
  'Optional FK to the ride request that produced this ride (for reporting and audit).';
