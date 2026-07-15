-- A Flutter release build can still be development-provisioned on a connected
-- iPhone. Preserve the APNs environment that Apple already proved for an
-- unchanged token instead of overwriting it from client build-mode guesses.
create or replace function public.fn_register_push_device(
  p_fcm_token text,
  p_platform text,
  p_app_role text,
  p_rider_identity_id uuid default null,
  p_apns_token text default null,
  p_apns_environment text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_driver_id uuid;
  v_auth_email text;
  v_apns_token text;
  v_apns_environment text;
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error', 'not_authenticated');
  end if;
  if p_fcm_token is null or length(trim(p_fcm_token)) < 10 then
    return jsonb_build_object('success', false, 'error', 'invalid_token');
  end if;
  if p_platform not in ('ios', 'android') then
    return jsonb_build_object('success', false, 'error', 'invalid_platform');
  end if;
  if p_app_role not in ('rider', 'driver') then
    return jsonb_build_object('success', false, 'error', 'invalid_app_role');
  end if;
  if p_apns_environment is not null
     and p_apns_environment not in ('sandbox', 'production') then
    return jsonb_build_object('success', false, 'error', 'invalid_apns_environment');
  end if;

  if p_platform = 'ios' and p_apns_token is not null
     and p_apns_token ~ '^[0-9A-Fa-f]{64}$' then
    v_apns_token := lower(p_apns_token);
    v_apns_environment := p_apns_environment;
  end if;

  if p_app_role = 'driver' then
    select id into v_driver_id from public.drivers where user_id = v_uid limit 1;
    if v_driver_id is null then
      return jsonb_build_object('success', false, 'error', 'driver_not_found');
    end if;
    insert into public.push_devices as existing (
      fcm_token, platform, app_role, driver_id, auth_user_id,
      apns_token, apns_environment
    ) values (
      trim(p_fcm_token), p_platform, 'driver', v_driver_id, v_uid,
      v_apns_token, v_apns_environment
    )
    on conflict (fcm_token) do update set
      driver_id = excluded.driver_id,
      auth_user_id = excluded.auth_user_id,
      platform = excluded.platform,
      app_role = 'driver',
      rider_identity_id = null,
      apns_environment = case
        when existing.apns_token = excluded.apns_token
          and existing.apns_environment is not null
          then existing.apns_environment
        else excluded.apns_environment
      end,
      apns_token = excluded.apns_token,
      updated_at = now();
    return jsonb_build_object('success', true);
  end if;

  if p_rider_identity_id is null then
    return jsonb_build_object('success', false, 'error', 'rider_identity_required');
  end if;
  select u.email into v_auth_email from auth.users u where u.id = v_uid limit 1;
  if not exists (
    select 1 from public.rider_identities ri
    where ri.id = p_rider_identity_id
      and (
        ri.user_id = v_uid
        or (
          ri.user_id is null and v_auth_email is not null and ri.email is not null
          and lower(trim(ri.email)) = lower(trim(v_auth_email))
        )
      )
  ) then
    return jsonb_build_object('success', false, 'error', 'identity_mismatch');
  end if;

  insert into public.push_devices as existing (
    fcm_token, platform, app_role, rider_identity_id, auth_user_id,
    apns_token, apns_environment
  ) values (
    trim(p_fcm_token), p_platform, 'rider', p_rider_identity_id, v_uid,
    v_apns_token, v_apns_environment
  )
  on conflict (fcm_token) do update set
    rider_identity_id = excluded.rider_identity_id,
    auth_user_id = excluded.auth_user_id,
    platform = excluded.platform,
    app_role = 'rider',
    driver_id = null,
    apns_environment = case
      when existing.apns_token = excluded.apns_token
        and existing.apns_environment is not null
        then existing.apns_environment
      else excluded.apns_environment
    end,
    apns_token = excluded.apns_token,
    updated_at = now();
  return jsonb_build_object('success', true);
end;
$$;

revoke all on function public.fn_register_push_device(text, text, text, uuid, text, text) from public;
grant execute on function public.fn_register_push_device(text, text, text, uuid, text, text) to authenticated;
