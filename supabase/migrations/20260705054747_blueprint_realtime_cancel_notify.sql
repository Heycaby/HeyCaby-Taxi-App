-- Backend Flow Blueprint: Realtime Contract + Cancel Notification Symmetry
-- Source: docs/HEYCABY_BACKEND_FLOW_BLUEPRINT.md
-- 1. Realtime publication: add ride_swaps + messages (verified absent from
--    supabase_realtime; existing members untouched).
-- 2. fn_driver_ride_cancel: rider cancellation notification (cancel must
--    never be a local-only state change).

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public' AND tablename = 'ride_swaps'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.ride_swaps;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public' AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;
END $$;

-- Cancel contract: notify the rider when the driver cancels.
CREATE OR REPLACE FUNCTION public.fn_driver_ride_cancel(
  p_ride_request_id uuid,
  p_reason text DEFAULT NULL
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
  v_ride public.ride_requests%ROWTYPE;
  v_rider_target text;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND OR v_ride.driver_id IS DISTINCT FROM v_driver_id
     OR v_ride.status NOT IN ('accepted', 'driver_arrived', 'in_progress') THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  UPDATE public.ride_requests rr
  SET status = 'cancelled',
      cancelled_at = timezone('utc', now()),
      cancelled_by = 'driver',
      cancellation_reason = NULLIF(btrim(COALESCE(p_reason, '')), ''),
      updated_at = timezone('utc', now())
  WHERE rr.id = p_ride_request_id;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  PERFORM public.fn_driver_ride_lifecycle_release_driver(v_driver_id);

  PERFORM public.fn_ride_audit_append(
    p_ride_request_id, 'ride.cancelled', v_driver_id,
    jsonb_build_object(
      'actor', 'driver',
      'reason', p_reason,
      'previous_status', v_ride.status
    ),
    'driver', 'rpc', p_ride_request_id
  );

  v_rider_target := COALESCE(v_ride.rider_identity_id::text, v_ride.rider_id::text);
  PERFORM public.fn_ride_event_notify(
    'rider', v_rider_target, 'ride_cancelled',
    'Ride cancelled',
    'Your driver cancelled this ride. You can book again right away.',
    jsonb_build_object(
      'type', 'ride_cancelled',
      'ride_request_id', p_ride_request_id,
      'cancelled_by', 'driver'
    ),
    'critical'
  );

  RETURN json_build_object('ok', true, 'status', 'cancelled', 'ride_id', p_ride_request_id);
END;
$$;
