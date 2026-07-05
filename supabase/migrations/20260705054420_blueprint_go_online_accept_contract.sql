-- Backend Flow Blueprint: Go Online Contract + Accept Ride Contract + Chat Context
-- Source: docs/HEYCABY_BACKEND_FLOW_BLUEPRINT.md
-- 1. fn_driver_set_status: fresh-GPS guard (5 min) + missing-tariff blocker with exact reasons.
-- 2. fn_payment_compatible: shared payment compatibility helper (matching + accept).
-- 3. fn_driver_accept_ride_invite: row lock, idempotent retry, tariff + GPS recheck,
--    accepted_at, conversation context, rider driver-found notification, audit.
-- 4. conversations table: durable chat context per ride (destination contract).

-- 1) conversations table (verified absent)
CREATE TABLE IF NOT EXISTS public.conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_request_id uuid NOT NULL UNIQUE REFERENCES public.ride_requests(id) ON DELETE CASCADE,
  driver_id uuid,
  rider_identity_id uuid,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policy WHERE polname = 'conversations_participants_read'
      AND polrelid = 'public.conversations'::regclass
  ) THEN
    CREATE POLICY conversations_participants_read ON public.conversations
      FOR SELECT USING (
        driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
        OR rider_identity_id IN (
          SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id = auth.uid()
        )
        OR auth.role() = 'service_role'
      );
  END IF;
END $$;

-- messages.conversation_id (legacy ride_request_id path remains supported)
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS conversation_id uuid REFERENCES public.conversations(id);

CREATE INDEX IF NOT EXISTS idx_messages_conversation_id
  ON public.messages(conversation_id) WHERE conversation_id IS NOT NULL;

-- 2) Payment compatibility helper (verified absent)
CREATE OR REPLACE FUNCTION public.fn_payment_compatible(
  p_driver_id uuid,
  p_rider_payment_methods text[]
) RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_driver_methods text[];
BEGIN
  -- No rider preference means any driver is compatible.
  IF p_rider_payment_methods IS NULL
     OR cardinality(p_rider_payment_methods) = 0 THEN
    RETURN true;
  END IF;

  SELECT array_agg(lower(trim(m::text))) INTO v_driver_methods
  FROM public.drivers d, unnest(COALESCE(d.payment_methods, '{}')) m
  WHERE d.id = p_driver_id;

  -- Driver without a declared list keeps legacy behavior: compatible.
  IF v_driver_methods IS NULL OR cardinality(v_driver_methods) = 0 THEN
    RETURN true;
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM unnest(p_rider_payment_methods) r
    WHERE lower(trim(r)) = ANY (v_driver_methods)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_payment_compatible(uuid, text[]) TO authenticated;

