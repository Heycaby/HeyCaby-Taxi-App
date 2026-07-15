-- Taxi Terug offer boosts are authoritative backend commands.
--
-- The released RPC signature is preserved. The backend calculates the delta,
-- writes the fare snapshot atomically, appends one audit event, publishes the
-- ride row through existing Realtime, and enqueues one driver-agent event.

CREATE OR REPLACE FUNCTION private.fn_driver_agent_enqueue_event(
  p_payload jsonb
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, vault
AS $$
DECLARE
  v_url text;
  v_secret text;
  v_request_id bigint;
BEGIN
  IF p_payload IS NULL OR jsonb_typeof(p_payload) <> 'object' THEN
    RAISE WARNING 'driver-agent event not enqueued: invalid payload';
    RETURN NULL;
  END IF;

  SELECT trim(ac.value)
  INTO v_url
  FROM public.app_config ac
  WHERE ac.key = 'agent_webhook_url'
  LIMIT 1;

  SELECT ds.decrypted_secret
  INTO v_secret
  FROM vault.decrypted_secrets ds
  WHERE ds.name = 'agent_webhook_secret'
  LIMIT 1;

  IF coalesce(v_url, '') = '' OR coalesce(v_secret, '') = '' THEN
    RAISE WARNING 'driver-agent event not enqueued: webhook configuration unavailable';
    RETURN NULL;
  END IF;

  SELECT net.http_post(
    url := v_url,
    body := p_payload,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', v_secret
    ),
    timeout_milliseconds := 5000
  )
  INTO v_request_id;

  RETURN v_request_id;
END;
$$;

REVOKE ALL ON FUNCTION private.fn_driver_agent_enqueue_event(jsonb)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.fn_driver_agent_enqueue_event(jsonb)
  TO service_role;

COMMENT ON FUNCTION private.fn_driver_agent_enqueue_event(jsonb) IS
  'Canonical Vault-backed enqueue boundary for database events delivered to driver-agent.';

-- Keep existing trigger behavior while removing its independent copy of the
-- webhook URL/secret transport contract.
CREATE OR REPLACE FUNCTION public.notify_driver_agent_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, pg_catalog
AS $$
DECLARE
  v_payload jsonb;
BEGIN
  v_payload := jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'record', CASE
      WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD)
      ELSE to_jsonb(NEW)
    END,
    'old_record', CASE
      WHEN TG_OP = 'UPDATE' THEN to_jsonb(OLD)
      ELSE NULL
    END
  );

  PERFORM private.fn_driver_agent_enqueue_event(v_payload);
  RETURN coalesce(NEW, OLD);
END;
$$;

REVOKE ALL ON FUNCTION public.notify_driver_agent_trigger()
  FROM PUBLIC, anon, authenticated;

CREATE UNIQUE INDEX IF NOT EXISTS notifications_taxi_terug_event_driver_uidx
  ON public.notifications (
    user_id,
    ((data ->> 'source_event_id'))
  )
  WHERE category = 'taxi_terug_offer_increased'
    AND data ? 'source_event_id';

CREATE OR REPLACE FUNCTION public.fn_rider_boost_marketplace_offer(
  p_ride_request_id uuid,
  p_new_fare numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, pg_catalog
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_mode text;
  v_previous_fare numeric;
  v_new_fare numeric;
  v_increase numeric;
  v_updated_at timestamptz;
  v_event_id uuid;
  v_delivery_request_id bigint;
BEGIN
  IF auth.uid() IS NULL
     OR NOT private.rider_owns_ride(p_ride_request_id) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_authorized');
  END IF;

  IF p_new_fare IS NULL OR p_new_fare <= 0 OR p_new_fare >= 9999 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_fare');
  END IF;

  SELECT rr.*
  INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND
     OR v_ride.booking_mode::text NOT IN ('marketplace', 'terug')
     OR v_ride.driver_id IS NOT NULL
     OR v_ride.status NOT IN ('pending', 'bidding')
     OR (v_ride.expires_at IS NOT NULL AND v_ride.expires_at <= now()) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'ride_not_boostable');
  END IF;

  v_mode := v_ride.booking_mode::text;
  v_previous_fare := round(coalesce(
    v_ride.marketplace_offered_fare,
    v_ride.offered_fare,
    v_ride.quoted_fare,
    v_ride.estimated_fare,
    0
  )::numeric, 2);
  v_new_fare := round(p_new_fare::numeric, 2);

  IF v_new_fare <= v_previous_fare THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'fare_not_increased',
      'previous_fare', v_previous_fare
    );
  END IF;

  v_increase := v_new_fare - v_previous_fare;
  v_event_id := gen_random_uuid();
  v_updated_at := timezone('utc', now());

  UPDATE public.ride_requests rr
  SET marketplace_offered_fare = v_new_fare,
      offered_fare = v_new_fare,
      quoted_fare = v_new_fare,
      estimated_fare = v_new_fare,
      updated_at = v_updated_at
  WHERE rr.id = p_ride_request_id;

  PERFORM public.fn_ride_audit_append(
    p_ride_request_id,
    CASE
      WHEN v_mode = 'terug' THEN 'taxi_terug.offer_increased'
      ELSE 'marketplace.offer_increased'
    END,
    auth.uid(),
    jsonb_build_object(
      'source_event_id', v_event_id,
      'booking_mode', v_mode,
      'previous_fare', v_previous_fare,
      'new_fare', v_new_fare,
      'increase', v_increase
    ),
    'rider',
    'rpc',
    v_event_id
  );

  IF v_mode = 'terug' THEN
    v_delivery_request_id := private.fn_driver_agent_enqueue_event(
      jsonb_build_object(
        'event', 'taxi_terug_offer_increased',
        'source_event_id', v_event_id,
        'ride_request_id', p_ride_request_id,
        'previous_fare', v_previous_fare,
        'new_fare', v_new_fare,
        'increase', v_increase,
        'occurred_at', v_updated_at
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'offer_boosted',
    'ride_request_id', p_ride_request_id,
    'booking_mode', v_mode,
    'previous_fare', v_previous_fare,
    'fare', v_new_fare,
    'new_fare', v_new_fare,
    'increase', v_increase,
    'source_event_id', v_event_id,
    'delivery_request_id', v_delivery_request_id,
    'state_version', floor(extract(epoch FROM v_updated_at) * 1000)::bigint
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_boost_marketplace_offer(uuid, numeric)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_rider_boost_marketplace_offer(uuid, numeric)
  TO authenticated;

COMMENT ON FUNCTION public.fn_rider_boost_marketplace_offer(uuid, numeric) IS
  'Auth-bound Rider offer increase for marketplace and Taxi Terug; returns backend-calculated old/new/delta and enqueues Taxi Terug delivery.';
