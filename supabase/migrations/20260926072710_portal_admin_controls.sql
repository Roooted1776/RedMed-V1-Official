-- No medical data. Admin membership is provisioned only through trusted SQL.
create schema if not exists redmed_private;
revoke all on schema redmed_private from public, anon, authenticated;
create table redmed_private.admin_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table redmed_private.admin_events (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null,
  target_id uuid,
  action text not null check(action in ('invite','suspend','restore')),
  outcome text not null default 'requested' check(outcome in ('requested','succeeded','failed')),
  created_at timestamptz not null default now()
);
create index admin_events_actor_time on redmed_private.admin_events(actor_id,created_at desc);
alter table redmed_private.admin_members enable row level security;
alter table redmed_private.admin_events enable row level security;
revoke all on all tables in schema redmed_private from public, anon, authenticated;

create function public.portal_account_enabled() returns boolean
language sql stable security definer set search_path = ''
as $$ select exists(select 1 from auth.users u where u.id=auth.uid()
  and u.email_confirmed_at is not null and (u.banned_until is null or u.banned_until <= now())); $$;
create function public.portal_is_admin() returns boolean
language sql stable security definer set search_path = ''
as $$ select public.portal_account_enabled() and exists(
  select 1 from redmed_private.admin_members a where a.user_id=auth.uid()); $$;
revoke all on function public.portal_account_enabled(), public.portal_is_admin() from public, anon;
grant execute on function public.portal_account_enabled(), public.portal_is_admin() to authenticated;

-- A suspended account's existing JWT must not retain access to band records.
-- Keep the four existing owner-only permissive policies; AND this restriction.
create policy portal_enabled on public.member_bands as restrictive
for all to authenticated using ((select public.portal_account_enabled()))
with check ((select public.portal_account_enabled()));

create function public.portal_admin_directory(p_page integer default 1, p_query text default '')
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare result jsonb; page_no integer := greatest(1,least(coalesce(p_page,1),100000));
begin
  if not public.portal_is_admin() then raise exception 'Admin access required' using errcode='42501'; end if;
  if length(coalesce(p_query,'')) > 254 then raise exception 'Search too long'; end if;
  select jsonb_build_object(
    'total_users',(select count(*) from auth.users),
    'total_bands',(select count(*) from public.member_bands),
    'filtered',(select count(*) from auth.users where strpos(lower(coalesce(email,'')),lower(coalesce(p_query,''))) > 0),
    'page',page_no,
    'users',coalesce((select jsonb_agg(to_jsonb(r)) from (
      select u.id,u.email,u.created_at,u.email_confirmed_at,
        coalesce(u.banned_until > now(),false) as suspended,
        exists(select 1 from redmed_private.admin_members a where a.user_id=u.id) as is_admin,
        (select count(*) from public.member_bands b where b.owner_id=u.id) as bands
      from auth.users u where strpos(lower(coalesce(u.email,'')),lower(coalesce(p_query,''))) > 0
      order by u.created_at desc,u.id limit 20 offset (page_no-1)*20
    ) r),'[]'::jsonb)
  ) into result;
  return result;
end; $$;
create function public.portal_admin_events() returns jsonb
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.portal_is_admin() then raise exception 'Admin access required' using errcode='42501'; end if;
  return coalesce((select jsonb_agg(to_jsonb(e)) from (
    select id,actor_id,target_id,action,outcome,created_at from redmed_private.admin_events
    order by created_at desc limit 50) e),'[]'::jsonb);
end; $$;
revoke all on function public.portal_admin_directory(integer,text), public.portal_admin_events() from public,anon;
grant execute on function public.portal_admin_directory(integer,text), public.portal_admin_events() to authenticated;

-- Only the Edge Function's service client can invoke these helpers.
create function public.portal_admin_target_protected(p_target uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists(select 1 from redmed_private.admin_members where user_id=p_target); $$;
create function public.portal_admin_begin(p_actor uuid,p_action text,p_target uuid default null) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare event_id uuid;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_actor::text,0));
  if not exists(select 1 from redmed_private.admin_members a join auth.users u on u.id=a.user_id
    where a.user_id=p_actor and u.email_confirmed_at is not null and (u.banned_until is null or u.banned_until<=now()))
    then raise exception 'Admin access required' using errcode='42501'; end if;
  if (select count(*) from redmed_private.admin_events where actor_id=p_actor and created_at > now()-interval '1 minute') >= 5
    then raise exception 'Rate limit: wait one minute'; end if;
  if p_target=p_actor or exists(select 1 from redmed_private.admin_members where user_id=p_target)
    then raise exception 'Administrator accounts are protected'; end if;
  insert into redmed_private.admin_events(actor_id,target_id,action) values(p_actor,p_target,p_action) returning id into event_id;
  return event_id;
end; $$;
create function public.portal_admin_finish(p_event uuid,p_outcome text,p_target uuid default null) returns void
language sql security definer set search_path = ''
as $$ update redmed_private.admin_events set outcome=p_outcome,target_id=coalesce(p_target,target_id)
  where id=p_event and outcome='requested'; $$;
revoke all on function public.portal_admin_target_protected(uuid), public.portal_admin_begin(uuid,text,uuid),
 public.portal_admin_finish(uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.portal_admin_target_protected(uuid), public.portal_admin_begin(uuid,text,uuid),
 public.portal_admin_finish(uuid,text,uuid) to service_role;
