-- Taxi Terug: revoke PUBLIC execute on all terug RPCs/helpers.
-- Internal helpers: service_role only. Client RPCs: authenticated (+ anon where needed).

-- ---------------------------------------------------------------------------
-- Internal — service_role only (called from SECURITY DEFINER lifecycle RPCs)
-- ---------------------------------------------------------------------------

REVOKE ALL ON FUNCTION public.fn_taxi_terug_activate_queued_ride(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_taxi_terug_activate_queued_ride(uuid, uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_activate_queued_ride(uuid, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.fn_taxi_terug_queue_accepted_invite(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_taxi_terug_queue_accepted_invite(uuid, uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_queue_accepted_invite(uuid, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.fn_taxi_terug_handle_driver_cancel(uuid, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_taxi_terug_handle_driver_cancel(uuid, uuid, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_handle_driver_cancel(uuid, uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public.fn_taxi_terug_record_completion(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_taxi_terug_record_completion(uuid, uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_record_completion(uuid, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.fn_taxi_terug_driver_transit_context(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_taxi_terug_driver_transit_context(uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_driver_transit_context(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.fn_driver_has_queued_taxi_terug(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_has_queued_taxi_terug(uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_has_queued_taxi_terug(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.fn_driver_has_non_queued_active_ride(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_has_non_queued_active_ride(uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_has_non_queued_active_ride(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.fn_taxi_terug_recent_cancel_count(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_taxi_terug_recent_cancel_count(uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_recent_cancel_count(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.fn_taxi_terug_supply_eligible(uuid, public.ride_requests, geography, numeric) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_taxi_terug_supply_eligible(uuid, public.ride_requests, geography, numeric) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_supply_eligible(uuid, public.ride_requests, geography, numeric) TO service_role;

REVOKE ALL ON FUNCTION public.fn_taxi_terug_fare_euros(public.ride_requests) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_taxi_terug_fare_euros(public.ride_requests) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_fare_euros(public.ride_requests) TO service_role;

REVOKE ALL ON FUNCTION public.fn_taxi_terug_empty_km_for_ride(public.ride_requests) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_taxi_terug_empty_km_for_ride(public.ride_requests) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_empty_km_for_ride(public.ride_requests) TO service_role;

REVOKE ALL ON FUNCTION public.fn_taxi_terug_match_score(numeric, numeric, numeric, numeric, numeric, numeric, numeric) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_taxi_terug_match_score(numeric, numeric, numeric, numeric, numeric, numeric, numeric) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_match_score(numeric, numeric, numeric, numeric, numeric, numeric, numeric) TO service_role;

REVOKE ALL ON FUNCTION public.fn_taxi_terug_match_score(numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_taxi_terug_match_score(numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_match_score(numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric) TO service_role;

-- ---------------------------------------------------------------------------
-- Client RPCs — authenticated (+ anon for rider browse/supply)
-- ---------------------------------------------------------------------------

REVOKE ALL ON FUNCTION public.fn_taxi_terug_config() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_config() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.fn_terugtaxi_qualify(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_terugtaxi_qualify(uuid, uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.fn_rider_taxi_terug_supply(double precision, double precision, double precision, double precision) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_taxi_terug_supply(double precision, double precision, double precision, double precision) TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.fn_rider_taxi_terug_candidates(double precision, double precision, double precision, double precision, int) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_rider_taxi_terug_candidates(double precision, double precision, double precision, double precision, int, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_taxi_terug_candidates(double precision, double precision, double precision, double precision, int, int) TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.fn_driver_taxi_terug_queue_status() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_taxi_terug_queue_status() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.fn_rider_taxi_terug_queue_status(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_taxi_terug_queue_status(uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.fn_driver_taxi_terug_stats(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_taxi_terug_stats(text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.fn_driver_return_mode_status() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_return_mode_status() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.fn_driver_return_mode_activate(text, uuid, double precision, double precision, numeric, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_return_mode_activate(text, uuid, double precision, double precision, numeric, numeric) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.fn_seed_taxi_terug_matching_batch(uuid, int, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_seed_taxi_terug_matching_batch(uuid, int, int) TO authenticated, service_role;
