-- Dynamic Grow Your City milestones: 1k → 2k → 5k → 10k → … → 1M monthly riders (NL).
-- Drivers capped at 10k; milestone progress uses monthly active riders from live Supabase data.

CREATE OR REPLACE FUNCTION public.fn_community_growth_milestones()
RETURNS bigint[]
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT ARRAY[
    1000::bigint, 2000, 5000, 10000,
    15000, 20000, 30000, 40000, 50000, 65000, 80000, 100000,
    130000, 170000, 220000, 280000, 350000, 450000, 550000, 700000, 850000, 1000000
  ];
$$;

CREATE OR REPLACE FUNCTION public.fn_community_growth_milestone_window(p_count bigint)
RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_milestones bigint[];
  v_prev bigint := 0;
  v_m bigint;
  v_count bigint := GREATEST(p_count, 0);
BEGIN
  v_milestones := public.fn_community_growth_milestones();

  FOREACH v_m IN ARRAY v_milestones LOOP
    IF v_count < v_m THEN
      RETURN jsonb_build_object(
        'previous_milestone', v_prev,
        'next_milestone', v_m,
        'remaining_to_milestone', v_m - v_count,
        'progress_fraction',
          CASE
            WHEN v_m > v_prev THEN LEAST(1.0, GREATEST(0.0, (v_count - v_prev)::numeric / (v_m - v_prev)::numeric))
            ELSE 1.0
          END,
        'final_goal_reached', false
      );
    END IF;
    v_prev := v_m;
  END LOOP;

  RETURN jsonb_build_object(
    'previous_milestone', 1000000,
    'next_milestone', 1000000,
    'remaining_to_milestone', 0,
    'progress_fraction', 1.0,
    'final_goal_reached', true
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_community_growth_stats(
  p_city_name text DEFAULT 'Netherlands'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_region_name text := COALESCE(NULLIF(trim(p_city_name), ''), 'Netherlands');
  v_cfg jsonb;
  v_review_email text;
  v_source text := 'live';
  v_driver_total int := 0;
  v_rider_total int := 0;
  v_monthly_drivers int := 0;
  v_monthly_riders int := 0;
  v_driver_cap constant int := 10000;
  v_rider_cap constant bigint := 1000000;
  v_milestone_window jsonb;
  v_achieved jsonb := '[]'::jsonb;
  v_achieved_arr bigint[];
  v_m bigint;
  v_newly_achieved bigint[] := ARRAY[]::bigint[];
  v_latest_achieved bigint := 0;
  v_just_reached bigint := NULL;
BEGIN
  SELECT value::jsonb
  INTO v_cfg
  FROM public.app_config
  WHERE key = 'community_growth'
  LIMIT 1;

  IF v_cfg IS NOT NULL AND (v_cfg->>'region_name') IS NOT NULL
     AND trim(v_cfg->>'region_name') <> '' THEN
    v_region_name := trim(v_cfg->>'region_name');
  ELSIF v_cfg IS NOT NULL AND (v_cfg->>'city_name') IS NOT NULL
     AND trim(v_cfg->>'city_name') <> '' THEN
    v_region_name := trim(v_cfg->>'city_name');
  END IF;

  SELECT NULLIF(trim(value), '')
  INTO v_review_email
  FROM public.app_config
  WHERE key = 'apple_review_email'
  LIMIT 1;

  v_review_email := COALESCE(v_review_email, 'review@heycaby.nl');

  SELECT COUNT(*)::int
  INTO v_driver_total
  FROM public.drivers d
  WHERE d.country_code = 'NL'
    AND lower(trim(coalesce(d.email, ''))) <> lower(v_review_email);

  SELECT COUNT(*)::int
  INTO v_rider_total
  FROM public.rider_identities ri
  WHERE coalesce(trim(ri.email), '') <> ''
     OR ri.user_id IS NOT NULL;

  SELECT COUNT(*)::int
  INTO v_monthly_drivers
  FROM public.drivers d
  WHERE d.country_code = 'NL'
    AND lower(trim(coalesce(d.email, ''))) <> lower(v_review_email)
    AND (
      d.last_active >= now() - interval '30 days'
      OR d.updated_at >= now() - interval '30 days'
      OR EXISTS (
        SELECT 1
        FROM public.driver_shift_sessions s
        WHERE s.driver_id = d.id
          AND s.shift_started_at >= now() - interval '30 days'
      )
    );

  SELECT COUNT(DISTINCT ri.id)::int
  INTO v_monthly_riders
  FROM public.rider_identities ri
  WHERE (coalesce(trim(ri.email), '') <> '' OR ri.user_id IS NOT NULL)
    AND (
      ri.updated_at >= now() - interval '30 days'
      OR ri.created_at >= now() - interval '30 days'
      OR EXISTS (
        SELECT 1
        FROM public.ride_requests rr
        WHERE rr.rider_identity_id = ri.id
          AND rr.created_at >= now() - interval '30 days'
      )
    );

  v_driver_total := LEAST(GREATEST(v_driver_total, 0), v_driver_cap);
  v_monthly_drivers := LEAST(GREATEST(v_monthly_drivers, 0), v_driver_cap);
  v_rider_total := LEAST(GREATEST(v_rider_total, 0), v_rider_cap::int);
  v_monthly_riders := LEAST(GREATEST(v_monthly_riders, 0), v_rider_cap::int);

  v_milestone_window := public.fn_community_growth_milestone_window(v_monthly_riders::bigint);

  IF v_cfg IS NOT NULL AND v_cfg ? 'achieved_milestones' THEN
    v_achieved := v_cfg->'achieved_milestones';
  END IF;

  SELECT COALESCE(array_agg(x ORDER BY x), ARRAY[]::bigint[])
  INTO v_achieved_arr
  FROM jsonb_array_elements_text(v_achieved) AS t(xtxt)
  CROSS JOIN LATERAL (SELECT xtxt::bigint AS x) s;

  FOREACH v_m IN ARRAY public.fn_community_growth_milestones() LOOP
    IF v_monthly_riders >= v_m
       AND NOT (v_m = ANY (COALESCE(v_achieved_arr, ARRAY[]::bigint[]))) THEN
      v_newly_achieved := array_append(v_newly_achieved, v_m);
    END IF;
  END LOOP;

  IF array_length(v_newly_achieved, 1) IS NOT NULL THEN
    FOREACH v_m IN ARRAY v_newly_achieved LOOP
      v_achieved := v_achieved || to_jsonb(v_m);
      IF v_latest_achieved IS NULL OR v_m > v_latest_achieved THEN
        v_latest_achieved := v_m;
      END IF;
    END LOOP;

    v_just_reached := v_latest_achieved;

    v_cfg := COALESCE(v_cfg, '{}'::jsonb) || jsonb_build_object(
      'region_name', v_region_name,
      'achieved_milestones', (
        SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val), '[]'::jsonb)
        FROM (
          SELECT jsonb_array_elements_text(
            COALESCE(v_cfg->'achieved_milestones', '[]'::jsonb) || v_achieved
          )::bigint AS val
        ) merged
      ),
      'last_achieved_at', now()
    );

    INSERT INTO public.app_config (key, value)
    VALUES ('community_growth', v_cfg::text)
    ON CONFLICT (key) DO UPDATE
    SET value = EXCLUDED.value;
  ELSE
    SELECT COALESCE(MAX(x), 0)
    INTO v_latest_achieved
    FROM unnest(COALESCE(v_achieved_arr, ARRAY[]::bigint[])) AS x;
  END IF;

  RETURN jsonb_build_object(
    'region_name', v_region_name,
    'city_name', v_region_name,
    'driver_count', v_driver_total,
    'rider_count', v_rider_total,
    'monthly_driver_count', v_monthly_drivers,
    'monthly_rider_count', v_monthly_riders,
    'driver_cap', v_driver_cap,
    'rider_cap', v_rider_cap,
    'milestone_metric', 'monthly_riders',
    'previous_milestone', (v_milestone_window->>'previous_milestone')::bigint,
    'next_milestone', (v_milestone_window->>'next_milestone')::bigint,
    'remaining_to_milestone', (v_milestone_window->>'remaining_to_milestone')::bigint,
    'progress_fraction', (v_milestone_window->>'progress_fraction')::numeric,
    'final_goal_reached', COALESCE((v_milestone_window->>'final_goal_reached')::boolean, false),
    'achieved_milestones', COALESCE(
      (
        SELECT jsonb_agg(DISTINCT val ORDER BY val)
        FROM (
          SELECT jsonb_array_elements_text(
            COALESCE(v_achieved, '[]'::jsonb)
          )::bigint AS val
        ) s
      ),
      '[]'::jsonb
    ),
    'latest_achieved_milestone', v_latest_achieved,
    'milestone_just_reached', v_just_reached,
    'source', v_source,
    'updated_at', now()
  );
END;
$$;

COMMENT ON FUNCTION public.fn_community_growth_stats(text) IS
  'Live NL Grow Your City stats with dynamic rider milestones (1k…1M monthly active riders). Drivers capped at 10k.';

GRANT EXECUTE ON FUNCTION public.fn_community_growth_milestones() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_community_growth_milestone_window(bigint) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_community_growth_stats(text) TO anon, authenticated;
