-- NL rollout health report
-- Purpose: quick operational snapshot for province-based launch readiness.
--
-- Output fields:
-- - active_provinces
-- - active_city_counts_per_province
-- - launch_provinces_city_coverage
-- - missing_province_mappings_in_nl

with active_provinces as (
  select province_code
  from public.launch_regions
  where country_code = 'NL'
    and is_active = true
),
city_counts as (
  select
    c.province_code,
    count(*) filter (where c.is_active) as active_city_count,
    count(*) as total_city_count
  from public.cities c
  where c.country_code = 'NL'
  group by c.province_code
),
missing_mappings as (
  select count(*) as missing_province_count
  from public.cities
  where country_code = 'NL'
    and (province_code is null or trim(province_code) = '')
)
select jsonb_build_object(
  'active_provinces', (
    select jsonb_agg(ap.province_code order by ap.province_code)
    from active_provinces ap
  ),
  'active_city_counts_per_province', (
    select jsonb_agg(
      jsonb_build_object(
        'province_code', cc.province_code,
        'active_city_count', cc.active_city_count,
        'total_city_count', cc.total_city_count
      ) order by cc.province_code
    )
    from city_counts cc
  ),
  'launch_provinces_city_coverage', (
    select jsonb_agg(
      jsonb_build_object(
        'province_code', ap.province_code,
        'active_city_count', coalesce(cc.active_city_count, 0),
        'total_city_count', coalesce(cc.total_city_count, 0)
      ) order by ap.province_code
    )
    from active_provinces ap
    left join city_counts cc on cc.province_code = ap.province_code
  ),
  'missing_province_mappings_in_nl', (
    select missing_province_count
    from missing_mappings
  )
) as report;
