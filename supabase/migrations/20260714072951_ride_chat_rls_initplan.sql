-- Preserve the released message authorization contract while evaluating the
-- authenticated UID once per statement. Also align Rider reads/acknowledgement
-- with the direct ride_requests.rider_id ownership already accepted by the
-- canonical send command.

DROP POLICY IF EXISTS messages_insert_participant ON public.messages;
CREATE POLICY messages_insert_participant
ON public.messages
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.ride_requests rr
    WHERE rr.id = messages.ride_request_id
      AND rr.status::text IN (
        'accepted',
        'assigned',
        'driver_found',
        'driver_en_route',
        'arrived',
        'driver_arrived',
        'in_progress'
      )
      AND (
        (
          messages.sender_type::text = 'driver'
          AND messages.sender_id = (SELECT auth.uid())
          AND rr.driver_id IN (
            SELECT d.id
            FROM public.drivers d
            WHERE d.user_id = (SELECT auth.uid())
          )
        )
        OR
        (
          messages.sender_type::text = 'rider'
          AND (
            rr.rider_id = (SELECT auth.uid())
            OR rr.rider_identity_id IN (
              SELECT ri.id
              FROM public.rider_identities ri
              WHERE ri.user_id = (SELECT auth.uid())
            )
            OR rr.rider_token IN (
              SELECT rs.session_token
              FROM public.rider_sessions rs
              WHERE rs.user_id = (SELECT auth.uid())
            )
          )
          AND (
            messages.sender_id = (SELECT auth.uid())
            OR messages.sender_id = rr.rider_identity_id
          )
        )
      )
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.ride_chat_blocks b
    WHERE b.ride_id = messages.ride_request_id
      AND (
        (
          b.blocker_type = messages.sender_type::text
          AND b.blocker_id = messages.sender_id::text
        )
        OR
        (
          b.blocked_type = messages.sender_type::text
          AND b.blocked_id = messages.sender_id::text
        )
      )
  )
);

DROP POLICY IF EXISTS messages_select_participant ON public.messages;
CREATE POLICY messages_select_participant
ON public.messages
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.ride_requests rr
    WHERE rr.id = messages.ride_request_id
      AND (
        rr.rider_id = (SELECT auth.uid())
        OR rr.driver_id IN (
          SELECT d.id
          FROM public.drivers d
          WHERE d.user_id = (SELECT auth.uid())
        )
        OR rr.rider_identity_id IN (
          SELECT ri.id
          FROM public.rider_identities ri
          WHERE ri.user_id = (SELECT auth.uid())
        )
        OR rr.rider_token IN (
          SELECT rs.session_token
          FROM public.rider_sessions rs
          WHERE rs.user_id = (SELECT auth.uid())
        )
      )
  )
);

DROP POLICY IF EXISTS messages_recipient_marks_read ON public.messages;
CREATE POLICY messages_recipient_marks_read
ON public.messages
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.ride_requests rr
    WHERE rr.id = messages.ride_request_id
      AND (
        (
          messages.sender_type::text = 'rider'
          AND rr.driver_id IN (
            SELECT d.id
            FROM public.drivers d
            WHERE d.user_id = (SELECT auth.uid())
          )
        )
        OR
        (
          messages.sender_type::text = 'driver'
          AND (
            rr.rider_id = (SELECT auth.uid())
            OR rr.rider_identity_id IN (
              SELECT ri.id
              FROM public.rider_identities ri
              WHERE ri.user_id = (SELECT auth.uid())
            )
            OR rr.rider_token IN (
              SELECT rs.session_token
              FROM public.rider_sessions rs
              WHERE rs.user_id = (SELECT auth.uid())
            )
          )
        )
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.ride_requests rr
    WHERE rr.id = messages.ride_request_id
      AND (
        (
          messages.sender_type::text = 'rider'
          AND rr.driver_id IN (
            SELECT d.id
            FROM public.drivers d
            WHERE d.user_id = (SELECT auth.uid())
          )
        )
        OR
        (
          messages.sender_type::text = 'driver'
          AND (
            rr.rider_id = (SELECT auth.uid())
            OR rr.rider_identity_id IN (
              SELECT ri.id
              FROM public.rider_identities ri
              WHERE ri.user_id = (SELECT auth.uid())
            )
            OR rr.rider_token IN (
              SELECT rs.session_token
              FROM public.rider_sessions rs
              WHERE rs.user_id = (SELECT auth.uid())
            )
          )
        )
      )
  )
);
