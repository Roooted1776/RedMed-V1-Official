-- Behavioural RLS test for redmed_owner. Runs in one transaction, rolls back.
-- Run with psql -v ON_ERROR_STOP=1 after local_auth_shim.sql + the owner migrations
-- (scripts/test-supabase-rls.sh). Never against a Supabase project.
begin;

insert into auth.users (id) values
  ('00000000-0000-0000-0000-00000000000a'),
  ('00000000-0000-0000-0000-00000000000b');

-- Helper: become a signed-in user.
create or replace function pg_temp.as_user(uid text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', uid, true);
  execute 'set local role authenticated';
end $$;

-- 0. Converged shape after the reconcile migration.
do $$ begin
  assert not has_schema_privilege('anon', 'redmed_owner', 'usage'), 'anon has schema usage';
  assert has_schema_privilege('authenticated', 'redmed_owner', 'usage'), 'authenticated lacks schema usage';
  assert not has_table_privilege('authenticated', 'redmed_owner.band_writes', 'update'),
    'band_writes is updatable';
  assert (select array_agg(policyname::text order by policyname) from pg_policies
          where schemaname = 'redmed_owner') = array[
            'band_writes_delete_own', 'band_writes_insert_own', 'band_writes_select_own',
            'profiles_delete_own', 'profiles_insert_own', 'profiles_select_own', 'profiles_update_own'],
    'policy set is not exactly the repo set';
  assert exists (select 1 from information_schema.triggers
                 where event_object_schema = 'redmed_owner' and trigger_name = 'profiles_touch_updated_at'
                   and event_manipulation = 'INSERT'), 'updated_at not stamped on insert';
end $$;

-- 1. A creates own row; server stamps updated_at even if the client lies.
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a') \gset
insert into redmed_owner.profiles (id, name, contacts, updated_at)
values ('00000000-0000-0000-0000-00000000000a', 'Alex',
        '[{"name":"Sam","relationship":"Sister","phone":"+15550100"}]', '2000-01-01');
do $$ begin
  assert (select updated_at > now() - interval '1 minute' from redmed_owner.profiles),
    'updated_at must be server-set';
end $$;

-- 2. PostgREST merge-duplicates upsert path works for own row.
insert into redmed_owner.profiles (id, name) values ('00000000-0000-0000-0000-00000000000a', 'Alex R')
on conflict (id) do update set name = excluded.name;
do $$ begin
  assert (select name from redmed_owner.profiles) = 'Alex R', 'upsert own row';
end $$;

-- 3. A cannot create B's row.
do $$ begin
  begin
    insert into redmed_owner.profiles (id, name) values ('00000000-0000-0000-0000-00000000000b', 'x');
    raise exception 'FAIL: inserted another user''s row';
  exception when insufficient_privilege then null;
  end;
end $$;

-- 4. A cannot move own row to B's id.
do $$ begin
  begin
    update redmed_owner.profiles set id = '00000000-0000-0000-0000-00000000000b';
    raise exception 'FAIL: re-keyed row to another user';
  exception when insufficient_privilege then null;
  end;
end $$;

-- 5. Band write: good row ok, bad hash / oversize / update refused.
insert into redmed_owner.band_writes (codec_version, packed_url_sha256, byte_length)
values (2, repeat('ab', 32), 612);
do $$ begin
  begin
    insert into redmed_owner.band_writes (codec_version, packed_url_sha256, byte_length) values (2, 'https://redmed.live/tapper/#d=AAAA', 30);
    raise exception 'FAIL: raw URL accepted as hash';
  exception when check_violation then null;
  end;
  begin
    insert into redmed_owner.band_writes (codec_version, packed_url_sha256, byte_length) values (2, repeat('cd', 32), 851);
    raise exception 'FAIL: over NTAG216 cap accepted';
  exception when check_violation then null;
  end;
  begin
    update redmed_owner.band_writes set byte_length = 1;
    raise exception 'FAIL: band_writes is updatable';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into redmed_owner.band_writes (user_id, codec_version, packed_url_sha256, byte_length)
    values ('00000000-0000-0000-0000-00000000000b', 2, repeat('ef', 32), 10);
    raise exception 'FAIL: band write for another user';
  exception when insufficient_privilege then null;
  end;
end $$;

-- 6. B sees nothing of A and can't change or delete it.
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b') \gset
do $$ declare n int; begin
  assert (select count(*) from redmed_owner.profiles) = 0, 'B sees A profile';
  assert (select count(*) from redmed_owner.band_writes) = 0, 'B sees A band writes';
  update redmed_owner.profiles set name = 'pwned';
  get diagnostics n = row_count; assert n = 0, 'B updated A';
  delete from redmed_owner.profiles;
  get diagnostics n = row_count; assert n = 0, 'B deleted A';
end $$;

-- 7. anon has no access at all.
reset role;
set local role anon;
do $$ begin
  begin
    perform 1 from redmed_owner.profiles;
    raise exception 'FAIL: anon can read profiles';
  exception when insufficient_privilege then null;
  end;
end $$;

-- 8. A deletes own copy (Erase All User Data path).
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a') \gset
delete from redmed_owner.band_writes;
delete from redmed_owner.profiles;
do $$ begin
  assert (select count(*) from redmed_owner.profiles) = 0, 'A delete own row';
end $$;

-- 9. Size caps hold.
do $$ begin
  begin
    insert into redmed_owner.profiles (id, notes) values ('00000000-0000-0000-0000-00000000000a', repeat('x', 2001));
    raise exception 'FAIL: notes cap';
  exception when check_violation then null;
  end;
  begin
    insert into redmed_owner.profiles (id, contacts) values ('00000000-0000-0000-0000-00000000000a', '{"not":"array"}');
    raise exception 'FAIL: contacts shape';
  exception when check_violation then null;
  end;
end $$;

-- 10. Deleting the auth user cascades.
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a') \gset
insert into redmed_owner.profiles (id) values ('00000000-0000-0000-0000-00000000000a');
reset role;
delete from auth.users where id = '00000000-0000-0000-0000-00000000000a';
do $$ begin
  assert (select count(*) from redmed_owner.profiles) = 0, 'cascade from auth.users';
end $$;

-- 11. delete_my_account: anon and a JWT with no sub are refused; a signed-in
--     user deletes only itself, and its rows cascade.
reset role;
insert into auth.users (id) values ('00000000-0000-0000-0000-00000000000c');
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c') \gset
insert into redmed_owner.profiles (id, name) values ('00000000-0000-0000-0000-00000000000c', 'Casey');
insert into redmed_owner.band_writes (codec_version, packed_url_sha256, byte_length)
values (2, repeat('0a', 32), 100);

reset role;
set local role anon;
do $$ begin
  begin
    perform redmed_owner.delete_my_account();
    raise exception 'FAIL: anon called delete_my_account';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
select pg_temp.as_user('') \gset
do $$ begin
  begin
    perform redmed_owner.delete_my_account();
    raise exception 'FAIL: delete_my_account ran without a user';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b') \gset
select redmed_owner.delete_my_account();
reset role;
do $$ begin
  assert not exists (select 1 from auth.users where id = '00000000-0000-0000-0000-00000000000b'),
    'B deleted itself';
  assert exists (select 1 from auth.users where id = '00000000-0000-0000-0000-00000000000c'),
    'B deleting itself left C';
  assert (select count(*) from redmed_owner.profiles) = 1, 'C profile survives B';
end $$;

select pg_temp.as_user('00000000-0000-0000-0000-00000000000c') \gset
select redmed_owner.delete_my_account();
reset role;
do $$ begin
  assert not exists (select 1 from auth.users where id = '00000000-0000-0000-0000-00000000000c'),
    'C deleted itself';
  assert (select count(*) from redmed_owner.profiles) = 0, 'C profile cascaded';
  assert (select count(*) from redmed_owner.band_writes) = 0, 'C band writes cascaded';
end $$;

select 'redmed_owner RLS: all assertions passed' as result;
rollback;
