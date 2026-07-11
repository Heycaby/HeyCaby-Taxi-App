-- Sprint 1.5 security fixes:
-- 1) Tighten rider_favorite_drivers RLS — add auth.uid() ownership check
-- 2) Enable RLS on ride_shares + create fn_rider_create_share_token RPC

-- ===========================================================================
-- 1) rider_favorite_drivers — replace permissive policies with ownership checks
-- ===========================================================================

ALTER TABLE public.rider_favorite_drivers ENABLE ROW LEVEL SECURITY;

-- Riders can read only their own favorites
DROP POLICY IF EXISTS riders_select_favorite_drivers ON public.rider_favorite_drivers;
CREATE POLICY riders_select_favorite_drivers ON public.rider_favorite_drivers
  FOR SELECT USING (
    rider_identity_id IN (
      SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
    )
    OR auth.role() = 'service_role'
  );

-- Riders can insert favorites only for their own identity
DROP POLICY IF EXISTS riders_insert_favorite_drivers ON public.rider_favorite_drivers;
CREATE POLICY riders_insert_favorite_drivers ON public.rider_favorite_drivers
  FOR INSERT WITH CHECK (
    rider_identity_id IN (
      SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
    )
  );

-- Riders can delete only their own favorites
DROP POLICY IF EXISTS riders_delete_favorite_drivers ON public.rider_favorite_drivers;
CREATE POLICY riders_delete_favorite_drivers ON public.rider_favorite_drivers
  FOR DELETE USING (
    rider_identity_id IN (
      SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
    )
  );

-- Drivers can see who favorited them (unchanged, kept for backward compat)
DROP POLICY IF EXISTS drivers_see_own_favorites ON public.rider_favorite_drivers;
CREATE POLICY drivers_see_own_favorites ON public.rider_favorite_drivers
  FOR SELECT USING (
    driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
  );

-- Service role keeps full access
DROP POLICY IF EXISTS service_role_manage_rider_favorite_drivers ON public.rider_favorite_drivers;
CREATE POLICY service_role_manage_rider_favorite_drivers ON public.rider_favorite_drivers
  FOR ALL USING (true) WITH CHECK (true);

-- ===========================================================================
-- 2) ride_shares — enable RLS + create RPC for safe share-token creation
-- ===========================================================================

ALTER TABLE public.ride_shares ENABLE ROW LEVEL SECURITY;

-- Riders can read their own share tokens (by rider_token match on the ride)
DROP POLICY IF EXISTS riders_select_own_shares ON public.ride_shares;
CREATE POLICY riders_select_own_shares ON public.ride_shares
  FOR SELECT USING (
    ride_request_id IN (
      SELECT rr.id
      FROM public.ride_requests rr
      WHERE rr.rider_token = ride_shares.rider_token
        AND (
          rr.rider_identity_id IN (
            SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
          )
          OR rr.rider_token IN (
            SELECT rs.session_token
            FROM public.rider_sessions rs
            WHERE rs.user_id = auth.uid()
          )
        )
    )
    OR auth.role() = 'service_role'
  );

-- No direct INSERT/UPDATE/DELETE from riders — must use fn_rider_create_share_token RPC
DROP POLICY IF EXISTS riders_insert_shares ON public.ride_shares;
DROP POLICY IF EXISTS riders_update_shares ON public.ride_shares;
DROP POLICY IF EXISTS riders_delete_shares ON public.ride_shares;

-- Service role full access
DROP POLICY IF EXISTS service_role_manage_ride_shares ON public.ride_shares;
CREATE POLICY service_role_manage_ride_shares ON public.ride_shares
  FOR ALL USING (true) WITH CHECK (true);

-- Anonymous/public read for share-token lookup (get-shared-ride Edge Function uses service role)
-- No anon access needed — EF uses service role key.

-- ===========================================================================
-- 3) fn_rider_create_share_token — RPC with ownership verification
-- ===========================================================================

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
  v_ride          public.ride_requests%ROWTYPE;
  v_auth_ok       boolean := false;
  v_existing      jsonb;
  v_share_token   text;
  v_result        jsonb;
BEGIN
  IF p_ride_request_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_ride_id');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  -- Authorization: identity match
  IF v_ride.rider_identity_id IS NOT NULL AND auth.uid() IS NOT NULL THEN
    SELECT EXISTS(
      SELECT 1 FROM public.rider_identities ri
      WHERE ri.id = v_ride.rider_identity_id AND ri.user_id = auth.uid()
    ) INTO v_auth_ok;
  END IF;

  -- Authorization: explicit rider_token match
  IF NOT v_auth_ok
     AND p_rider_token IS NOT NULL
     AND btrim(p_rider_token) <> ''
     AND v_ride.rider_token = btrim(p_rider_token) THEN
    v_auth_ok := true;
  END IF;

  -- Authorization: session token match
  IF NOT v_auth_ok
     AND auth.uid() IS NOT NULL
     AND v_ride.rider_token IS NOT NULL THEN
    SELECT EXISTS(
      SELECT 1 FROM public.rider_sessions rs
      WHERE rs.user_id = auth.uid()
        AND rs.session_token = v_ride.rider_token
    ) INTO v_auth_ok;
  END IF;

  IF NOT v_auth_ok THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authorized');
  END IF;

  -- Check for existing active share
  SELECT to_jsonb(rs) INTO v_existing
  FROM public.ride_shares rs
  WHERE rs.ride_request_id = p_ride_request_id
    AND rs.is_active = true
  LIMIT 1;

  IF v_existing IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', true,
      'share_token', v_existing->>'share_token',
      'share_url', '/track/' || v_existing->>'share_token',
      'already_existed', true
    );
  END IF;

  -- Insert new share row (share_token auto-generated by default/gen_random_uuid)
  INSERT INTO public.ride_shares (ride_request_id, rider_token, is_active)
  VALUES (p_ride_request_id, v_ride.rider_token, true)
  RETURNING to_jsonb(ride_shares) INTO v_result;

  RETURN jsonb_build_object(
    'ok', true,
    'share_token', v_result->>'share_token',
    'share_url', '/track/' || v_result->>'share_token',
    'already_existed', false
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_create_share_token(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_create_share_token(uuid, text) TO authenticated;

COMMENT ON FUNCTION public.fn_rider_create_share_token(uuid, text) IS
  'Rider creates a share-trip token; authorizes via rider_token, identity, or session.';
