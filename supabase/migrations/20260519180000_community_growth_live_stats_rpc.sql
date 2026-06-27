-- Live community growth stats for Grow Your City (both apps).
-- Returns real platform counts for Rotterdam/Nl; optional App Store Connect totals
-- in app_config.community_growth (app_store_driver_downloads / app_store_rider_downloads).

CREATE OR REPLACE FUNCTION public.fn_community_growth_stats(
  p_city_name text DEFAULT 'Rotterdam'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_city_name text := COALESCE(NULLIF(trim(p_city_name), ''), 'Rotterdam');
  v_goal int := 10000;
  v_cfg jsonb;
  v_driver_count int := 0;
  v_rider_count int := 0;
  v_review_email text;
  v_source text := 'live';
BEGIN
  SELECT value::jsonb
  INTO v_cfg
  FROM public.app_config
  WHERE key = 'community_growth'
  LIMIT 1;

  IF v_cfg IS NOT NULL THEN
    IF v_cfg ? 'member_goal' THEN
      v_goal := GREATEST(1, (v_cfg->>'member_goal')::int);
    ELSIF v_cfg ? 'goal' THEN
      v_goal := GREATEST(1, (v_cfg->>'goal')::int);
    END IF;

    IF (v_cfg->>'city_name') IS NOT NULL AND trim(v_cfg->>'city_name') <> '' THEN
      v_city_name := trim(v_cfg->>'city_name');
    END IF;
  END IF;

  IF v_cfg ? 'app_store_driver_downloads'
     AND v_cfg ? 'app_store_rider_downloads'
     AND (v_cfg->>'app_store_driver_downloads') ~ '^[0-9]+$'
     AND (v_cfg->>'app_store_rider_downloads') ~ '^[0-9]+$' THEN
    v_driver_count := (v_cfg->>'app_store_driver_downloads')::int;
    v_rider_count := (v_cfg->>'app_store_rider_downloads')::int;
    v_source := 'app_store_connect';
  ELSE
    SELECT NULLIF(trim(value), '')
    INTO v_review_email
    FROM public.app_config
    WHERE key = 'apple_review_email'
    LIMIT 1;

    v_review_email := COALESCE(v_review_email, 'review@heycaby.nl');

    SELECT COUNT(*)::int
    INTO v_driver_count
    FROM public.drivers d
    WHERE d.country_code = 'NL'
      AND lower(trim(coalesce(d.email, ''))) <> lower(v_review_email)
      AND (
        lower(trim(coalesce(d.home_city, ''))) = lower(v_city_name)
        OR v_city_name = ANY (coalesce(d.service_cities, ARRAY[]::text[]))
        OR (
          coalesce(d.home_city, '') = ''
          AND coalesce(array_length(d.service_cities, 1), 0) = 0
        )
      );

    SELECT COUNT(*)::int
    INTO v_rider_count
    FROM public.rider_identities ri
    WHERE coalesce(trim(ri.email), '') <> ''
       OR ri.user_id IS NOT NULL;

    SELECT GREATEST(
      v_driver_count,
      COALESCE((
        SELECT COUNT(DISTINCT pd.auth_user_id)::int
        FROM public.push_devices pd
        WHERE pd.app_role = 'driver'
          AND pd.platform = 'ios'
      ), 0)
    )
    INTO v_driver_count;

    SELECT GREATEST(
      v_rider_count,
      COALESCE((
        SELECT COUNT(DISTINCT pd.auth_user_id)::int
        FROM public.push_devices pd
        WHERE pd.app_role = 'rider'
          AND pd.platform = 'ios'
      ), 0)
    )
    INTO v_rider_count;

    v_source := 'live';
  END IF;

  RETURN jsonb_build_object(
    'city_name', v_city_name,
    'driver_count', GREATEST(v_driver_count, 0),
    'rider_count', GREATEST(v_rider_count, 0),
    'member_goal', v_goal,
    'source', v_source,
    'updated_at', now()
  );
END;
$$;

COMMENT ON FUNCTION public.fn_community_growth_stats(text) IS
  'Grow Your City transparency stats. Prefers App Store Connect totals in app_config.community_growth when set; otherwise live NL/Rotterdam platform + iOS install counts.';

GRANT EXECUTE ON FUNCTION public.fn_community_growth_stats(text) TO anon, authenticated;
