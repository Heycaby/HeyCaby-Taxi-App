-- Phase 2A: Lifecycle matrix audit + canonical ride_events view (foundation for 2C).
--
-- Run after each two-phone test ride:
--   SELECT public.fn_ride_lifecycle_matrix_audit('<ride_id>');
--
-- Every cell must be green before Phase 2B (APNs Live Activity push).

-- ---------------------------------------------------------------------------
-- Canonical event stream (VIEW over ride_audit_log — Phase 2C precursor)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.ride_events AS
SELECT
  ral.id,
  ral.ride_id,
  CASE ral.event
    WHEN 'ride.created' THEN 'ride_created'
    WHEN 'offer.sent' THEN 'driver_invited'
    WHEN 'offer.accepted' THEN 'driver_accepted'
    WHEN 'ride.accepted' THEN 'driver_accepted'
    WHEN 'trip.en_route' THEN 'driver_on_way'
    WHEN 'driver.ping_on_my_way' THEN 'driver_on_way'
    WHEN 'driver.ping_on_my_way.delivered' THEN 'driver_on_way'
    WHEN 'near_pickup.notified' THEN 'driver_nearby'
    WHEN 'trip.arrived' THEN 'driver_arrived'
    WHEN 'waiting.grace_started' THEN 'driver_arrived'
    WHEN 'driver.ping_outside' THEN 'driver_arrived'
    WHEN 'driver.ping_arrived' THEN 'driver_arrived'
    WHEN 'trip.started' THEN 'ride_started'
    WHEN 'trip.completed' THEN 'ride_completed'
    WHEN 'payment.confirmed' THEN 'payment_confirmed'
    WHEN 'receipt.issued' THEN 'receipt_created'
    WHEN 'trip.rated' THEN 'ride_rated'
    WHEN 'trip.rated_by_rider' THEN 'ride_rated'
    WHEN 'driver.favorited' THEN 'driver_favorited'
    ELSE replace(replace(ral.event, '.', '_'), '-', '_')
  END AS event_type,
  ral.occurred_at,
  ral.actor_id AS actor,
  ral.metadata AS payload,
  ral.event AS source_event
FROM public.ride_audit_log ral;

COMMENT ON VIEW public.ride_events IS
  'Canonical ride lifecycle event stream (mapped from ride_audit_log). Phase 2C target table will mirror this shape.';

