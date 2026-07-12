ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS cancellation_rating_notified_at timestamptz;

-- Preserve the latest rider-rating implementation and widen only the status
-- guard so both people can review a cancelled, already-accepted journey.
DO $$
DECLARE
  v_definition text;
BEGIN
  SELECT pg_get_functiondef(
    'public.fn_rider_rate_driver(uuid,smallint,text,text)'::regprocedure
  ) INTO v_definition;
  IF position('rr.status = ''completed''' IN v_definition) > 0 THEN
    v_definition := replace(
      v_definition,
      'rr.status = ''completed''',
      'rr.status IN (''completed'', ''cancelled'')'
    );
    EXECUTE v_definition;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.trg_notify_cancelled_ride_rating()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'cancelled'
     AND NEW.cancelled_by = 'driver'
     AND NEW.driver_cancel_reason_code IS NOT NULL
     AND NEW.cancellation_rating_notified_at IS NULL THEN
    UPDATE public.ride_requests
    SET cancellation_rating_notified_at = timezone('utc', now())
    WHERE id = NEW.id AND cancellation_rating_notified_at IS NULL;

    PERFORM public.fn_ride_notify_rider(
      NEW.id,
      'rating',
      'How was the experience?',
      'This ride ended early. Your private feedback helps keep HeyCaby fair and safe.',
      jsonb_build_object(
        'type', 'rating',
        'ride_request_id', NEW.id,
        'cancelled_ride', true
      ),
      'high'
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_cancelled_ride_rating ON public.ride_requests;
CREATE TRIGGER trg_cancelled_ride_rating
AFTER UPDATE OF driver_cancel_reason_code ON public.ride_requests
FOR EACH ROW
EXECUTE FUNCTION public.trg_notify_cancelled_ride_rating();

REVOKE ALL ON FUNCTION public.trg_notify_cancelled_ride_rating()
  FROM PUBLIC, anon, authenticated;
