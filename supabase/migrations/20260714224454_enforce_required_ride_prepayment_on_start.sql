-- Required ride prepayment is enforced at the authoritative transition into
-- `in_progress`. Flutter can request checkout, but cannot bypass this guard or
-- assert that a payment succeeded.
create or replace function private.fn_ride_prepayment_start_decision(
  p_ride_id uuid,
  p_booking_mode text,
  p_ride_payment_status text
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_flags jsonb := '{}'::jsonb;
  v_required boolean := false;
  v_payment public.ride_payments%rowtype;
begin
  if p_booking_mode not in ('scheduled', 'terug') then
    return jsonb_build_object(
      'allowed', true,
      'required', false,
      'reason', 'mode_not_required'
    );
  end if;

  begin
    select coalesce(nullif(ac.value, '')::jsonb, '{}'::jsonb)
    into v_flags
    from public.app_config ac
    where ac.key = 'feature_flags';
  exception
    when others then
      return jsonb_build_object(
        'allowed', false,
        'required', true,
        'reason', 'ride_prepayment_config_invalid'
      );
  end;

  v_required := coalesce(
    v_flags -> 'ride_prepaid_payments_enabled' = 'true'::jsonb,
    false
  ) and case p_booking_mode
    when 'scheduled' then coalesce(
      v_flags -> 'ride_prepaid_scheduled_enabled' = 'true'::jsonb,
      false
    )
    when 'terug' then coalesce(
      v_flags -> 'ride_prepaid_taxi_terug_enabled' = 'true'::jsonb,
      false
    )
    else false
  end;

  if not v_required then
    return jsonb_build_object(
      'allowed', true,
      'required', false,
      'reason', 'flag_disabled'
    );
  end if;

  select rp.* into v_payment
  from public.ride_payments rp
  where rp.ride_id = p_ride_id
  order by rp.created_at desc
  limit 1;

  if v_payment.id is null
     or v_payment.state <> 'paid'
     or v_payment.paid_at is null
     or coalesce(v_payment.refunded_cents, 0) <> 0
     or coalesce(p_ride_payment_status, '') not in ('confirmed', 'paid') then
    return jsonb_build_object(
      'allowed', false,
      'required', true,
      'reason', 'ride_prepayment_required',
      'payment_id', v_payment.id,
      'payment_state', coalesce(v_payment.state, 'missing'),
      'ride_payment_status', p_ride_payment_status,
      'refunded_cents', coalesce(v_payment.refunded_cents, 0)
    );
  end if;

  return jsonb_build_object(
    'allowed', true,
    'required', true,
    'reason', 'paid',
    'payment_id', v_payment.id,
    'payment_state', v_payment.state
  );
end;
$$;

revoke all on function private.fn_ride_prepayment_start_decision(
  uuid, text, text
) from public, anon, authenticated;
grant execute on function private.fn_ride_prepayment_start_decision(
  uuid, text, text
) to service_role;

create or replace function public.fn_driver_ride_start(p_ride_request_id uuid)
returns json
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_driver_id uuid;
  v_updated int;
  v_ride public.ride_requests%rowtype;
  v_max_m numeric;
  v_dist_m numeric;
  v_wait_secs int;
  v_fee_cents int;
  v_prepay jsonb := '{}'::jsonb;
  v_requires_prepay boolean := false;
  v_payment_id uuid;
begin
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  if v_driver_id is null then
    return json_build_object('ok', false, 'error', 'not_a_driver');
  end if;

  select * into v_ride
  from public.ride_requests rr
  where rr.id = p_ride_request_id
  for update;

  if not found or v_ride.driver_id is distinct from v_driver_id
     or v_ride.status <> 'driver_arrived' then
    return json_build_object('ok', false, 'error', 'invalid_transition');
  end if;

  v_prepay := private.fn_ride_prepayment_start_decision(
    p_ride_request_id,
    v_ride.booking_mode::text,
    v_ride.payment_status
  );
  v_requires_prepay := coalesce((v_prepay ->> 'required')::boolean, false);
  v_payment_id := nullif(v_prepay ->> 'payment_id', '')::uuid;

  if coalesce((v_prepay ->> 'allowed')::boolean, false) is not true then
    perform public.fn_ride_audit_append(
      p_ride_request_id,
      case v_prepay ->> 'reason'
        when 'ride_prepayment_config_invalid'
          then 'trip.start_blocked_prepayment_config'
        else 'trip.start_blocked_prepayment'
      end,
      v_driver_id,
      jsonb_build_object('booking_mode', v_ride.booking_mode::text)
        || v_prepay,
      'driver', 'rpc', p_ride_request_id
    );
    return json_build_object(
      'ok', false,
      'error', coalesce(
        v_prepay ->> 'reason',
        'ride_prepayment_required'
      ),
      'booking_mode', v_ride.booking_mode::text,
      'payment_state', coalesce(v_prepay ->> 'payment_state', 'missing')
    );
  end if;

  -- Proximity guard (default 200 m), enforced when verifiable.
  v_max_m := coalesce(
    nullif(public.fn_app_config_text('start_max_distance_m'), '')::numeric,
    200
  );
  select st_distance(
           st_setsrid(st_makepoint(dl.longitude, dl.latitude), 4326)::geography,
           v_ride.pickup_coords
         )
  into v_dist_m
  from public.driver_locations dl
  where dl.driver_id = v_driver_id
    and dl.updated_at > now() - interval '3 minutes'
    and dl.latitude is not null
    and dl.longitude is not null
    and v_ride.pickup_coords is not null
  limit 1;

  if v_dist_m is not null and v_dist_m > v_max_m then
    perform public.fn_ride_audit_append(
      p_ride_request_id, 'trip.start_blocked_distance', v_driver_id,
      jsonb_build_object('distance_m', round(v_dist_m), 'max_m', v_max_m),
      'driver', 'rpc', p_ride_request_id
    );
    return json_build_object(
      'ok', false, 'error', 'too_far_from_pickup',
      'distance_m', round(v_dist_m), 'max_m', v_max_m
    );
  end if;

  -- Freeze waiting values at boarding.
  v_wait_secs := greatest(
    0,
    coalesce(
      extract(epoch from (
        timezone('utc', now()) - v_ride.driver_arrived_at
      ))::int,
      0
    ) - coalesce(v_ride.waiting_grace_seconds, 120)
  );
  if coalesce(v_ride.waiting_fee_waived, false) then
    v_fee_cents := 0;
  else
    v_fee_cents := round(
      (v_wait_secs / 60.0)
      * coalesce(v_ride.waiting_rate_per_minute, 0)
      * 100
    )::int;
  end if;

  update public.ride_requests rr
  set status = 'in_progress',
      started_at = timezone('utc', now()),
      chargeable_wait_seconds = v_wait_secs,
      waiting_fee_cents = v_fee_cents,
      updated_at = timezone('utc', now())
  where rr.id = p_ride_request_id;

  get diagnostics v_updated = row_count;
  if v_updated = 0 then
    return json_build_object('ok', false, 'error', 'invalid_transition');
  end if;

  perform public.fn_driver_ride_lifecycle_mark_on_ride(v_driver_id);
  perform public.fn_driver_ride_lifecycle_audit(
    p_ride_request_id, 'trip.started', v_driver_id,
    jsonb_build_object(
      'status', 'in_progress',
      'chargeable_wait_seconds', v_wait_secs,
      'waiting_fee_cents', v_fee_cents,
      'waiting_fee_waived', coalesce(v_ride.waiting_fee_waived, false),
      'prepayment_required', v_requires_prepay,
      'ride_payment_id', v_payment_id
    )
  );

  perform public.fn_ride_notify_rider(
    p_ride_request_id,
    'ride_started',
    'Your trip has started',
    'Enjoy your ride.',
    jsonb_build_object('type', 'ride_started'),
    'high'
  );

  return json_build_object(
    'ok', true,
    'status', 'in_progress',
    'ride_id', p_ride_request_id,
    'chargeable_wait_seconds', v_wait_secs,
    'waiting_fee_cents', v_fee_cents
  );
end;
$$;

revoke all on function public.fn_driver_ride_start(uuid) from public, anon;
grant execute on function public.fn_driver_ride_start(uuid)
  to authenticated, service_role;

comment on function public.fn_driver_ride_start(uuid) is
  'Canonical Driver ride-start command. Enforces webhook-confirmed prepayment for enabled scheduled and Taxi Terug modes before transitioning to in_progress.';
