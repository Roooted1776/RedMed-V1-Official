#!/usr/bin/env bash
# Apply the redmed_owner migrations to a throwaway local Postgres with a
# minimal Supabase auth shim, then run the behavioural RLS test. Every
# migration runs twice (idempotence). Three starting points:
#
#   fresh      repo migrations on an empty database (new project, CI)
#   live       the live project's first schema (supabase/tests/live_schema_20260926.sql)
#              + the migrations applied to it after 20260926000000
#   live-push  that same live schema + every repo migration (`supabase db push`)
#
# All three must end in the same enforced shape. Needs psql + a reachable Postgres.
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

scenario() {
  local name="$1" base="$2"; shift 2
  local db="redmed_rls_${name//-/_}_$$"
  DBS+=("$db")
  psql -v ON_ERROR_STOP=1 -qc "create database $db" postgres
  run "$db" "$TESTS/local_auth_shim.sql"
  if [ -n "$base" ]; then run "$db" "$base"; fi
  for f in "$@"; do run "$db" "$f"; run "$db" "$f"; done
  local out
  out="$(psql -v ON_ERROR_STOP=1 -q -d "$db" -f "$TESTS/redmed_owner_rls.sql")"
  grep -q 'all assertions passed' <<<"$out"
  echo "OK   $name"
}

all=("$MIG"/*.sql)
after_base=()
for f in "${all[@]}"; do
  [ "$(basename "$f")" = "20260926000000_redmed_owner.sql" ] || after_base+=("$f")
done

scenario fresh     ""                                   "${all[@]}"
scenario live      "$TESTS/live_schema_20260926.sql"    "${after_base[@]}"
scenario live-push "$TESTS/live_schema_20260926.sql"    "${all[@]}"
echo "redmed_owner RLS: 3 scenarios passed"
