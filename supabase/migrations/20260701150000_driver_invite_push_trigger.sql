-- Driver invite push reliability:
-- Realtime gets foreground drivers the invite row. This trigger sends the same
-- invite insert to driver-agent so background/locked devices can receive FCM.
-- The target function reads the webhook secret from app_config, so no bearer
-- token is embedded in the trigger definition.

DROP TRIGGER IF EXISTS driver_agent_on_ride_request_invites ON public.ride_request_invites;

CREATE TRIGGER driver_agent_on_ride_request_invites
AFTER INSERT ON public.ride_request_invites
FOR EACH ROW
EXECUTE FUNCTION public.notify_driver_agent_trigger();
