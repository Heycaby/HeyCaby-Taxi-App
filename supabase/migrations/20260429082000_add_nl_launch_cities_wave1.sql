-- Add NL launch cities/areas for province-based rollout (dedupe-safe).
-- Keeps existing rows and updates launch metadata where city already exists.

with seed(name, slug, center_lat, center_lng, province_code) as (
  values
    ('Dordrecht', 'dordrecht', 51.8133, 4.6901, 'ZH'),
    ('Eindhoven', 'eindhoven', 51.4416, 5.4697, 'NB'),
    ('Amersfoort', 'amersfoort', 52.1561, 5.3878, 'UT'),
    ('Hengelo', 'hengelo', 52.2658, 6.7931, 'OV'),
    ('Breda', 'breda', 51.5719, 4.7683, 'NB'),
    ('Spijkenisse', 'spijkenisse', 51.8450, 4.3292, 'ZH'),
    ('Rozenburg', 'rozenburg', 51.9058, 4.2486, 'ZH'),
    ('Brielle', 'brielle', 51.9008, 4.1625, 'ZH'),
    ('Hoek van Holland', 'hoek_van_holland', 51.9777, 4.1333, 'ZH'),
    ('Europoort', 'europoort', 51.9470, 4.1370, 'ZH')
)
insert into public.cities (
  name,
  slug,
  center_lat,
  center_lng,
  country_code,
  timezone,
  currency,
  province_code,
  is_active
)
select
  s.name,
  s.slug,
  s.center_lat,
  s.center_lng,
  'NL',
  'Europe/Amsterdam',
  'EUR',
  s.province_code,
  true
from seed s
where not exists (
  select 1
  from public.cities c
  where lower(c.name) = lower(s.name)
     or lower(c.slug) = lower(s.slug)
);

-- Ensure existing target launch cities are active and province-mapped.
update public.cities
set is_active = true,
    province_code = coalesce(province_code, 'ZH')
where country_code = 'NL'
  and lower(name) in ('den haag', 'dordrecht', 'spijkenisse', 'rozenburg', 'brielle', 'hoek van holland', 'europoort');

update public.cities
set is_active = true,
    province_code = coalesce(province_code, 'NB')
where country_code = 'NL'
  and lower(name) in ('eindhoven', 'breda');

update public.cities
set is_active = true,
    province_code = coalesce(province_code, 'UT')
where country_code = 'NL'
  and lower(name) in ('amersfoort', 'utrecht');

update public.cities
set is_active = true,
    province_code = coalesce(province_code, 'OV')
where country_code = 'NL'
  and lower(name) in ('hengelo');

