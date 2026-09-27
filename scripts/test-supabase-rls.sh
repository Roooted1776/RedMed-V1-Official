#!/usr/bin/env bash
# Apply the redmed_owner migrations to a throwaway local Postgres with a
# minimal Supabase auth shim, then run the behavioural RLS test.
#
#   live   the migrations that created the live schema, once, in order
#          (20260926193000 / 20260926194500 are plain CREATE, not re-runnable)
#          + every later owner migration, twice (idempotence).
#
# Ops / portal migrations (redmed_ops, redmed_private) are not applied here.
# Needs psql + a reachable Postgres.
#
#   PGHOST=... PGPORT=... PGUSER=postgres scripts/test-supabase-rls.sh
#
# Never point this at a Supabase project: the shim creates auth.uid().
set -euo pipefail
export PGOPTIONS="${PGOPTIONS:-} -c client_min_messages=warning"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MIG="$ROOT/supabase/migrations"
TESTS="$ROOT/supabase/tests"
DBS=()
cleanup() { for db in "${DBS[@]}"; do psql -qc "drop database if exists $db" postgres >/dev/null || true; done; }
trap cleanup EXIT

run() { psql -v ON_ERROR_STOP=1 -q -d "$1" -f "$2" >/dev/null; }

BASE=(
  "$MIG/20260926193000_redmed_owner_profiles.sql"
  "$MIG/20260926194500_owner_touch_search_path.sql"
)
forward=()
for f in "$MIG"/*owner*.sql; do
  case " ${BASE[*]} " in *" $f "*) ;; *) forward+=("$f") ;; esac
done

scenario() {
  local name="$1"
  local db="redmed_rls_${name//-/_}_$$"
  DBS+=("$db")
  psql -v ON_ERROR_STOP=1 -qc "create database $db" postgres
  run "$db" "$TESTS/local_auth_shim.sql"
  for f in "${BASE[@]}"; do run "$db" "$f"; done
  for f in "${forward[@]}"; do run "$db" "$f"; run "$db" "$f"; done
  local out
  out="$(psql -v ON_ERROR_STOP=1 -q -d "$db" -f "$TESTS/redmed_owner_rls.sql")"
  grep -q 'all assertions passed' <<<"$out"
  echo "OK   $name"
}

scenario live
echo "redmed_owner RLS: passed"
