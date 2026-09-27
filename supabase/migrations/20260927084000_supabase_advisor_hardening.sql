-- Harden advisor findings without opening Assist/#d= to this project.
-- 1) Explicit deny-all RLS policies on ops + private tables (service_role bypasses RLS).
-- 2) Move portal SECURITY DEFINER bodies into redmed_private; keep public INVOKER wrappers
--    so PostgREST RPC paths stay stable for the portal.

-- ---------------------------------------------------------------------------
-- redmed_ops: intentional no-client access — add false policies for the linter
-- ---------------------------------------------------------------------------
drop policy if exists gate_runs_no_client on redmed_ops.gate_runs;
create policy gate_runs_no_client
  on redmed_ops.gate_runs
  for all
  to anon, authenticated
  using (false)
  with check (false);

drop policy if exists release_candidates_no_client on redmed_ops.release_candidates;
create policy release_candidates_no_client
  on redmed_ops.release_candidates
  for all
  to anon, authenticated
  using (false)
  with check (false);

-- ---------------------------------------------------------------------------
-- redmed_private: force RLS + deny clients (portal RPCs stay DEFINER)
-- ---------------------------------------------------------------------------
alter table redmed_private.admin_events enable row level security;
alter table redmed_private.admin_events force row level security;
alter table redmed_private.admin_members enable row level security;
alter table redmed_private.admin_members force row level security;

revoke all on all tables in schema redmed_private from public, anon, authenticated;
revoke all on schema redmed_private from public, anon, authenticated;
grant usage on schema redmed_private to postgres, service_role;
-- Authenticated may EXECUTE specific private helpers below; not table DML.
grant usage on schema redmed_private to authenticated;

drop policy if exists admin_events_no_client on redmed_private.admin_events;
create policy admin_events_no_client
  on redmed_private.admin_events
  for all
  to anon, authenticated
  using (false)
  with check (false);

drop policy if exists admin_members_no_client on redmed_private.admin_members;
create policy admin_members_no_client
  on redmed_private.admin_members
  for all
  to anon, authenticated
  using (false)
  with check (false);

grant select, insert, update on redmed_private.admin_events to service_role;
grant select, insert, update, delete on redmed_private.admin_members to service_role;

-- ---------------------------------------------------------------------------
-- Private DEFINER implementations
-- ---------------------------------------------------------------------------
create or replace function redmed_private.portal_account_enabled()
returns boolean
language sql
stable
security definer
set search_path to ''
as $function$
  select exists (
    select 1
    from auth.users u
    where u.id = auth.uid()
      and u.email_confirmed_at is not null
      and (u.banned_until is null or u.banned_until <= now())
  );
$function$;

create or replace function redmed_private.portal_is_admin()
returns boolean
language sql
stable
security definer
set search_path to ''
as $function$
  select redmed_private.portal_account_enabled()
    and exists (
      select 1
      from redmed_private.admin_members a
      where a.user_id = auth.uid()
    );
$function$;

create or replace function redmed_private.portal_admin_target_protected(p_target uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $function$
  select exists (
    select 1 from redmed_private.admin_members where user_id = p_target
  );
$function$;

create or replace function redmed_private.portal_admin_events()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if not redmed_private.portal_is_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(e))
    from (
      select id, actor_id, target_id, action, outcome, created_at
      from redmed_private.admin_events
      order by created_at desc
      limit 50
    ) e
  ), '[]'::jsonb);
end;
$function$;

create or replace function redmed_private.portal_admin_directory(
  p_page integer default 1,
  p_query text default ''::text
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  result jsonb;
  page_no integer := greatest(1, least(coalesce(p_page, 1), 100000));
begin
  if not redmed_private.portal_is_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;
  if length(coalesce(p_query, '')) > 254 then
    raise exception 'Search too long';
  end if;
  select jsonb_build_object(
    'total_users', (select count(*) from auth.users),
    'total_bands', (select count(*) from public.member_bands),
    'filtered', (
      select count(*) from auth.users
      where strpos(lower(coalesce(email, '')), lower(coalesce(p_query, ''))) > 0
    ),
    'page', page_no,
    'users', coalesce((
      select jsonb_agg(to_jsonb(r)) from (
        select
          u.id,
          u.email,
          u.created_at,
          u.email_confirmed_at,
          coalesce(u.banned_until > now(), false) as suspended,
          exists (
            select 1 from redmed_private.admin_members a where a.user_id = u.id
          ) as is_admin,
          (select count(*) from public.member_bands b where b.owner_id = u.id) as bands
        from auth.users u
        where strpos(lower(coalesce(u.email, '')), lower(coalesce(p_query, ''))) > 0
        order by u.created_at desc, u.id
        limit 20 offset (page_no - 1) * 20
      ) r
    ), '[]'::jsonb)
  ) into result;
  return result;
end;
$function$;

create or replace function redmed_private.portal_admin_begin(
  p_actor uuid,
  p_action text,
  p_target uuid default null::uuid
)
returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare
  event_id uuid;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_actor::text, 0));
  if not exists (
    select 1
    from redmed_private.admin_members a
    join auth.users u on u.id = a.user_id
    where a.user_id = p_actor
      and u.email_confirmed_at is not null
      and (u.banned_until is null or u.banned_until <= now())
  ) then
    raise exception 'Admin access required' using errcode = '42501';
  end if;
  if (
    select count(*)
    from redmed_private.admin_events
    where actor_id = p_actor and created_at > now() - interval '1 minute'
  ) >= 5 then
    raise exception 'Rate limit: wait one minute';
  end if;
  if p_target = p_actor
    or exists (select 1 from redmed_private.admin_members where user_id = p_target)
  then
    raise exception 'Administrator accounts are protected';
  end if;
  insert into redmed_private.admin_events (actor_id, target_id, action)
  values (p_actor, p_target, p_action)
  returning id into event_id;
  return event_id;
