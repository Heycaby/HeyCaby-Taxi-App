-- Phase E: fleet allowlist management RPCs for Secure Shift Handover.

CREATE OR REPLACE FUNCTION public.fn_driver_fleet_handover_vehicles()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_staff boolean;
BEGIN
  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  v_staff := public.fn_shift_handover_staff_is_authorized();

  IF v_driver_id IS NULL AND NOT v_staff THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'items', coalesce((
      SELECT jsonb_agg(row_to_json(t)::jsonb ORDER BY t.plate_display ASC)
      FROM (
        SELECT
          tv.id AS vehicle_id,
          tv.plate_normalized,
          coalesce(nullif(trim(tv.plate_display), ''), tv.plate_normalized) AS plate_display,
          tv.ownership_type,
          (
            SELECT count(*)::int
            FROM public.taxi_vehicle_driver_allowlist av
            WHERE av.vehicle_id = tv.id
          ) AS allowlist_count
        FROM public.taxi_vehicles tv
        WHERE tv.ownership_type = 'shared_fleet'
          AND (
            v_staff
            OR tv.fleet_owner_driver_id = v_driver_id
            OR tv.owner_driver_id = v_driver_id
          )
        ORDER BY plate_display ASC
        LIMIT 100
      ) t
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_fleet_handover_driver_search(
  p_vehicle_id uuid,
  p_query text
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_query text;
BEGIN
  IF NOT public.fn_shift_handover_fleet_can_manage_vehicle(p_vehicle_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'forbidden');
  END IF;

  v_query := lower(trim(coalesce(p_query, '')));
  IF length(v_query) < 3 THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'query_too_short',
      'message', 'Typ minimaal 3 tekens om te zoeken.'
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'items', coalesce((
      SELECT jsonb_agg(row_to_json(s)::jsonb ORDER BY s.display_name ASC)
      FROM (
        SELECT
          d.id AS driver_id,
          coalesce(
            nullif(trim(d.full_name), ''),
            nullif(trim(d.veriff_full_name), ''),
            'Chauffeur'
          ) AS display_name,
          d.email,
          d.profile_photo_url
        FROM public.drivers d
        WHERE (
          COALESCE(d.veriff_status, '') IN ('approved', 'verified')
          OR COALESCE(d.rijbewijs_verified, false)
        )
        AND (
          lower(coalesce(d.email, '')) = v_query
          OR lower(coalesce(d.email, '')) LIKE v_query || '%'
          OR lower(coalesce(d.full_name, '')) LIKE '%' || v_query || '%'
          OR lower(coalesce(d.veriff_full_name, '')) LIKE '%' || v_query || '%'
        )
        ORDER BY d.full_name ASC NULLS LAST
        LIMIT 15
      ) s
    ), '[]'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_fleet_handover_vehicles() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_fleet_handover_vehicles() TO authenticated;

REVOKE ALL ON FUNCTION public.fn_driver_fleet_handover_driver_search(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_fleet_handover_driver_search(uuid, text) TO authenticated;
