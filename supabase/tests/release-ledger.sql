-- Run with an administrative migration/test connection. All test rows roll back.
begin;
do $test$
declare
  candidate uuid;
  target text;
  client_role text;
begin
  foreach client_role in array array['anon', 'authenticated'] loop
    if has_schema_privilege(client_role, 'redmed_ops', 'USAGE') then
      raise exception '% unexpectedly has schema access', client_role;
    end if;
    foreach target in array array['release_candidates', 'gate_runs'] loop
      if has_table_privilege(client_role, 'redmed_ops.' || target, 'SELECT,INSERT,UPDATE,DELETE') then
        raise exception '% unexpectedly has table access', client_role;
      end if;
    end loop;
  end loop;
  if (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'redmed_ops' and c.relkind = 'r'
      and c.relrowsecurity and c.relforcerowsecurity) <> 2 then
    raise exception 'RLS is not enabled and forced on both tables';
  end if;
  foreach target in array array['release_candidates', 'gate_runs'] loop
    if not has_table_privilege('service_role', 'redmed_ops.' || target, 'SELECT')
       or not has_table_privilege('service_role', 'redmed_ops.' || target, 'INSERT')
       or has_table_privilege('service_role', 'redmed_ops.' || target, 'UPDATE,DELETE,TRUNCATE') then
      raise exception 'service_role is not read/append-only';
    end if;
  end loop;
  -- Exercise the actual roles, not only catalog flags.
  set local role anon;
  begin
    perform 1 from redmed_ops.release_candidates;
    raise exception 'anon read unexpectedly succeeded';
  exception when insufficient_privilege then null;
  end;
  reset role;
  set local role authenticated;
  begin
    perform 1 from redmed_ops.gate_runs;
    raise exception 'authenticated read unexpectedly succeeded';
  exception when insufficient_privilege then null;
  end;
  reset role;
  set local role service_role;
  insert into redmed_ops.release_candidates(component, commit_sha)
    values ('ops', repeat('0', 40)) returning id into candidate;
  insert into redmed_ops.gate_runs(candidate_id, gate_key, outcome, duration_ms)
    values (candidate, 'mcp', 'pass', 1);
  begin
    insert into redmed_ops.release_candidates(component, commit_sha)
      values ('ops', 'invalid');
    raise exception 'invalid SHA accepted';
  exception when check_violation then null;
  end;
  begin
    insert into redmed_ops.gate_runs(candidate_id, gate_key, outcome)
      values (candidate, 'free_text_not_allowed', 'pass');
    raise exception 'invalid gate accepted';
  exception when check_violation then null;
  end;
  begin
    insert into redmed_ops.gate_runs(candidate_id, gate_key, outcome, duration_ms)
      values (candidate, 'mcp', 'pass', -1);
    raise exception 'negative duration accepted';
  exception when check_violation then null;
  end;
  reset role;
end;
$test$;
rollback;
select 'PASS: grants, RLS, role isolation, service append, and constraints; fixtures rolled back' as result;
