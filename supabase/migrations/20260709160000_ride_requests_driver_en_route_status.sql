-- fn_driver_ride_en_route sets status driver_en_route; the legacy check constraint omitted it.

ALTER TABLE public.ride_requests
  DROP CONSTRAINT IF EXISTS ride_requests_status_check;

ALTER TABLE public.ride_requests
  ADD CONSTRAINT ride_requests_status_check
  CHECK (
    status = ANY (
      ARRAY[
        'pending'::text,
        'bidding'::text,
        'accepted'::text,
        'assigned'::text,
        'driver_found'::text,
        'driver_en_route'::text,
        'driver_arrived'::text,
        'in_progress'::text,
        'declined'::text,
        'cancelled'::text,
        'completed'::text,
        'expired'::text,
        'no_driver'::text
      ]
    )
  );

COMMENT ON CONSTRAINT ride_requests_status_check ON public.ride_requests IS
  'Lifecycle statuses including driver_en_route (head-to-pickup) and dispatch intermediates.';
