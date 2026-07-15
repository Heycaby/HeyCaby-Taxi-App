-- Link only pre-approved active Admin registry entries to matching verified/invited Auth users.
-- The email match avoids hard-coding generated Auth identifiers.
UPDATE public.admin_users au
SET user_id = u.id,
    updated_at = now()
FROM auth.users u
WHERE au.user_id IS NULL
  AND au.is_active
  AND lower(au.email) = lower(u.email);

-- Existing Edge Functions still consume the established app_metadata role contract.
UPDATE auth.users u
SET raw_app_meta_data = COALESCE(u.raw_app_meta_data, '{}'::jsonb)
  || jsonb_build_object('role', au.role)
FROM public.admin_users au
WHERE au.user_id = u.id
  AND au.is_active
  AND au.role IN ('admin', 'super_admin')
  AND COALESCE(u.raw_app_meta_data->>'role', '') IS DISTINCT FROM au.role;
