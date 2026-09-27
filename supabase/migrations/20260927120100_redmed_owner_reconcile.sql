-- Bring redmed_owner to the Owner app contract (shared with Roooted1776/RedMed-iOS).
--
-- 20260926193000_redmed_owner_profiles.sql + 20260926194500_owner_touch_search_path.sql
-- created the live project's schema on 2026-09-26. This forward migration
-- tightens that shape without rewriting either applied file:
--
--   * band_writes is append-only: no UPDATE grant, no update policy.
--     Erase All User Data still deletes (delete policy + grant kept).
--   * profiles.updated_at is server-stamped on INSERT as well as UPDATE, so a
--     phone clock can't win a first-sync conflict. created_at is server-owned.
--   * anon has no USAGE on the schema and no table rights. Only `authenticated`
--     reaches it. PostgREST still lists the schema via pgrst.db_schemas.
--   * One own-row policy set per table (`*_own`, `(select auth.uid())`).
--
-- Column types are left alone (jsonb lists, 200-char caps); the app already
-- reads and writes JSON arrays and caps every field at 200 characters.
--
-- Idempotent. Run as one transaction.

-- ---------------------------------------------------------------------------
-- Schema access
-- ---------------------------------------------------------------------------

revoke all on schema redmed_owner from public, anon;
grant usage on schema redmed_owner to authenticated;

-- ---------------------------------------------------------------------------
-- profiles: server-owned stamps
-- ---------------------------------------------------------------------------

alter table redmed_owner.profiles
  add column if not exists created_at timestamptz not null default now();

create or replace function redmed_owner.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  if tg_op = 'INSERT' then
    new.created_at := now();
  else
    new.created_at := old.created_at;
  end if;
  return new;
end;
$$;

revoke all on function redmed_owner.touch_updated_at() from public, anon, authenticated, service_role;

drop trigger if exists profiles_touch_updated_at on redmed_owner.profiles;
create trigger profiles_touch_updated_at
  before insert or update on redmed_owner.profiles
  for each row execute function redmed_owner.touch_updated_at();

-- ---------------------------------------------------------------------------
-- profiles: one policy set (own row, all four verbs)
-- ---------------------------------------------------------------------------

drop policy if exists profiles_select on redmed_owner.profiles;
drop policy if exists profiles_insert on redmed_owner.profiles;
drop policy if exists profiles_update on redmed_owner.profiles;
drop policy if exists profiles_delete on redmed_owner.profiles;

drop policy if exists profiles_select_own on redmed_owner.profiles;
create policy profiles_select_own on redmed_owner.profiles
  for select to authenticated
  using (id = (select auth.uid()));

drop policy if exists profiles_insert_own on redmed_owner.profiles;
create policy profiles_insert_own on redmed_owner.profiles
  for insert to authenticated
  with check (id = (select auth.uid()));

drop policy if exists profiles_update_own on redmed_owner.profiles;
create policy profiles_update_own on redmed_owner.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

drop policy if exists profiles_delete_own on redmed_owner.profiles;
create policy profiles_delete_own on redmed_owner.profiles
  for delete to authenticated
  using (id = (select auth.uid()));

alter table redmed_owner.profiles enable row level security;
alter table redmed_owner.profiles force row level security;

revoke all on redmed_owner.profiles from public, anon;
grant select, insert, update, delete on redmed_owner.profiles to authenticated;

-- ---------------------------------------------------------------------------
-- band_writes: append-only
-- ---------------------------------------------------------------------------

alter table redmed_owner.band_writes
  alter column user_id set default auth.uid();

drop policy if exists band_writes_select on redmed_owner.band_writes;
drop policy if exists band_writes_insert on redmed_owner.band_writes;
drop policy if exists band_writes_update on redmed_owner.band_writes;
drop policy if exists band_writes_delete on redmed_owner.band_writes;

drop policy if exists band_writes_select_own on redmed_owner.band_writes;
create policy band_writes_select_own on redmed_owner.band_writes
  for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists band_writes_insert_own on redmed_owner.band_writes;
create policy band_writes_insert_own on redmed_owner.band_writes
  for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists band_writes_delete_own on redmed_owner.band_writes;
create policy band_writes_delete_own on redmed_owner.band_writes
  for delete to authenticated
  using (user_id = (select auth.uid()));

alter table redmed_owner.band_writes enable row level security;
alter table redmed_owner.band_writes force row level security;

revoke all on redmed_owner.band_writes from public, anon, authenticated;
grant select, insert, delete on redmed_owner.band_writes to authenticated;

-- PostgREST picks up the new grants without a restart.
notify pgrst, 'reload schema';
