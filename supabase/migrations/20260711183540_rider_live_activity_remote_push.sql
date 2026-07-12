-- Server-driven iOS Live Activity delivery.
-- ActivityKit update tokens are per activity and rotate, so they are stored
-- separately from ordinary FCM device tokens and are never exposed via REST.

CREATE TABLE IF NOT EXISTS public.rider_live_activities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_request_id uuid NOT NULL REFERENCES public.ride_requests(id) ON DELETE CASCADE,
  rider_identity_id uuid REFERENCES public.rider_identities(id) ON DELETE CASCADE,
  auth_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  activity_id text NOT NULL,
  activity_push_token text NOT NULL,
  fcm_token text NOT NULL,
  platform text NOT NULL DEFAULT 'ios' CHECK (platform = 'ios'),
  is_active boolean NOT NULL DEFAULT true,
  last_event_version bigint NOT NULL DEFAULT 0,
  last_pushed_at timestamptz,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (activity_push_token)
);

CREATE UNIQUE INDEX IF NOT EXISTS rider_live_activities_one_active_ride_device_idx
  ON public.rider_live_activities (ride_request_id, fcm_token)
  WHERE is_active;
CREATE INDEX IF NOT EXISTS rider_live_activities_ride_idx
  ON public.rider_live_activities (ride_request_id)
  WHERE is_active;

ALTER TABLE public.rider_live_activities ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.rider_live_activities FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.rider_live_activities TO service_role;

CREATE OR REPLACE FUNCTION public.fn_register_rider_live_activity(
  p_ride_request_id uuid,
  p_activity_id text,
  p_activity_push_token text,
  p_fcm_token text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_ride public.ride_requests%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  IF p_ride_request_id IS NULL
     OR length(btrim(COALESCE(p_activity_id, ''))) < 8
     OR length(btrim(COALESCE(p_activity_push_token, ''))) < 32
     OR length(btrim(COALESCE(p_fcm_token, ''))) < 10 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_registration');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests
  WHERE id = p_ride_request_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'ride_not_found');
  END IF;

  IF NOT (
    EXISTS (
      SELECT 1 FROM public.rider_identities ri
      WHERE ri.id = v_ride.rider_identity_id AND ri.user_id = v_uid
    )
    OR EXISTS (
      SELECT 1 FROM public.rider_sessions rs
      WHERE rs.user_id = v_uid
        AND NULLIF(btrim(rs.session_token), '') = NULLIF(btrim(v_ride.rider_token), '')
    )
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'ride_not_owned');
  END IF;

  -- The same device may begin a replacement activity after iOS invalidates a token.
  UPDATE public.rider_live_activities
  SET is_active = false, updated_at = timezone('utc', now())
  WHERE ride_request_id = p_ride_request_id
    AND fcm_token = btrim(p_fcm_token)
    AND activity_push_token <> btrim(p_activity_push_token)
    AND is_active;

  INSERT INTO public.rider_live_activities (
    ride_request_id, rider_identity_id, auth_user_id, activity_id,
    activity_push_token, fcm_token, is_active, updated_at
  ) VALUES (
    p_ride_request_id, v_ride.rider_identity_id, v_uid, btrim(p_activity_id),
    btrim(p_activity_push_token), btrim(p_fcm_token), true, timezone('utc', now())
  )
  ON CONFLICT (activity_push_token) DO UPDATE SET
    ride_request_id = EXCLUDED.ride_request_id,
    rider_identity_id = EXCLUDED.rider_identity_id,
    auth_user_id = EXCLUDED.auth_user_id,
    activity_id = EXCLUDED.activity_id,
    fcm_token = EXCLUDED.fcm_token,
    is_active = true,
    last_error = NULL,
    updated_at = timezone('utc', now());

  RETURN jsonb_build_object('success', true);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_register_rider_live_activity(uuid, text, text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_register_rider_live_activity(uuid, text, text, text)
  TO authenticated;

COMMENT ON TABLE public.rider_live_activities IS
  'Private ActivityKit update-token registry for server-driven rider lock-screen lifecycle updates.';