GRANT SELECT ON public.ride_events TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Lifecycle matrix audit — backend proof for Phase 2A sign-off
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_ride_lifecycle_matrix_audit(p_ride_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_audit jsonb;
  v_notif jsonb;
  v_step jsonb;
  v_matrix jsonb := '[]'::jsonb;
  v_all_green boolean := true;
  v_has_event boolean;
  v_has_notif boolean;
BEGIN
  IF p_ride_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ride_id_required');
  END IF;

  SELECT * INTO v_ride FROM public.ride_requests rr WHERE rr.id = p_ride_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'event', event,
      'occurred_at', occurred_at,
      'metadata', metadata
    ) ORDER BY occurred_at
  ), '[]'::jsonb)
  INTO v_audit
  FROM public.ride_audit_log
  WHERE ride_id = p_ride_id;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'category', category,
      'title', title,
      'push_sent_at', push_sent_at,
      'created_at', created_at
    ) ORDER BY created_at
  ), '[]'::jsonb)
  INTO v_notif
  FROM public.notifications n
  WHERE (n.data->>'ride_request_id')::uuid = p_ride_id
     OR (n.data->>'ride_id')::uuid = p_ride_id;

  -- Helper: append step row
  -- ride_created
  v_has_event := v_audit @> '[{"event":"ride.created"}]'::jsonb
    OR EXISTS (SELECT 1 FROM jsonb_array_elements(v_audit) e WHERE e->>'event' = 'ride.created');
  v_step := jsonb_build_object(
    'step', 'ride_created',
    'rpc', v_has_event,
    'db', v_ride.created_at IS NOT NULL,
    'audit', v_has_event,
    'notification', true,
    'green', v_has_event AND v_ride.created_at IS NOT NULL
  );
  v_matrix := v_matrix || jsonb_build_array(v_step);
  IF NOT (v_step->>'green')::boolean THEN v_all_green := false; END IF;

  -- accept
  v_has_event := EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_audit) e
    WHERE e->>'event' IN ('ride.accepted', 'offer.accepted')
  );
  v_has_notif := EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_notif) e
    WHERE e->>'category' IN ('driver_found', 'driver_assigned', 'driver_accepted')
  );
  v_step := jsonb_build_object(
    'step', 'driver_accepted',
    'rpc', v_has_event,
    'db', v_ride.accepted_at IS NOT NULL AND v_ride.driver_id IS NOT NULL,
    'audit', v_has_event,
    'notification', v_has_notif,
    'green', v_has_event
      AND v_ride.accepted_at IS NOT NULL
      AND v_ride.driver_id IS NOT NULL
      AND v_has_notif
  );
  v_matrix := v_matrix || jsonb_build_array(v_step);
  IF NOT (v_step->>'green')::boolean THEN v_all_green := false; END IF;

  -- on my way (optional if driver skips — flag yellow via optional key)
  v_has_event := EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_audit) e
    WHERE e->>'event' IN ('trip.en_route', 'driver.ping_on_my_way', 'driver.ping_on_my_way.delivered')
  ) OR v_ride.status IN ('driver_en_route', 'driver_arrived', 'in_progress', 'completed');
  v_has_notif := EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_notif) e
    WHERE e->>'category' IN ('driver_en_route', 'driver_ping_on_my_way')
  );
  v_step := jsonb_build_object(
    'step', 'driver_on_way',
    'optional', true,
    'rpc', v_has_event OR v_ride.status IN ('driver_en_route', 'driver_arrived', 'in_progress', 'completed'),
    'db', v_ride.status IN ('driver_en_route', 'driver_arrived', 'in_progress', 'completed')
      OR EXISTS (
        SELECT 1 FROM jsonb_array_elements(v_audit) e
        WHERE e->>'event' = 'ride.status_changed'
          AND e->'metadata'->>'to_status' = 'driver_en_route'
      ),
    'audit', v_has_event,
    'notification', v_has_notif OR v_ride.status IN ('driver_arrived', 'in_progress', 'completed'),
    'green', v_ride.status IN ('driver_arrived', 'in_progress', 'completed')
      OR (v_has_event AND v_has_notif)
  );
  v_matrix := v_matrix || jsonb_build_array(v_step);

  -- nearby
  v_has_event := v_ride.near_pickup_notified_at IS NOT NULL
    OR EXISTS (
      SELECT 1 FROM jsonb_array_elements(v_audit) e
      WHERE e->>'event' = 'near_pickup.notified'
    );
  v_has_notif := EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_notif) e
    WHERE e->>'category' IN ('driver_near_pickup', 'near_pickup')
  );
  v_step := jsonb_build_object(
    'step', 'driver_nearby',
    'optional', true,
    'rpc', v_has_event,
    'db', v_ride.near_pickup_notified_at IS NOT NULL,
    'audit', v_has_event,
    'notification', v_has_notif,
    'green', v_ride.near_pickup_notified_at IS NOT NULL AND v_has_notif
  );
  v_matrix := v_matrix || jsonb_build_array(v_step);

  -- arrived
  v_has_event := EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_audit) e
    WHERE e->>'event' IN ('trip.arrived', 'waiting.grace_started')
  );
  v_has_notif := EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_notif) e
    WHERE e->>'category' IN ('ride_arrived', 'driver_ping_arrived', 'driver_ping_outside')
  );
  v_step := jsonb_build_object(
    'step', 'driver_arrived',
    'rpc', v_has_event,
    'db', v_ride.driver_arrived_at IS NOT NULL,
    'audit', v_has_event,
    'notification', v_has_notif,
    'green', v_has_event
      AND v_ride.driver_arrived_at IS NOT NULL
      AND v_has_notif
  );
  v_matrix := v_matrix || jsonb_build_array(v_step);
  IF v_ride.status IN ('driver_arrived', 'in_progress', 'completed')
     AND NOT (v_step->>'green')::boolean THEN
    v_all_green := false;
  END IF;

  -- start
  v_has_event := EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_audit) e
    WHERE e->>'event' = 'trip.started'
  );
  v_has_notif := EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_notif) e
    WHERE e->>'category' IN ('ride_started', 'trip_started')
  );
  v_step := jsonb_build_object(
    'step', 'ride_started',
    'rpc', v_has_event,
    'db', v_ride.started_at IS NOT NULL AND v_ride.status IN ('in_progress', 'completed'),
    'audit', v_has_event,
    'notification', v_has_notif,
    'green', v_has_event
      AND v_ride.started_at IS NOT NULL
      AND v_has_notif
  );
  v_matrix := v_matrix || jsonb_build_array(v_step);
  IF v_ride.status IN ('in_progress', 'completed') AND NOT (v_step->>'green')::boolean THEN
    v_all_green := false;
  END IF;

  -- complete
  v_has_event := EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_audit) e
    WHERE e->>'event' = 'trip.completed'
  );
  v_has_notif := EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_notif) e
    WHERE e->>'category' IN ('ride_completed', 'trip_completed')
  );
  v_step := jsonb_build_object(
    'step', 'ride_completed',
    'rpc', v_has_event,
    'db', v_ride.completed_at IS NOT NULL,
    'audit', v_has_event,
    'notification', v_has_notif,
    'green', v_has_event
      AND v_ride.completed_at IS NOT NULL
      AND v_has_notif
  );
  v_matrix := v_matrix || jsonb_build_array(v_step);
  IF v_ride.status = 'completed' AND NOT (v_step->>'green')::boolean THEN
    v_all_green := false;
  END IF;

  -- payment
  v_has_event := EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_audit) e
    WHERE e->>'event' = 'payment.confirmed'
  );
  v_has_notif := EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_notif) e
    WHERE e->>'category' IN ('payment_confirmed', 'payment')
  );
  v_step := jsonb_build_object(
    'step', 'payment_confirmed',
    'optional', COALESCE(v_ride.payment_status, 'pending') NOT IN ('confirmed', 'paid'),
    'rpc', v_has_event,
    'db', COALESCE(v_ride.payment_status, '') IN ('confirmed', 'paid'),
    'audit', v_has_event,
    'notification', v_has_notif,
    'green', CASE
      WHEN COALESCE(v_ride.payment_status, '') IN ('confirmed', 'paid') THEN
        v_has_event AND v_has_notif
      ELSE true
    END
  );
  v_matrix := v_matrix || jsonb_build_array(v_step);

  -- rating (optional post-complete)
  v_has_event := EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_audit) e
    WHERE e->>'event' IN ('trip.rated', 'trip.rated_by_rider')
  );
  v_step := jsonb_build_object(
    'step', 'ride_rated',
    'optional', true,
    'rpc', v_has_event,
    'db', v_has_event,
    'audit', v_has_event,
    'notification', true,
    'green', true
  );
  v_matrix := v_matrix || jsonb_build_array(v_step);

  -- favorite (optional)
  v_has_event := EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_audit) e
    WHERE e->>'event' = 'driver.favorited'
  );
  v_step := jsonb_build_object(
    'step', 'driver_favorited',
    'optional', true,
    'rpc', v_has_event,
    'db', v_has_event,
    'audit', v_has_event,
    'notification', true,
    'green', true
  );
  v_matrix := v_matrix || jsonb_build_array(v_step);

  RETURN jsonb_build_object(
    'ok', true,
    'ride_id', p_ride_id,
    'status', v_ride.status,
    'all_required_green', v_all_green,
    'matrix', v_matrix,
    'ride_row', jsonb_build_object(
      'status', v_ride.status,
      'accepted_at', v_ride.accepted_at,
      'driver_arrived_at', v_ride.driver_arrived_at,
      'near_pickup_notified_at', v_ride.near_pickup_notified_at,
      'started_at', v_ride.started_at,
      'completed_at', v_ride.completed_at,
      'payment_status', v_ride.payment_status,
      'updated_at', v_ride.updated_at
    ),
    'audit_events', v_audit,
    'notifications', v_notif,
    'canonical_events', (
      SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
          'event_type', event_type,
          'occurred_at', occurred_at,
          'actor', actor
        ) ORDER BY occurred_at
      ), '[]'::jsonb)
      FROM public.ride_events re
      WHERE re.ride_id = p_ride_id
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_ride_lifecycle_matrix_audit(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_ride_lifecycle_matrix_audit(uuid) TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_ride_lifecycle_matrix_audit(uuid) IS
  'Phase 2A: Returns green/red matrix for RPC, DB, audit, notification per lifecycle step.';
