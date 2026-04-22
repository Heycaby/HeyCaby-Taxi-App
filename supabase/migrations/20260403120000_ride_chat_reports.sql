-- Ride chat: report participant (App Store UGC — moderation queue).
-- Apply with: supabase db push / SQL Editor.

CREATE TABLE IF NOT EXISTS public.ride_chat_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  ride_id uuid NOT NULL,
  reporter_id text NOT NULL,
  reporter_type text NOT NULL CHECK (reporter_type IN ('rider', 'driver')),
  reported_id text NOT NULL,
  reported_type text NOT NULL CHECK (reported_type IN ('rider', 'driver')),
  reason text
);

ALTER TABLE public.ride_chat_reports ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.fn_ride_chat_report_participant(
  p_ride_id uuid,
  p_reporter_id text,
  p_reporter_type text,
  p_reported_id text,
  p_reported_type text,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_ride_id IS NULL
     OR p_reporter_id IS NULL OR length(trim(p_reporter_id)) = 0
     OR p_reported_id IS NULL OR length(trim(p_reported_id)) = 0
  THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_params');
  END IF;

  IF p_reporter_type NOT IN ('rider', 'driver') OR p_reported_type NOT IN ('rider', 'driver') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_role');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.messages m
    WHERE m.ride_request_id = p_ride_id
      AND m.sender_id::text = trim(p_reporter_id)
      AND m.sender_type = p_reporter_type
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'reporter_not_in_ride');
  END IF;

  INSERT INTO public.ride_chat_reports (
    ride_id, reporter_id, reporter_type, reported_id, reported_type, reason
  )
  VALUES (
    p_ride_id,
    trim(p_reporter_id),
    p_reporter_type,
    trim(p_reported_id),
    p_reported_type,
    CASE
      WHEN p_reason IS NULL THEN NULL
      WHEN length(trim(p_reason)) = 0 THEN NULL
      ELSE left(trim(p_reason), 2000)
    END
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_ride_chat_report_participant(uuid, text, text, text, text, text) TO anon, authenticated;
