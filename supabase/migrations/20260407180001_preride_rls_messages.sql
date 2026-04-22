-- RLS: riders linked via rider_identities; chat insert for assigned / en route.

DROP POLICY IF EXISTS ride_requests_select_rider_identity ON public.ride_requests;

CREATE POLICY ride_requests_select_rider_identity
  ON public.ride_requests
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.rider_identities ri
      WHERE ri.id = ride_requests.rider_identity_id
        AND ri.user_id = (SELECT auth.uid())
    )
  );

DROP POLICY IF EXISTS messages_insert ON public.messages;

CREATE POLICY messages_insert
  ON public.messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (
      (sender_type)::text = 'driver'::text
      AND (sender_id = (SELECT auth.uid()))
      AND (EXISTS (
        SELECT 1
        FROM ride_requests rr
        INNER JOIN drivers d ON d.id = rr.driver_id
        WHERE rr.id = messages.ride_request_id
          AND d.user_id = (SELECT auth.uid())
          AND (rr.status)::text IN ('accepted', 'assigned', 'driver_arrived')
      ))
    )
    OR (
      (sender_type)::text = 'rider'::text
      AND (EXISTS (
        SELECT 1
        FROM ride_requests rr
        WHERE rr.id = messages.ride_request_id
          AND rr.rider_token = ((SELECT auth.uid()))::text
          AND (rr.status)::text IN ('accepted', 'assigned', 'driver_arrived')
      ))
    )
  );
