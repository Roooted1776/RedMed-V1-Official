-- Ops metadata only. No patient, profile, contact, URL, payload or JSON columns.
-- Keep this schema outside the Data API's exposed-schema list.
create schema redmed_ops;
revoke all on schema redmed_ops from public, anon, authenticated;
grant usage on schema redmed_ops to service_role;

create table redmed_ops.release_candidates (
  id uuid primary key default gen_random_uuid(),
  component text not null check (component in ('assist', 'owner', 'mcp', 'ops')),
  commit_sha text not null check (commit_sha ~ '^[0-9a-f]{40}$'),
  created_at timestamptz not null default now(),
  unique (component, commit_sha)
);

create table redmed_ops.gate_runs (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references redmed_ops.release_candidates(id),
  gate_key text not null check (gate_key in (
    'codec', 'nfc_contract', 'offline_cache', 'worker_device', 'mcp',
    'public_origin', 'ios_simulator', 'hardware_readback', 'clinical_review'
  )),
  outcome text not null check (outcome in ('pass', 'fail', 'blocked')),
  duration_ms integer check (duration_ms between 0 and 3600000),
  checked_at timestamptz not null default now()
);
create index gate_runs_candidate_checked_idx
  on redmed_ops.gate_runs(candidate_id, checked_at desc);

alter table redmed_ops.release_candidates enable row level security;
alter table redmed_ops.release_candidates force row level security;
alter table redmed_ops.gate_runs enable row level security;
alter table redmed_ops.gate_runs force row level security;

revoke all on all tables in schema redmed_ops from public, anon, authenticated, service_role;
grant select, insert on all tables in schema redmed_ops to service_role;
-- No client policies: anon/authenticated are denied, even if grants drift.
-- service_role bypasses RLS; keep its key out of browser and Owner builds.
alter default privileges in schema redmed_ops
  revoke all on tables from public, anon, authenticated, service_role;
alter default privileges in schema redmed_ops
  revoke execute on functions from public, anon, authenticated, service_role;

comment on schema redmed_ops is
  'Internal release evidence only. Never store medical profiles, band fragments, contacts or response bodies.';