-- 3) Go-online guards: fresh GPS (5 min) + active tariff, exact blockers
CREATE OR REPLACE FUNCTION public.fn_driver_set_status(
  p_status text,
  p_lat double precision DEFAULT NULL,
  p_lng double precision DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_driver_id uuid;
  v_user_id uuid := auth.uid();
  v_d public.drivers%ROWTYPE;
  v_readiness jsonb;
  v_billing jsonb;
  v_flags jsonb;
  v_skip_gates boolean := false;
  v_status text := lower(trim(COALESCE(p_status, '')));
  v_has_fresh_gps boolean := false;
  v_has_tariff boolean := false;
BEGIN
  IF v_status NOT IN ('available', 'offline', 'on_break') THEN
    RETURN jsonb_build_object(
      'status', 'offline',
      'blocked_reason', 'invalid_status',
      'message', 'Invalid status'
    );
  END IF;

  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = v_user_id
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'offline',
      'blocked_reason', 'not_a_driver',
      'message', 'Driver profile not found'
    );
  END IF;

  SELECT * INTO v_d FROM public.drivers d WHERE d.id = v_driver_id;

  v_flags := public.fn_app_config_jsonb('feature_flags');
  v_skip_gates := COALESCE((v_flags->>'skip_go_online_gates')::boolean, false);

  IF v_status = 'available' THEN
    v_readiness := public.fn_driver_readiness_eval(v_driver_id);
    IF COALESCE((v_readiness->>'can_go_online')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object(
        'status', 'offline',
        'blocked_reason', 'missing_docs',
        'message', COALESCE(v_readiness->>'status_message', 'Compliance incomplete'),
        'readiness', v_readiness
      );
    END IF;

    IF NOT v_skip_gates AND NOT public.fn_driver_is_review_account(v_user_id) THEN
      -- Blueprint: fresh valid GPS required; reject if missing or older than 5 min.
      v_has_fresh_gps := (p_lat IS NOT NULL AND p_lng IS NOT NULL)
        OR EXISTS (
          SELECT 1 FROM public.driver_locations dl
          WHERE dl.driver_id = v_driver_id
            AND dl.latitude IS NOT NULL AND dl.longitude IS NOT NULL
            AND dl.updated_at > now() - interval '5 minutes'
        );
      IF NOT v_has_fresh_gps THEN
        RETURN jsonb_build_object(
          'status', 'offline',
          'blocked_reason', 'missing_location',
          'message', 'Enable location to go online',
          'redirect', '/driver/location'
        );
      END IF;

      -- Blueprint: at least one active initial tariff required.
      v_has_tariff := EXISTS (
        SELECT 1 FROM public.driver_rate_profiles rp
        WHERE rp.driver_id = v_driver_id AND rp.is_active = true
      );
      IF NOT v_has_tariff THEN
        RETURN jsonb_build_object(
          'status', 'offline',
          'blocked_reason', 'missing_tariff',
          'message', 'Set your first tariff before going online',
          'redirect', '/driver/tariffs'
        );
      END IF;

      PERFORM public.fn_driver_platform_balance_ensure_weekly(v_driver_id);
      v_billing := public.fn_driver_can_accept_rides(v_driver_id);
      IF COALESCE((v_billing->>'allowed')::boolean, false) IS NOT TRUE THEN
        RETURN jsonb_build_object(
          'status', 'offline',
          'blocked_reason', 'payment_required',
          'message', COALESCE(v_billing->>'reason', 'Platform fee payment required'),
          'redirect', '/driver/billing'
        );
      END IF;
    END IF;
  END IF;

  UPDATE public.drivers
  SET status = v_status::public.driver_status,
      updated_at = timezone('utc', now())
  WHERE id = v_driver_id;

  IF p_lat IS NOT NULL AND p_lng IS NOT NULL THEN
    INSERT INTO public.driver_locations (
      user_id, driver_id, latitude, longitude, country_code, updated_at
    )
    VALUES (
      v_user_id, v_driver_id, p_lat, p_lng,
      COALESCE(v_d.country_code, 'NL'), timezone('utc', now())
    )
    ON CONFLICT (user_id) DO UPDATE
    SET driver_id = EXCLUDED.driver_id,
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        country_code = EXCLUDED.country_code,
        updated_at = EXCLUDED.updated_at;
  END IF;

  RETURN jsonb_build_object(
    'status', v_status,
    'message', CASE
      WHEN v_status = 'available' THEN 'Online'
      WHEN v_status = 'on_break' THEN 'On break'
      ELSE 'Offline'
    END
  );
END;
$$;

-- 4) Atomic accept with lock, idempotency, rechecks, chat context, notification
CREATE OR REPLACE FUNCTION public.fn_driver_accept_ride_invite(p_ride_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
  v_billing jsonb;
  v_ride public.ride_requests%ROWTYPE;
  v_d public.drivers%ROWTYPE;
  v_conversation_id uuid;
  v_rider_target text;
BEGIN
  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  -- Lock the ride row first: single winner.
  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  -- Idempotency: same driver retrying after network retry gets context back.
  IF v_ride.status = 'accepted' AND v_ride.driver_id = v_driver_id THEN
    SELECT c.id INTO v_conversation_id
    FROM public.conversations c
    WHERE c.ride_request_id = p_ride_request_id;
    RETURN json_build_object(
      'ok', true, 'already_accepted', true,
      'ride_id', p_ride_request_id,
      'conversation_id', v_conversation_id
    );
  END IF;

  IF v_ride.status <> 'pending' THEN
    RETURN json_build_object('ok', false, 'error', 'race_lost');
  END IF;

  -- Billing recheck.
  v_billing := public.fn_driver_can_accept_rides(v_driver_id);
  IF COALESCE((v_billing->>'allowed')::boolean, false) = false THEN
    PERFORM public.fn_billing_audit_append(
      v_driver_id, 'billing.accept_blocked', p_ride_request_id,
      jsonb_build_object(
        'reason', v_billing->>'reason',
        'status', v_billing->>'status',
        'outstanding_cents', v_billing->>'outstanding_cents',
        'limit_cents', v_billing->>'limit_cents',
        'billing_enforcement', v_billing->>'billing_enforcement'
      ),
      p_ride_request_id
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.driver_rejected_billing', v_driver_id,
      jsonb_build_object(
        'reason', v_billing->>'reason',
        'status', v_billing->>'status',
        'outstanding_cents', v_billing->>'outstanding_cents',
        'limit_cents', v_billing->>'limit_cents'
      ),
      'driver', 'supabase_trigger', p_ride_request_id
    );
    RETURN json_build_object(
      'ok', false, 'error', 'billing_locked',
      'message', COALESCE(v_billing->>'reason', 'Outstanding platform fees exceed market limit.')
    );
  END IF;

  -- Valid pending invite required.
  IF NOT EXISTS (
    SELECT 1 FROM public.ride_request_invites i
    WHERE i.ride_request_id = p_ride_request_id
      AND i.driver_id = v_driver_id
      AND i.status = 'pending'
      AND i.expires_at > now()
  ) THEN
    RETURN json_build_object('ok', false, 'error', 'no_valid_invite');
  END IF;

  -- Active tariff recheck.
  IF NOT EXISTS (
    SELECT 1 FROM public.driver_rate_profiles rp
    WHERE rp.driver_id = v_driver_id AND rp.is_active = true
  ) THEN
    RETURN json_build_object('ok', false, 'error', 'missing_tariff');
  END IF;

  -- Fresh GPS recheck (3 min accept window).
  IF NOT EXISTS (
    SELECT 1 FROM public.driver_locations dl
    WHERE dl.driver_id = v_driver_id
      AND dl.latitude IS NOT NULL AND dl.longitude IS NOT NULL
      AND dl.updated_at > now() - interval '3 minutes'
  ) THEN
    RETURN json_build_object('ok', false, 'error', 'stale_location');
  END IF;

  -- Payment compatibility recheck (same helper as matching).
  IF NOT public.fn_payment_compatible(v_driver_id, v_ride.payment_methods) THEN
    RETURN json_build_object('ok', false, 'error', 'payment_incompatible');
  END IF;

  UPDATE public.ride_requests rr
  SET status = 'accepted',
      driver_id = v_driver_id,
      accepted_at = timezone('utc', now()),
      updated_at = now()
  WHERE rr.id = p_ride_request_id
    AND rr.status = 'pending';

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RETURN json_build_object('ok', false, 'error', 'race_lost');
  END IF;

  UPDATE public.ride_request_invites i
  SET status = 'superseded'
  WHERE i.ride_request_id = p_ride_request_id
    AND i.driver_id <> v_driver_id
    AND i.status = 'pending';

  UPDATE public.ride_request_invites i
  SET status = 'accepted'
  WHERE i.ride_request_id = p_ride_request_id
    AND i.driver_id = v_driver_id
    AND i.status = 'pending';

  -- Guarantee chat context.
  INSERT INTO public.conversations (ride_request_id, driver_id, rider_identity_id)
  VALUES (p_ride_request_id, v_driver_id, v_ride.rider_identity_id)
  ON CONFLICT (ride_request_id) DO UPDATE
  SET driver_id = EXCLUDED.driver_id
  RETURNING id INTO v_conversation_id;

  -- Rider driver-found notification event.
  SELECT * INTO v_d FROM public.drivers d WHERE d.id = v_driver_id;
  v_rider_target := COALESCE(v_ride.rider_identity_id::text, v_ride.rider_id::text);
  PERFORM public.fn_ride_event_notify(
    'rider', v_rider_target, 'driver_found',
    'Driver found',
    COALESCE(v_d.full_name, 'Your driver') || ' is on the way'
      || CASE
           WHEN COALESCE(v_d.vehicle_make, '') <> ''
             THEN ' in a ' || v_d.vehicle_make || ' ' || COALESCE(v_d.vehicle_model, '')
           ELSE ''
         END || '.',
    jsonb_build_object(
      'type', 'driver_found',
      'ride_request_id', p_ride_request_id,
      'driver_name', v_d.full_name,
      'vehicle_make', v_d.vehicle_make,
      'vehicle_model', v_d.vehicle_model,
      'vehicle_plate', v_d.vehicle_plate,
      'conversation_id', v_conversation_id
    ),
    'critical'
  );

  PERFORM public.fn_ride_audit_append(
    p_ride_request_id, 'ride.accepted', v_driver_id,
    jsonb_build_object('conversation_id', v_conversation_id),
    'driver', 'rpc', p_ride_request_id
  );

  RETURN json_build_object(
    'ok', true,
    'ride_id', p_ride_request_id,
    'conversation_id', v_conversation_id
  );
END;
$$;
