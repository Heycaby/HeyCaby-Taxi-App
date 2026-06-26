-- Add NL launch cities/areas wave 2 (dedupe-safe).
-- Expands operational coverage across active launch provinces.

with seed(name, slug, center_lat, center_lng, province_code) as (
  values
    ('Schiedam', 'schiedam', 51.9194, 4.3883, 'ZH'),
    ('Vlaardingen', 'vlaardingen', 51.9125, 4.3417, 'ZH'),
    ('Capelle aan den IJssel', 'capelle_aan_den_ijssel', 51.9292, 4.5778, 'ZH'),
    ('Maassluis', 'maassluis', 51.9233, 4.2500, 'ZH'),
    ('Barendrecht', 'barendrecht', 51.8567, 4.5347, 'ZH'),
    ('Delft', 'delft', 52.0116, 4.3571, 'ZH'),
    ('Leiden', 'leiden', 52.1601, 4.4970, 'ZH'),
    ('Haarlem', 'haarlem', 52.3874, 4.6462, 'NH'),
    ('Alkmaar', 'alkmaar', 52.6324, 4.7534, 'NH'),
    ('Zaanstad', 'zaanstad', 52.4385, 4.8260, 'NH'),
    ('Amstelveen', 'amstelveen', 52.3000, 4.8639, 'NH'),
    ('Hilversum', 'hilversum', 52.2292, 5.1669, 'NH'),
    ('Nieuwegein', 'nieuwegein', 52.0286, 5.0903, 'UT'),
    ('Zeist', 'zeist', 52.0907, 5.2336, 'UT'),
    ('Veenendaal', 'veenendaal', 52.0289, 5.5589, 'UT'),
    ('Den Bosch', 'den_bosch', 51.6978, 5.3037, 'NB'),
    ('Tilburg', 'tilburg', 51.5555, 5.0913, 'NB'),
    ('Helmond', 'helmond', 51.4817, 5.6611, 'NB'),
    ('Oss', 'oss', 51.7650, 5.5181, 'NB'),
    ('Enschede', 'enschede', 52.2215, 6.8937, 'OV'),
    ('Zwolle', 'zwolle', 52.5168, 6.0830, 'OV'),
    ('Deventer', 'deventer', 52.2550, 6.1639, 'OV'),
    ('Almelo', 'almelo', 52.3567, 6.6625, 'OV')
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

-- Ensure these launch wave cities remain active and province-mapped if they already existed.
update public.cities
set is_active = true,
    province_code = coalesce(province_code, 'ZH')
where country_code = 'NL'
  and lower(name) in (
    'schiedam', 'vlaardingen', 'capelle aan den ijssel', 'maassluis',
    'barendrecht', 'delft', 'leiden'
  );

update public.cities
set is_active = true,
    province_code = coalesce(province_code, 'NH')
where country_code = 'NL'
  and lower(name) in ('haarlem', 'alkmaar', 'zaanstad', 'amstelveen', 'hilversum');

update public.cities
set is_active = true,
    province_code = coalesce(province_code, 'UT')
where country_code = 'NL'
  and lower(name) in ('nieuwegein', 'zeist', 'veenendaal');

update public.cities
set is_active = true,
    province_code = coalesce(province_code, 'NB')
where country_code = 'NL'
  and lower(name) in ('den bosch', 'tilburg', 'helmond', 'oss');

update public.cities
set is_active = true,
    province_code = coalesce(province_code, 'OV')
where country_code = 'NL'
  and lower(name) in ('enschede', 'zwolle', 'deventer', 'almelo');

