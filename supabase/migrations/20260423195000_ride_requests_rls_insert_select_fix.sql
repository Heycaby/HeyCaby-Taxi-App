-- Keep ride_requests compatible with guest booking:
-- riders can create/search rides without login/email, as long as rider_token exists.
-- Authenticated identity ownership remains available when rider_identity_id is present.

ALTER TABLE public.ride_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ride_requests_insert_rider_owner ON public.ride_requests;
DROP POLICY IF EXISTS ride_requests_insert ON public.ride_requests;
CREATE POLICY ride_requests_insert
  ON public.ride_requests
  FOR INSERT
  TO public
  WITH CHECK (
    (
      rider_token IS NOT NULL
      AND btrim(rider_token) <> ''
    )
    OR (
      driver_id IN (
        SELECT drivers.id
        FROM public.drivers
        WHERE drivers.user_id = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS ride_requests_select_rider_identity ON public.ride_requests;
DROP POLICY IF EXISTS ride_requests_select_rider_owner ON public.ride_requests;
DROP POLICY IF EXISTS ride_requests_select ON public.ride_requests;
CREATE POLICY ride_requests_select
  ON public.ride_requests
  FOR SELECT
  TO public
  USING (
    (
      driver_id IN (
        SELECT drivers.id
        FROM public.drivers
        WHERE drivers.user_id = auth.uid()
      )
    )
    OR (status = 'pending' AND driver_id IS NULL)
    OR (rider_token IS NOT NULL AND btrim(rider_token) <> '')
  );

CREATE POLICY ride_requests_select_rider_identity
  ON public.ride_requests
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.rider_identities ri
      WHERE ri.id = ride_requests.rider_identity_id
        AND ri.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS ride_requests_update_rider_owner ON public.ride_requests;
DROP POLICY IF EXISTS ride_requests_update ON public.ride_requests;
CREATE POLICY ride_requests_update
  ON public.ride_requests
  FOR UPDATE
  TO public
  USING (
    (
      driver_id IN (
        SELECT drivers.id
        FROM public.drivers
        WHERE drivers.user_id = auth.uid()
      )
    )
    OR (rider_token IS NOT NULL AND btrim(rider_token) <> '')
  )
  WITH CHECK (
    (
      driver_id IN (
        SELECT drivers.id
        FROM public.drivers
        WHERE drivers.user_id = auth.uid()
      )
    )
    OR (rider_token IS NOT NULL AND btrim(rider_token) <> '')
  );
