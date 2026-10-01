create table public.member_bands (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  serial text not null check (serial ~ '^[0-9A-F]{8,32}$'),
  color text not null check (color in ('red','black','white','other')),
  status text not null default 'registered' check (status in ('registered','in_use','lost','retired')),
  created_at timestamptz not null default now(),
  unique (owner_id, serial)
);
create index member_bands_owner_idx on public.member_bands(owner_id);
alter table public.member_bands enable row level security;
alter table public.member_bands force row level security;
revoke all on public.member_bands from public, anon, authenticated;
grant select, delete on public.member_bands to authenticated;
grant insert (owner_id, serial, color, status) on public.member_bands to authenticated;
grant update (color, status) on public.member_bands to authenticated;
create policy member_bands_select on public.member_bands for select to authenticated using ((select auth.uid()) = owner_id);
create policy member_bands_insert on public.member_bands for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy member_bands_update on public.member_bands for update to authenticated using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
create policy member_bands_delete on public.member_bands for delete to authenticated using ((select auth.uid()) = owner_id);
comment on table public.member_bands is 'Non-medical inventory. UID is not ownership proof. Status changes never revoke a band payload.';
