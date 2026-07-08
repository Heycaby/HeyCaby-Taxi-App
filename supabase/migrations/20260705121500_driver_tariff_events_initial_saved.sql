-- Allow initial_tariff_saved audit events from fn_driver_save_initial_tariff.

ALTER TABLE public.driver_tariff_events
  DROP CONSTRAINT IF EXISTS driver_tariff_events_event_type_check;

ALTER TABLE public.driver_tariff_events
  ADD CONSTRAINT driver_tariff_events_event_type_check
  CHECK (event_type IN ('switch_profile', 'rate_edit', 'initial_tariff_saved'));