end;
$function$;

create or replace function redmed_private.portal_admin_finish(
  p_event uuid,
  p_outcome text,
  p_target uuid default null::uuid
)
returns void
language sql
security definer
set search_path to ''
as $function$
  update redmed_private.admin_events
  set outcome = p_outcome,
      target_id = coalesce(p_target, target_id)
  where id = p_event and outcome = 'requested';
$function$;

revoke all on all functions in schema redmed_private from public, anon, authenticated, service_role;
grant execute on function redmed_private.portal_account_enabled() to authenticated, service_role;
grant execute on function redmed_private.portal_is_admin() to authenticated, service_role;
grant execute on function redmed_private.portal_admin_events() to authenticated, service_role;
grant execute on function redmed_private.portal_admin_directory(integer, text) to authenticated, service_role;
grant execute on function redmed_private.portal_admin_target_protected(uuid) to service_role;
grant execute on function redmed_private.portal_admin_begin(uuid, text, uuid) to service_role;
grant execute on function redmed_private.portal_admin_finish(uuid, text, uuid) to service_role;

-- ---------------------------------------------------------------------------
-- Public INVOKER wrappers (no DEFINER in the exposed schema)
-- ---------------------------------------------------------------------------
create or replace function public.portal_account_enabled()
returns boolean
language sql
stable
security invoker
set search_path to ''
as $function$
  select redmed_private.portal_account_enabled();
$function$;

create or replace function public.portal_is_admin()
returns boolean
language sql
stable
security invoker
set search_path to ''
as $function$
  select redmed_private.portal_is_admin();
$function$;

create or replace function public.portal_admin_events()
returns jsonb
language sql
stable
security invoker
set search_path to ''
as $function$
  select redmed_private.portal_admin_events();
$function$;

create or replace function public.portal_admin_directory(
  p_page integer default 1,
  p_query text default ''::text
)
returns jsonb
language sql
stable
security invoker
set search_path to ''
as $function$
  select redmed_private.portal_admin_directory(p_page, p_query);
$function$;

create or replace function public.portal_admin_target_protected(p_target uuid)
returns boolean
language sql
stable
security invoker
set search_path to ''
as $function$
  select redmed_private.portal_admin_target_protected(p_target);
$function$;

create or replace function public.portal_admin_begin(
  p_actor uuid,
  p_action text,
  p_target uuid default null::uuid
)
returns uuid
language sql
security invoker
set search_path to ''
as $function$
  select redmed_private.portal_admin_begin(p_actor, p_action, p_target);
$function$;

create or replace function public.portal_admin_finish(
  p_event uuid,
  p_outcome text,
  p_target uuid default null::uuid
)
returns void
language sql
security invoker
set search_path to ''
as $function$
  select redmed_private.portal_admin_finish(p_event, p_outcome, p_target);
$function$;

revoke all on function public.portal_account_enabled() from public, anon;
revoke all on function public.portal_is_admin() from public, anon;
revoke all on function public.portal_admin_events() from public, anon;
revoke all on function public.portal_admin_directory(integer, text) from public, anon;
revoke all on function public.portal_admin_target_protected(uuid) from public, anon, authenticated;
revoke all on function public.portal_admin_begin(uuid, text, uuid) from public, anon, authenticated;
revoke all on function public.portal_admin_finish(uuid, text, uuid) from public, anon, authenticated;

grant execute on function public.portal_account_enabled() to authenticated, service_role;
grant execute on function public.portal_is_admin() to authenticated, service_role;
grant execute on function public.portal_admin_events() to authenticated, service_role;
grant execute on function public.portal_admin_directory(integer, text) to authenticated, service_role;
grant execute on function public.portal_admin_target_protected(uuid) to service_role;
grant execute on function public.portal_admin_begin(uuid, text, uuid) to service_role;
grant execute on function public.portal_admin_finish(uuid, text, uuid) to service_role;

notify pgrst, 'reload schema';
