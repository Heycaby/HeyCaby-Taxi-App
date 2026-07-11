-- Full-platform stabilization: bind rider data to the authenticated Supabase
-- session, close token-only RLS gaps, and lock internal lifecycle helpers.
-- Anonymous rider accounts created by Supabase Auth still use the
-- `authenticated` database role and remain supported.

-- ---------------------------------------------------------------------------
-- Rider session and verified-email ownership
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_rider_bind_session_token(p_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_token text := NULLIF(btrim(COALESCE(p_token, '')), '');
  v_uid uuid := auth.uid();
  v_owner uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;
  IF v_token IS NULL OR v_token !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_token');
  END IF;

  SELECT rs.user_id INTO v_owner
  FROM public.rider_sessions rs
  WHERE rs.session_token = v_token
  FOR UPDATE;

  IF FOUND AND v_owner IS DISTINCT FROM v_uid THEN
    RETURN jsonb_build_object('ok', false, 'error', 'token_already_bound');
  END IF;

  INSERT INTO public.rider_sessions (
    session_token, user_id, created_at, last_active_at
  ) VALUES (
    v_token, v_uid, timezone('utc', now()), timezone('utc', now())
  )
  ON CONFLICT (session_token) DO UPDATE
  SET last_active_at = timezone('utc', now())
  WHERE rider_sessions.user_id = v_uid;

  RETURN jsonb_build_object('ok', true, 'session_token', v_token);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_create_rider_session(
  p_email text,
  p_display_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_claimed_email text := lower(NULLIF(btrim(auth.jwt() ->> 'email'), ''));
  v_email text := lower(NULLIF(btrim(COALESCE(p_email, '')), ''));
  v_token text := gen_random_uuid()::text;
  v_identity_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  IF v_email IS NULL OR v_email NOT LIKE '%@%' THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_email');
  END IF;
  IF v_claimed_email IS NULL OR v_claimed_email IS DISTINCT FROM v_email THEN
    RETURN jsonb_build_object('success', false, 'error', 'email_not_verified');
  END IF;

  INSERT INTO public.rider_identities (
    id, email, booking_name, email_verified_at, user_id, updated_at
  ) VALUES (
    gen_random_uuid(), v_email, p_display_name, now(), v_uid, now()
  )
  ON CONFLICT (email) DO UPDATE
  SET booking_name = COALESCE(EXCLUDED.booking_name, rider_identities.booking_name),
      email_verified_at = COALESCE(rider_identities.email_verified_at, now()),
      user_id = EXCLUDED.user_id,
      updated_at = now()
  WHERE rider_identities.user_id IS NULL OR rider_identities.user_id = v_uid
  RETURNING id INTO v_identity_id;

  IF v_identity_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'identity_owned_by_another_user');
  END IF;

  INSERT INTO public.rider_sessions (
    session_token, display_name, user_id, created_at, last_active_at
  ) VALUES (
    v_token, COALESCE(NULLIF(btrim(p_display_name), ''), 'Rider'), v_uid, now(), now()
  );

  RETURN jsonb_build_object(
    'success', true,
    'session_token', v_token,
    'identity_id', v_identity_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_create_rider_session_review(
  p_email text,
  p_otp text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_enabled text;
  v_review_email text;
  v_review_otp text;
  v_email text := lower(NULLIF(btrim(COALESCE(p_email, '')), ''));
  v_token text := gen_random_uuid()::text;
  v_identity_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  SELECT value INTO v_enabled FROM public.app_config WHERE key = 'apple_review_enabled';
  SELECT value INTO v_review_email FROM public.app_config WHERE key = 'apple_review_email';
  SELECT value INTO v_review_otp FROM public.app_config WHERE key = 'apple_review_otp';

  IF v_enabled IS DISTINCT FROM 'true' OR
     v_email IS DISTINCT FROM lower(btrim(v_review_email)) OR
     btrim(COALESCE(p_otp, '')) IS DISTINCT FROM btrim(v_review_otp) THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_credentials');
  END IF;

  INSERT INTO public.rider_identities (
    id, email, booking_name, email_verified_at, user_id, updated_at
  ) VALUES (
    gen_random_uuid(), v_email, NULL, now(), v_uid, now()
  )
  ON CONFLICT (email) DO UPDATE
  SET email_verified_at = COALESCE(rider_identities.email_verified_at, now()),
      user_id = EXCLUDED.user_id,
      updated_at = now()
  WHERE rider_identities.user_id IS NULL OR rider_identities.user_id = v_uid
  RETURNING id INTO v_identity_id;

  IF v_identity_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'identity_owned_by_another_user');
  END IF;

  INSERT INTO public.rider_sessions (
    session_token, display_name, user_id, created_at, last_active_at
  ) VALUES (v_token, 'App Review', v_uid, now(), now());

  RETURN jsonb_build_object(
    'success', true,
    'session_token', v_token,
    'identity_id', v_identity_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_bind_session_token(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_rider_bind_session_token(text) TO authenticated;
REVOKE ALL ON FUNCTION public.fn_create_rider_session(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_create_rider_session(text, text) TO authenticated;
REVOKE ALL ON FUNCTION public.fn_create_rider_session_review(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_create_rider_session_review(text, text) TO authenticated;
REVOKE ALL ON FUNCTION public.fn_rider_email_has_identity(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_rider_email_has_identity(text) TO service_role;

-- ---------------------------------------------------------------------------
-- Rider identities and session tokens
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "Guest riders can read own identity" ON public.rider_identities;
DROP POLICY IF EXISTS "Riders can insert own identity" ON public.rider_identities;
DROP POLICY IF EXISTS "Riders can read own identity" ON public.rider_identities;
DROP POLICY IF EXISTS "Riders update own identity" ON public.rider_identities;
DROP POLICY IF EXISTS service_role_manage_rider_identities ON public.rider_identities;

CREATE POLICY rider_identities_select_own
ON public.rider_identities FOR SELECT TO authenticated
USING (user_id = auth.uid());
CREATE POLICY rider_identities_insert_own
ON public.rider_identities FOR INSERT TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND lower(email) = lower(COALESCE(auth.jwt() ->> 'email', ''))
);
CREATE POLICY rider_identities_update_own
ON public.rider_identities FOR UPDATE TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());
CREATE POLICY service_role_manage_rider_identities
ON public.rider_identities FOR ALL TO service_role
USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS rider_sessions_insert_anon ON public.rider_sessions;
DROP POLICY IF EXISTS rider_sessions_select_own ON public.rider_sessions;
CREATE POLICY rider_sessions_select_own
ON public.rider_sessions FOR SELECT TO authenticated
USING (user_id = auth.uid());
CREATE POLICY service_role_manage_rider_sessions
ON public.rider_sessions FOR ALL TO service_role
USING (true) WITH CHECK (true);

-- ---------------------------------------------------------------------------
-- Ride ownership: a token is valid only when bound to auth.uid().
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS ride_requests_insert ON public.ride_requests;
DROP POLICY IF EXISTS ride_requests_select ON public.ride_requests;
DROP POLICY IF EXISTS ride_requests_select_rider_identity ON public.ride_requests;
DROP POLICY IF EXISTS ride_requests_update ON public.ride_requests;

CREATE POLICY ride_requests_select_participant
ON public.ride_requests FOR SELECT TO authenticated
USING (
  driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
  OR rider_identity_id IN (
    SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
  )
  OR rider_token IN (
    SELECT rs.session_token FROM public.rider_sessions rs WHERE rs.user_id = auth.uid()
  )
  OR (
    status IN ('pending', 'bidding')
    AND driver_id IS NULL
    AND EXISTS (SELECT 1 FROM public.drivers d WHERE d.user_id = auth.uid())
  )
);

CREATE POLICY ride_requests_insert_owner
ON public.ride_requests FOR INSERT TO authenticated
WITH CHECK (
  (
    rider_token IN (
      SELECT rs.session_token FROM public.rider_sessions rs WHERE rs.user_id = auth.uid()
    )
    AND (
      rider_identity_id IS NULL
      OR rider_identity_id IN (
        SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
      )
    )
  )
  OR driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
);

CREATE POLICY ride_requests_update_participant
ON public.ride_requests FOR UPDATE TO authenticated
USING (
  driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
  OR rider_identity_id IN (
    SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
  )
  OR rider_token IN (
    SELECT rs.session_token FROM public.rider_sessions rs WHERE rs.user_id = auth.uid()
  )
)
WITH CHECK (
  driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
  OR rider_identity_id IN (
    SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
  )
  OR rider_token IN (
    SELECT rs.session_token FROM public.rider_sessions rs WHERE rs.user_id = auth.uid()
  )
);

-- ---------------------------------------------------------------------------
-- Ride chat and conversation context
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS messages_insert ON public.messages;
DROP POLICY IF EXISTS messages_select ON public.messages;
DROP POLICY IF EXISTS messages_update ON public.messages;

CREATE POLICY messages_select_participant
ON public.messages FOR SELECT TO authenticated
USING (EXISTS (
  SELECT 1
  FROM public.ride_requests rr
  WHERE rr.id = messages.ride_request_id
    AND (
      rr.driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
      OR rr.rider_identity_id IN (
        SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
      )
      OR rr.rider_token IN (
        SELECT rs.session_token FROM public.rider_sessions rs WHERE rs.user_id = auth.uid()
      )
    )
));

CREATE POLICY messages_insert_participant
ON public.messages FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.ride_requests rr
    WHERE rr.id = messages.ride_request_id
      AND rr.status IN ('accepted', 'assigned', 'driver_found', 'driver_en_route', 'arrived', 'driver_arrived', 'in_progress')
      AND (
        (
          messages.sender_type = 'driver'
          AND messages.sender_id = auth.uid()
          AND rr.driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
        )
        OR (
          messages.sender_type = 'rider'
          AND (
            rr.rider_identity_id IN (
              SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
            )
            OR rr.rider_token IN (
              SELECT rs.session_token FROM public.rider_sessions rs WHERE rs.user_id = auth.uid()
            )
          )
          AND (
            messages.sender_id = auth.uid()
            OR messages.sender_id = rr.rider_identity_id
          )
        )
      )
  )
);

CREATE POLICY messages_update_participant
ON public.messages FOR UPDATE TO authenticated
USING (EXISTS (
  SELECT 1 FROM public.ride_requests rr
  WHERE rr.id = messages.ride_request_id
    AND (
      rr.driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
      OR rr.rider_identity_id IN (
        SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
      )
      OR rr.rider_token IN (
        SELECT rs.session_token FROM public.rider_sessions rs WHERE rs.user_id = auth.uid()
      )
    )
))
WITH CHECK (EXISTS (
  SELECT 1 FROM public.ride_requests rr
  WHERE rr.id = messages.ride_request_id
    AND (
      rr.driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
      OR rr.rider_identity_id IN (
        SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
      )
      OR rr.rider_token IN (
        SELECT rs.session_token FROM public.rider_sessions rs WHERE rs.user_id = auth.uid()
      )
    )
));

DROP POLICY IF EXISTS conversations_participants_read ON public.conversations;
CREATE POLICY conversations_participants_read
ON public.conversations FOR SELECT TO authenticated
USING (
  driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
  OR rider_identity_id IN (
    SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1 FROM public.ride_requests rr
    WHERE rr.id = conversations.ride_request_id
      AND rr.rider_token IN (
        SELECT rs.session_token FROM public.rider_sessions rs WHERE rs.user_id = auth.uid()
      )
  )
);

-- ---------------------------------------------------------------------------
-- Favorites and trip sharing
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS riders_select_favorite_drivers ON public.rider_favorite_drivers;
DROP POLICY IF EXISTS riders_insert_favorite_drivers ON public.rider_favorite_drivers;
DROP POLICY IF EXISTS riders_delete_favorite_drivers ON public.rider_favorite_drivers;
DROP POLICY IF EXISTS drivers_see_own_favorites ON public.rider_favorite_drivers;
DROP POLICY IF EXISTS service_role_manage_rider_favorite_drivers ON public.rider_favorite_drivers;

CREATE POLICY riders_select_favorite_drivers
ON public.rider_favorite_drivers FOR SELECT TO authenticated
USING (rider_identity_id IN (
  SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
));
CREATE POLICY riders_insert_favorite_drivers
ON public.rider_favorite_drivers FOR INSERT TO authenticated
WITH CHECK (rider_identity_id IN (
  SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
));
CREATE POLICY riders_delete_favorite_drivers
ON public.rider_favorite_drivers FOR DELETE TO authenticated
USING (rider_identity_id IN (
  SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
));
CREATE POLICY drivers_see_own_favorites
ON public.rider_favorite_drivers FOR SELECT TO authenticated
USING (driver_id IN (
  SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid()
));
CREATE POLICY service_role_manage_rider_favorite_drivers
ON public.rider_favorite_drivers FOR ALL TO service_role
USING (true) WITH CHECK (true);

-- Preserve the mature favorite-write implementation behind an ownership gate.
ALTER FUNCTION public.fn_rider_add_favorite_driver(uuid, uuid, text)
  RENAME TO fn_rider_add_favorite_driver_unchecked;
REVOKE ALL ON FUNCTION public.fn_rider_add_favorite_driver_unchecked(uuid, uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_rider_add_favorite_driver_unchecked(uuid, uuid, text)
  TO service_role;

CREATE FUNCTION public.fn_rider_add_favorite_driver(
  p_ride_request_id uuid,
  p_driver_id uuid,
  p_rider_token text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.ride_requests rr
    WHERE rr.id = p_ride_request_id
      AND rr.driver_id = p_driver_id
      AND (
        rr.rider_identity_id IN (
          SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
        )
        OR rr.rider_token IN (
          SELECT rs.session_token FROM public.rider_sessions rs WHERE rs.user_id = auth.uid()
        )
      )
  ) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_authorized');
  END IF;

  RETURN public.fn_rider_add_favorite_driver_unchecked(
    p_ride_request_id,
    p_driver_id,
    p_rider_token
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_add_favorite_driver(uuid, uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_rider_add_favorite_driver(uuid, uuid, text)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_rider_favorite_drivers(p_rider_identity_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF p_rider_identity_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.rider_identities ri
    WHERE ri.id = p_rider_identity_id AND ri.user_id = auth.uid()
  ) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_authorized', 'drivers', '[]'::jsonb);
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', rfd.id,
    'driver_id', rfd.driver_id,
    'driver_name', d.full_name,
    'driver_photo', d.profile_photo_url,
    'rating', COALESCE(d.rating, 5.0),
    'total_rides', COALESCE(d.trip_count, 0),
    'vehicle_make', d.vehicle_make,
    'vehicle_model', d.vehicle_model,
    'vehicle_colour', d.vehicle_colour,
    'vehicle_plate', d.vehicle_plate,
    'driver_status', d.status::text,
    'is_available', d.status = 'available',
    'created_at', rfd.created_at,
    'last_ride_completed_at', rr.completed_at
  ) ORDER BY rfd.created_at DESC), '[]'::jsonb)
  INTO v_result
  FROM public.rider_favorite_drivers rfd
  JOIN public.drivers d ON d.id = rfd.driver_id
  LEFT JOIN public.ride_requests rr ON rr.id = rfd.source_ride_request_id
  WHERE rfd.rider_identity_id = p_rider_identity_id
    AND rfd.is_active = true;

  RETURN jsonb_build_object('success', true, 'drivers', v_result);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_rider_remove_favorite_driver(
  p_rider_identity_id uuid,
  p_driver_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rows integer;
BEGIN
  IF p_rider_identity_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.rider_identities ri
    WHERE ri.id = p_rider_identity_id AND ri.user_id = auth.uid()
  ) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_authorized');
  END IF;

  UPDATE public.rider_favorite_drivers
  SET is_active = false, removed_at = now()
  WHERE rider_identity_id = p_rider_identity_id
    AND driver_id = p_driver_id
    AND is_active = true;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  RETURN jsonb_build_object(
    'success', v_rows > 0,
    'reason', CASE WHEN v_rows > 0 THEN NULL ELSE 'not_favorited' END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_favorite_drivers(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_rider_favorite_drivers(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.fn_rider_remove_favorite_driver(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_rider_remove_favorite_driver(uuid, uuid) TO authenticated;

DROP POLICY IF EXISTS ride_shares_deactivate_own ON public.ride_shares;
DROP POLICY IF EXISTS ride_shares_insert ON public.ride_shares;
DROP POLICY IF EXISTS ride_shares_insert_own ON public.ride_shares;
DROP POLICY IF EXISTS ride_shares_select ON public.ride_shares;
DROP POLICY IF EXISTS ride_shares_update ON public.ride_shares;
DROP POLICY IF EXISTS riders_select_own_shares ON public.ride_shares;
DROP POLICY IF EXISTS service_role_manage_ride_shares ON public.ride_shares;

CREATE POLICY ride_shares_select_participant
ON public.ride_shares FOR SELECT TO authenticated
USING (EXISTS (
  SELECT 1 FROM public.ride_requests rr
  WHERE rr.id = ride_shares.ride_request_id
    AND (
      rr.driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
      OR rr.rider_identity_id IN (
        SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
      )
      OR rr.rider_token IN (
        SELECT rs.session_token FROM public.rider_sessions rs WHERE rs.user_id = auth.uid()
      )
    )
));
CREATE POLICY service_role_manage_ride_shares
ON public.ride_shares FOR ALL TO service_role
USING (true) WITH CHECK (true);

CREATE OR REPLACE FUNCTION public.fn_rider_create_share_token(
  p_ride_request_id uuid,
  p_rider_token text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_share_token text;
BEGIN
  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  IF NOT (
    v_ride.driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
    OR v_ride.rider_identity_id IN (
      SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
    )
    OR v_ride.rider_token IN (
      SELECT rs.session_token FROM public.rider_sessions rs WHERE rs.user_id = auth.uid()
    )
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authorized');
  END IF;

  SELECT rs.share_token INTO v_share_token
  FROM public.ride_shares rs
  WHERE rs.ride_request_id = p_ride_request_id AND rs.is_active = true
  ORDER BY rs.created_at DESC
  LIMIT 1;

  IF v_share_token IS NULL THEN
    INSERT INTO public.ride_shares (
      ride_request_id, rider_token, is_active, expires_at
    ) VALUES (
      p_ride_request_id,
      COALESCE(v_ride.rider_token, gen_random_uuid()::text),
      true,
      now() + interval '24 hours'
    )
    RETURNING share_token INTO v_share_token;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'share_token', v_share_token,
    'share_url', '/track/' || v_share_token
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_create_share_token(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_rider_create_share_token(uuid, text) TO authenticated;

-- ---------------------------------------------------------------------------
-- Ratings: authenticated ride participants only.
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS ride_ratings_anon_select ON public.ride_ratings;
DROP POLICY IF EXISTS ride_ratings_insert ON public.ride_ratings;
DROP POLICY IF EXISTS ride_ratings_select ON public.ride_ratings;
DROP POLICY IF EXISTS ride_ratings_update ON public.ride_ratings;

CREATE POLICY ride_ratings_select_participant
ON public.ride_ratings FOR SELECT TO authenticated
USING (
  driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
  OR ride_request_id IN (
    SELECT rr.id FROM public.ride_requests rr
    WHERE rr.rider_identity_id IN (
      SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
    )
    OR rr.rider_token IN (
      SELECT rs.session_token FROM public.rider_sessions rs WHERE rs.user_id = auth.uid()
    )
  )
);
CREATE POLICY ride_ratings_insert_participant
ON public.ride_ratings FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.ride_requests rr
    WHERE rr.id = ride_ratings.ride_request_id
      AND rr.driver_id = ride_ratings.driver_id
      AND (
        rr.driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
        OR rr.rider_token IN (
          SELECT rs.session_token FROM public.rider_sessions rs WHERE rs.user_id = auth.uid()
        )
        OR rr.rider_identity_id IN (
          SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
        )
      )
  )
);
CREATE POLICY ride_ratings_update_participant
ON public.ride_ratings FOR UPDATE TO authenticated
USING (
  driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
  OR rider_token IN (
    SELECT rs.session_token FROM public.rider_sessions rs WHERE rs.user_id = auth.uid()
  )
)
WITH CHECK (
  (driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
    AND driver_rating_of_rider BETWEEN 1 AND 5)
  OR (rider_token IN (
    SELECT rs.session_token FROM public.rider_sessions rs WHERE rs.user_id = auth.uid()
  ) AND rider_rating_of_driver BETWEEN 1 AND 5)
);

-- ---------------------------------------------------------------------------
-- Views and internal RPCs
-- ---------------------------------------------------------------------------

ALTER VIEW public.driver_platform_balance SET (security_invoker = true);
ALTER VIEW public.ride_events SET (security_invoker = true);
REVOKE ALL ON public.driver_platform_balance FROM anon;
GRANT SELECT ON public.driver_platform_balance TO authenticated, service_role;
REVOKE ALL ON public.ride_events FROM anon;
GRANT SELECT ON public.ride_events TO authenticated, service_role;

DROP POLICY IF EXISTS ride_audit_log_select_rider_session ON public.ride_audit_log;
CREATE POLICY ride_audit_log_select_rider_session
ON public.ride_audit_log FOR SELECT TO authenticated
USING (EXISTS (
  SELECT 1 FROM public.ride_requests rr
  WHERE rr.id = ride_audit_log.ride_id
    AND rr.rider_token IN (
      SELECT rs.session_token FROM public.rider_sessions rs WHERE rs.user_id = auth.uid()
    )
));

REVOKE ALL ON FUNCTION public.fn_ride_lifecycle_matrix_audit(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_ride_lifecycle_matrix_audit(uuid) TO service_role;
REVOKE ALL ON FUNCTION public.fn_ride_notify_rider(uuid, text, text, text, jsonb, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_ride_notify_rider(uuid, text, text, text, jsonb, text) TO service_role;
REVOKE ALL ON FUNCTION public.sync_ride_request_share_from_ride_shares() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sync_ride_request_share_from_ride_shares() TO service_role;

REVOKE ALL ON FUNCTION public.fn_driver_accept_ride_invite(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_driver_accept_ride_invite(uuid) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.fn_driver_ride_arrived(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_driver_ride_arrived(uuid) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.fn_driver_ride_start(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_driver_ride_start(uuid) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.fn_driver_ride_complete(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_driver_ride_complete(uuid) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.fn_driver_set_status(text, double precision, double precision) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_driver_set_status(text, double precision, double precision) TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_rider_bind_session_token(text) IS
  'Binds a rider UUID token once to auth.uid(); existing ownership cannot be overwritten.';
COMMENT ON FUNCTION public.fn_create_rider_session(text, text) IS
  'Creates/claims a rider identity only after Supabase Auth has verified the same email.';
