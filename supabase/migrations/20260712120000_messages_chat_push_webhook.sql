-- Driver ↔ rider chat push reliability:
-- Realtime delivers foreground in-app messages. This trigger forwards message
-- inserts to driver-agent so background/locked devices receive FCM as well.

DROP TRIGGER IF EXISTS driver_agent_on_messages ON public.messages;

CREATE TRIGGER driver_agent_on_messages
AFTER INSERT ON public.messages
FOR EACH ROW
EXECUTE FUNCTION public.notify_driver_agent_trigger();

COMMENT ON TRIGGER driver_agent_on_messages ON public.messages IS
  'Forwards chat message inserts to driver-agent for FCM delivery to the other participant.';
