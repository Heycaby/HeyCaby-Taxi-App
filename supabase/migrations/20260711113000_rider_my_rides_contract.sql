-- Authenticated rider-owned ride list for Upcoming and History surfaces.
-- Ownership follows ride lifecycle access while excluding the driver's
-- marketplace visibility branch from the rider's personal ride list.

create or replace function public.fn_rider_my_rides(
  p_scope text default 'all',
  p_limit integer default 100,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_scope text := lower(btrim(coalesce(p_scope, 'all')));
  v_limit integer := least(greatest(coalesce(p_limit, 100), 1), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_total bigint := 0;
  v_items jsonb := '[]'::jsonb;
  v_identity_ids uuid[] := '{}'::uuid[];
  v_session_tokens text[] := '{}'::text[];
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'not_authenticated');
  end if;

  if v_scope not in ('all', 'upcoming', 'history') then
    return jsonb_build_object('ok', false, 'error', 'invalid_scope');
  end if;

  select coalesce(array_agg(distinct ri.id), '{}'::uuid[])
  into v_identity_ids
  from public.rider_identities ri
  left join auth.users au on au.id = v_uid
  where ri.user_id = v_uid
    or (
      nullif(btrim(ri.email), '') is not null
      and lower(btrim(ri.email)) = lower(btrim(au.email::text))
    )
    or exists (
      select 1
      from public.push_devices pd
      where pd.auth_user_id = v_uid
        and pd.app_role = 'rider'
        and pd.rider_identity_id = ri.id
    );

  select coalesce(array_agg(rs.session_token), '{}'::text[])
  into v_session_tokens
  from public.rider_sessions rs
  where rs.user_id = v_uid;

  with owned as (
    select rr.*
    from public.ride_requests rr
    where rr.rider_identity_id = any(v_identity_ids)
       or rr.rider_token = any(v_session_tokens)
  ), filtered as (
    select o.*
    from owned o
    where
      v_scope = 'all'
      or (
        v_scope = 'upcoming'
        and o.status = any (array[
          'pending', 'bidding', 'assigned', 'accepted', 'driver_found',
          'driver_en_route', 'driver_arrived', 'in_progress'
        ]::text[])
      )
      or (
        v_scope = 'history'
        and o.status = any (array[
          'completed', 'cancelled', 'expired', 'no_driver', 'declined'
        ]::text[])
      )
  )
  select count(*) into v_total from filtered;

  with owned as (
    select rr.*
    from public.ride_requests rr
    where rr.rider_identity_id = any(v_identity_ids)
       or rr.rider_token = any(v_session_tokens)
  ), filtered as (
    select o.*
    from owned o
    where
      v_scope = 'all'
      or (
        v_scope = 'upcoming'
        and o.status = any (array[
          'pending', 'bidding', 'assigned', 'accepted', 'driver_found',
          'driver_en_route', 'driver_arrived', 'in_progress'
        ]::text[])
      )
      or (
        v_scope = 'history'
        and o.status = any (array[
          'completed', 'cancelled', 'expired', 'no_driver', 'declined'
        ]::text[])
      )
  ), page as (
    select f.*
    from filtered f
    order by
      case
        when v_scope = 'upcoming'
          and f.scheduled_pickup_at is not null
          and f.scheduled_pickup_at > now()
        then 0
        when v_scope = 'upcoming' then 1
        else 2
      end,
      case
        when v_scope = 'upcoming'
          and f.scheduled_pickup_at is not null
          and f.scheduled_pickup_at > now()
        then f.scheduled_pickup_at
      end asc nulls last,
      f.created_at desc
    limit v_limit offset v_offset
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', p.id,
        'status', p.status,
        'booking_mode', p.booking_mode::text,
        'pickup_address', p.pickup_address,
        'destination_address', p.destination_address,
        'scheduled_pickup_at', p.scheduled_pickup_at,
        'final_fare', p.final_fare,
        'quoted_fare', p.quoted_fare,
        'offered_fare', p.offered_fare,
        'marketplace_offered_fare', p.marketplace_offered_fare,
        'estimated_fare', p.estimated_fare,
        'waiting_fee_cents', p.waiting_fee_cents,
        'waiting_fee_waived', p.waiting_fee_waived,
        'created_at', p.created_at,
        'completed_at', p.completed_at,
        'driver', case
          when d.id is null then null
          else jsonb_build_object(
            'full_name', d.full_name,
            'profile_photo_url', d.profile_photo_url
          )
        end
      )
      order by
        case
          when v_scope = 'upcoming'
            and p.scheduled_pickup_at is not null
            and p.scheduled_pickup_at > now()
          then 0
          when v_scope = 'upcoming' then 1
          else 2
        end,
        case
          when v_scope = 'upcoming'
            and p.scheduled_pickup_at is not null
            and p.scheduled_pickup_at > now()
          then p.scheduled_pickup_at
        end asc nulls last,
        p.created_at desc
    ),
    '[]'::jsonb
  )
  into v_items
  from page p
  left join public.drivers d on d.id = p.driver_id;

  return jsonb_build_object(
    'ok', true,
    'items', v_items,
    'total', v_total,
    'limit', v_limit,
    'offset', v_offset,
    'has_more', (v_offset + jsonb_array_length(v_items)) < v_total
  );
end;
$$;

revoke all on function public.fn_rider_my_rides(text, integer, integer) from public;
revoke all on function public.fn_rider_my_rides(text, integer, integer) from anon;
grant execute on function public.fn_rider_my_rides(text, integer, integer) to authenticated;
