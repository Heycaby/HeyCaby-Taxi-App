create or replace function public.fn_driver_create_manual_ride(
  p_pickup_address text,
  p_dropoff_address text,
  p_fare_cents integer,
  p_currency text default 'EUR',
  p_payment_method text default 'cash',
  p_passenger_name text default null,
  p_pickup_lat double precision default null,
  p_pickup_lng double precision default null,
  p_dropoff_lat double precision default null,
  p_dropoff_lng double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_country_code text := 'NL';
  v_ride_id uuid;
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error', 'not_authenticated');
  end if;

  if p_dropoff_address is null or btrim(p_dropoff_address) = '' then
    return jsonb_build_object('success', false, 'error', 'dropoff_required');
  end if;

  if p_fare_cents is null or p_fare_cents <= 0 then
    return jsonb_build_object('success', false, 'error', 'fare_invalid');
  end if;

  if p_payment_method not in ('cash', 'card', 'tikkie') then
    return jsonb_build_object('success', false, 'error', 'payment_method_invalid');
  end if;

  select coalesce(nullif(d.country_code, ''), 'NL')
    into v_country_code
  from public.drivers d
  where d.id = v_uid
  limit 1;

  insert into public.ride_requests (
    driver_id,
    status,
    country_code,
    currency,
    pickup_address,
    destination_address,
    manual_entry,
    manual_passenger_name,
    manual_fare_cents,
    manual_payment_method,
    payment_method,
    driver_earnings_cents,
    platform_fee_cents,
    pickup_location,
    destination_location
  )
  values (
    v_uid,
    'completed',
    v_country_code,
    coalesce(nullif(p_currency, ''), 'EUR'),
    nullif(p_pickup_address, ''),
    p_dropoff_address,
    true,
    nullif(p_passenger_name, ''),
    p_fare_cents,
    p_payment_method,
    p_payment_method,
    p_fare_cents,
    0,
    case
      when p_pickup_lat is not null and p_pickup_lng is not null
      then format('POINT(%s %s)', p_pickup_lng, p_pickup_lat)::public.geometry
      else null
    end,
    case
      when p_dropoff_lat is not null and p_dropoff_lng is not null
      then format('POINT(%s %s)', p_dropoff_lng, p_dropoff_lat)::public.geometry
      else null
    end
  )
  returning id into v_ride_id;

  return jsonb_build_object(
    'success', true,
    'ride_id', v_ride_id,
    'message', 'Ride recorded successfully'
  );
exception
  when others then
    return jsonb_build_object('success', false, 'error', sqlerrm);
end;
$$;

revoke all on function public.fn_driver_create_manual_ride(
  text, text, integer, text, text, text, double precision, double precision, double precision, double precision
) from public;
grant execute on function public.fn_driver_create_manual_ride(
  text, text, integer, text, text, text, double precision, double precision, double precision, double precision
) to authenticated;
