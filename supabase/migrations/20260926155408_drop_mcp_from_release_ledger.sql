-- The release ledger is product evidence only. MCP is not a component or a gate.
delete from redmed_ops.gate_runs
 where gate_key = 'mcp'
    or candidate_id in (
      select id from redmed_ops.release_candidates where component = 'mcp'
    );
delete from redmed_ops.release_candidates where component = 'mcp';

alter table redmed_ops.release_candidates
  drop constraint release_candidates_component_check;
alter table redmed_ops.release_candidates
  add constraint release_candidates_component_check
  check (component in ('assist', 'owner', 'ops'));

alter table redmed_ops.gate_runs
  drop constraint gate_runs_gate_key_check;
alter table redmed_ops.gate_runs
  add constraint gate_runs_gate_key_check
  check (gate_key in (
    'codec', 'nfc_contract', 'offline_cache', 'worker_device',
    'public_origin', 'ios_simulator', 'hardware_readback', 'clinical_review'
  ));
