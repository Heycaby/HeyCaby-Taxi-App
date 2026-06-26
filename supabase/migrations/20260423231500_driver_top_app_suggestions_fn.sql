-- Driver app suggestions: public top ideas feed (anonymized).
-- Returns only suggestion text + status + votes metadata for app UI.

create or replace function public.fn_driver_top_app_suggestions(p_limit integer default 8)
returns table (
  suggestion_text text,
  status text,
  votes_count integer,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    s.suggestion_text,
    s.status,
    s.votes_count,
    s.created_at
  from public.driver_app_suggestions s
  where s.status <> 'rejected'
  order by
    case s.status
      when 'planned' then 1
      when 'in_progress' then 2
      when 'reviewing' then 3
      when 'new' then 4
      when 'done' then 5
      else 99
    end asc,
    s.votes_count desc,
    s.created_at desc
  limit greatest(1, least(coalesce(p_limit, 8), 30));
$$;

revoke all on function public.fn_driver_top_app_suggestions(integer) from public;
grant execute on function public.fn_driver_top_app_suggestions(integer) to authenticated;
grant execute on function public.fn_driver_top_app_suggestions(integer) to service_role;
