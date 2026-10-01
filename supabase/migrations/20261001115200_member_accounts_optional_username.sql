-- Account identity for the public Sign in / Create account form.
-- Email and the password hash stay in auth.users.
-- Username is optional. No medical fields. No card data.

create table public.member_accounts (
  id uuid primary key references auth.users (id) on delete cascade,
  username text,
  created_at timestamptz not null default now(),
  constraint member_accounts_username_check check (
    username is null or username ~ '^[a-z0-9_]{3,24}$'
  )
);

create unique index member_accounts_username_key
  on public.member_accounts (username)
  where username is not null;

alter table public.member_accounts enable row level security;
alter table public.member_accounts force row level security;

revoke all on public.member_accounts from public, anon;
grant select, update on public.member_accounts to authenticated;

create policy member_accounts_select
  on public.member_accounts
  for select
  to authenticated
  using ((select auth.uid()) = id);

create policy member_accounts_update
  on public.member_accounts
  for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

create or replace function redmed_private.member_account_from_auth()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  uname text;
begin
  uname := lower(nullif(btrim(new.raw_user_meta_data ->> 'username'), ''));
  if uname is not null and uname !~ '^[a-z0-9_]{3,24}$' then
    raise exception 'username must be 3-24 letters, numbers, or underscores';
  end if;
  insert into public.member_accounts (id, username)
  values (new.id, uname)
  on conflict (id) do update
    set username = excluded.username;
  return new;
end;
$function$;

revoke all on function redmed_private.member_account_from_auth() from public, anon, authenticated;

create trigger member_accounts_from_auth
  after insert on auth.users
  for each row
  execute function redmed_private.member_account_from_auth();

insert into public.member_accounts (id)
select id from auth.users
on conflict (id) do nothing;
