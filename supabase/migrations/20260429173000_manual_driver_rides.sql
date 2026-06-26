-- Manual "street pickup" rides recorded by drivers for bookkeeping.
-- Backend stays authoritative for policy (commission = 0).

alter table public.ride_requests
  add column if not exists manual_entry boolean not null default false,
  add column if not exists manual_passenger_name text,
  add column if not exists manual_fare_cents integer,
  add column if not exists manual_payment_method text,
  add column if not exists platform_fee_cents integer;

comment on column public.ride_requests.manual_entry is
  'True when ride is manually recorded by a driver (street pickup).';
comment on column public.ride_requests.manual_fare_cents is
  'Fare entered by the driver for manual rides, in cents.';
comment on column public.ride_requests.platform_fee_cents is
  'Platform fee for this ride in cents. Manual rides currently use 0.';
