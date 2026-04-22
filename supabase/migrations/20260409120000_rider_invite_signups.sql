-- Track successful rider→rider invite attribution (friend joined via your /i/{code} link).
-- fn_my_invited_friends_count: inviter's dashboard count.
-- fn_record_rider_invite_attribution: invitee calls once after auth (e.g. deep link /i/xxxxxxx).

CREATE TABLE IF NOT EXISTS public.rider_invite_signups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  inviter_rider_identity_id uuid NOT NULL REFERENCES public.rider_identities (id) ON DELETE CASCADE,
  invitee_rider_identity_id uuid NOT NULL REFERENCES public.rider_identities (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now (),
  CONSTRAINT rider_invite_signups_invitee_unique UNIQUE (invitee_rider_identity_id),
  CONSTRAINT rider_invite_signups_no_self CHECK (
    inviter_rider_identity_id IS DISTINCT FROM invitee_rider_identity_id
  )
);

CREATE INDEX IF NOT EXISTS idx_rider_invite_signups_inviter
  ON public.rider_invite_signups (inviter_rider_identity_id);

COMMENT ON TABLE public.rider_invite_signups IS
  'One row per rider identity that joined via another rider''s short invite code; used for TAF stats.';

ALTER TABLE public.rider_invite_signups ENABLE ROW LEVEL SECURITY;

-- Clients use SECURITY DEFINER RPCs only (no direct table policies).

CREATE OR REPLACE FUNCTION public.fn_my_invited_friends_count ()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_me uuid;
  n int;
BEGIN
  IF v_uid IS NULL THEN
    RETURN 0;
  END IF;

  SELECT ri.id
  INTO v_me
  FROM public.rider_identities ri
  WHERE ri.user_id = v_uid
  LIMIT 1;

  IF v_me IS NULL THEN
    RETURN 0;
  END IF;

  SELECT COUNT(*)::int
  INTO n
  FROM public.rider_invite_signups s
  WHERE s.inviter_rider_identity_id = v_me;

  RETURN COALESCE(n, 0);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_record_rider_invite_attribution (p_invite_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_invitee uuid;
  v_inviter uuid;
  v_code text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;

  IF p_invite_code IS NULL OR length(trim(p_invite_code)) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_code');
  END IF;

  v_code := trim(p_invite_code);
  IF v_code !~ '^[a-zA-Z0-9]{7}$' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_code');
  END IF;

  SELECT ri.id
  INTO v_invitee
  FROM public.rider_identities ri
  WHERE ri.user_id = v_uid
  LIMIT 1;

  IF v_invitee IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'identity_not_found');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.rider_invite_signups s
    WHERE s.invitee_rider_identity_id = v_invitee
  ) THEN
    RETURN jsonb_build_object('ok', true, 'skipped', true, 'reason', 'already_attributed');
  END IF;

  SELECT ic.rider_identity_id
  INTO v_inviter
  FROM public.invite_codes ic
  WHERE ic.code = v_code
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'unknown_code');
  END IF;

  IF v_inviter IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'skipped', true, 'reason', 'not_rider_code');
  END IF;

  IF v_inviter = v_invitee THEN
    RETURN jsonb_build_object('ok', true, 'skipped', true, 'reason', 'self_invite');
  END IF;

  INSERT INTO public.rider_invite_signups (inviter_rider_identity_id, invitee_rider_identity_id)
  VALUES (v_inviter, v_invitee);

  RETURN jsonb_build_object('ok', true, 'recorded', true);
EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', true, 'skipped', true, 'reason', 'duplicate');
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_my_invited_friends_count () TO authenticated;

GRANT EXECUTE ON FUNCTION public.fn_record_rider_invite_attribution (text) TO authenticated;
