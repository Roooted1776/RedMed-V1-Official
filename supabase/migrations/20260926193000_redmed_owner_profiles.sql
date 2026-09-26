-- Signed-in wearer copy. Not the rescuer path.
-- redmed_ops stays release evidence and is not altered here.
-- The raw #d= fragment is not stored. The public tap page does not query this schema.
-- service_role is not granted: the secret API key must not select these rows.
-- anon has schema USAGE only so PostgREST can resolve the schema, then no table rights.

create schema if not exists redmed_owner;

revoke all on schema redmed_owner from public;
grant usage on schema redmed_owner to anon, authenticated;

create table redmed_owner.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null default '' check (char_length(name) <= 200),
  birth_date text not null default '' check (char_length(birth_date) <= 200),
  blood_type text not null default '' check (char_length(blood_type) <= 200),
  allergies jsonb not null default '[]'::jsonb check (jsonb_typeof(allergies) = 'array'),
  medications jsonb not null default '[]'::jsonb check (jsonb_typeof(medications) = 'array'),
  conditions jsonb not null default '[]'::jsonb check (jsonb_typeof(conditions) = 'array'),
  contacts jsonb not null default '[]'::jsonb check (jsonb_typeof(contacts) = 'array'),
  bracelet_linked boolean not null default false,
  is_organ_donor boolean not null default false,
  is_pregnant boolean not null default false,
  is_deaf_or_vision_impaired boolean not null default false,
  last_updated text not null default '' check (char_length(last_updated) <= 200),
  notes text not null default '' check (char_length(notes) <= 200),
  updated_at timestamptz not null default now()
);

create table redmed_owner.band_writes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  written_at timestamptz not null default now(),
  codec_version smallint not null check (codec_version = 2),
  packed_url_sha256 text not null check (packed_url_sha256 ~ '^[0-9a-f]{64}$'),
  byte_length integer not null check (byte_length between 1 and 850)
);

create index band_writes_user_written_idx
  on redmed_owner.band_writes (user_id, written_at desc);

create function redmed_owner.touch_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_touch_updated_at
  before update on redmed_owner.profiles
  for each row execute function redmed_owner.touch_updated_at();

revoke all on function redmed_owner.touch_updated_at() from public, anon, authenticated, service_role;

alter table redmed_owner.profiles enable row level security;
alter table redmed_owner.profiles force row level security;
alter table redmed_owner.band_writes enable row level security;
alter table redmed_owner.band_writes force row level security;

revoke all on all tables in schema redmed_owner from public, anon, authenticated, service_role;
grant select, insert, update, delete on redmed_owner.profiles to authenticated;
grant select, insert, update, delete on redmed_owner.band_writes to authenticated;

alter default privileges in schema redmed_owner
  revoke all on tables from public, anon, authenticated, service_role;
alter default privileges in schema redmed_owner
  revoke execute on functions from public, anon, authenticated, service_role;

create policy profiles_select on redmed_owner.profiles
  for select to authenticated
  using (id = (select auth.uid()));

create policy profiles_insert on redmed_owner.profiles
  for insert to authenticated
  with check (id = (select auth.uid()));

create policy profiles_update on redmed_owner.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy profiles_delete on redmed_owner.profiles
  for delete to authenticated
  using (id = (select auth.uid()));

create policy band_writes_select on redmed_owner.band_writes
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy band_writes_insert on redmed_owner.band_writes
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy band_writes_update on redmed_owner.band_writes
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy band_writes_delete on redmed_owner.band_writes
  for delete to authenticated
  using (user_id = (select auth.uid()));

comment on schema redmed_owner is
  'Signed-in wearer profile. Not the band tap path. No raw #d= fragments.';

comment on table redmed_owner.band_writes is
  'Verified write metadata only: time, codec version, sha256, byte length. Not the URL.';

-- Add this schema to the Data API list without dropping public.
-- Manual pgrst.db_schemas means the dashboard Exposed schemas control stops
-- managing this role until it is reset. See Supabase "Using Custom Schemas".
do $$
declare
  current_schemas text;
begin
  select split_part(cfg, '=', 2)
    into current_schemas
  from pg_roles r
  cross join lateral unnest(coalesce(r.rolconfig, array[]::text[])) as cfg
  where r.rolname = 'authenticator'
    and cfg like 'pgrst.db_schemas=%'
  limit 1;

  if current_schemas is null or btrim(current_schemas) = '' then
    current_schemas := 'public, graphql_public';
  end if;

  if position('redmed_owner' in current_schemas) = 0 then
    execute format(
      'alter role authenticator set pgrst.db_schemas = %L',
      current_schemas || ', redmed_owner'
    );
  end if;
end $$;

notify pgrst, 'reload config';
