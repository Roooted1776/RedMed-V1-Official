-- Proves anon cannot read wearer rows and a different signed-in user cannot either.
-- Run with an administrative connection. All fixture rows roll back.
begin;
do $test$
declare
  user_a uuid := '11111111-1111-4111-8111-111111111111';
  user_b uuid := '22222222-2222-4222-8222-222222222222';
  seen int;
  client_role text;
begin
  if has_schema_privilege('anon', 'redmed_owner', 'CREATE') then
    raise exception 'anon can create in redmed_owner';
  end if;
  if has_table_privilege('anon', 'redmed_owner.profiles', 'SELECT,INSERT,UPDATE,DELETE') then
    raise exception 'anon has table privileges on profiles';
  end if;
  if has_table_privilege('anon', 'redmed_owner.band_writes', 'SELECT,INSERT,UPDATE,DELETE') then
    raise exception 'anon has table privileges on band_writes';
  end if;
  if has_table_privilege('service_role', 'redmed_owner.profiles', 'SELECT,INSERT,UPDATE,DELETE') then
    raise exception 'service_role is granted wearer tables';
  end if;
  foreach client_role in array array['SELECT', 'INSERT', 'UPDATE', 'DELETE'] loop
    if not has_table_privilege('authenticated', 'redmed_owner.profiles', client_role) then
      raise exception 'authenticated missing % on profiles', client_role;
    end if;
    if not has_table_privilege('authenticated', 'redmed_owner.band_writes', client_role) then
      raise exception 'authenticated missing % on band_writes', client_role;
    end if;
  end loop;
  if (select count(*) from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'redmed_owner' and c.relkind = 'r'
        and c.relrowsecurity and c.relforcerowsecurity) <> 2 then
    raise exception 'RLS is not enabled and forced on both wearer tables';
  end if;

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at, confirmation_token, email_change,
    email_change_token_new, recovery_token
  ) values
    ('00000000-0000-0000-0000-000000000000', user_a, 'authenticated', 'authenticated',
     'a-owner-test@example.com', '', now(),
     '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
     now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', user_b, 'authenticated', 'authenticated',
     'b-owner-test@example.com', '', now(),
     '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
     now(), now(), '', '', '', '');

  insert into redmed_owner.profiles (id, name, blood_type, allergies)
  values (user_a, 'Fixture A', 'O+', '["Penicillin"]'::jsonb);

  set local role anon;
  begin
    perform 1 from redmed_owner.profiles;
    raise exception 'anon read unexpectedly succeeded';
  exception when insufficient_privilege then null;
  end;
  reset role;

  perform set_config('request.jwt.claim.sub', user_b::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', user_b, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into seen from redmed_owner.profiles;
  if seen <> 0 then
    raise exception 'user B can see user A profile (% rows)', seen;
  end if;
  begin
    insert into redmed_owner.profiles (id, name) values (user_a, 'stolen');
    raise exception 'user B inserted user A profile';
  exception when insufficient_privilege or check_violation or foreign_key_violation then
    null;
  end;
  reset role;

  perform set_config('request.jwt.claim.sub', user_a::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', user_a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into seen from redmed_owner.profiles;
  if seen <> 1 then
    raise exception 'user A cannot see own profile (% rows)', seen;
  end if;
  update redmed_owner.profiles set notes = 'ok' where id = user_a;
  insert into redmed_owner.band_writes (user_id, codec_version, packed_url_sha256, byte_length)
  values (user_a, 2, repeat('ab', 32), 120);
  begin
    insert into redmed_owner.band_writes (user_id, codec_version, packed_url_sha256, byte_length)
    values (user_a, 2, 'not-a-hash', 10);
    raise exception 'non-sha band write accepted';
  exception when check_violation then null;
  end;
  begin
    insert into redmed_owner.band_writes (user_id, codec_version, packed_url_sha256, byte_length)
    values (user_a, 2, repeat('ab', 32), 900);
    raise exception 'over-cap band write accepted';
  exception when check_violation then null;
  end;
  reset role;
end;
$test$;
rollback;
select 'PASS: wearer grants, forced RLS, cross-user isolation, hash constraints; fixtures rolled back' as result;
