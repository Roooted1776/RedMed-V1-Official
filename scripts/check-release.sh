#!/usr/bin/env bash
# Read-only verification. No deployment, DNS changes, or database writes.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [[ $# -gt 1 || ( $# -eq 1 && "$1" != "--live" ) ]]; then
  echo "Usage: bash scripts/check-release.sh [--live]" >&2
  exit 2
fi
cmp sw.js tapper/sw.js
cmp sw.js owner/RedMed/sw.js
node scripts/test-d-codec.mjs
node scripts/test-nfc-hardware.mjs
node scripts/test-sw-offline.mjs
node scripts/test-worker-device.mjs
npm run check --prefix mcp/redmed-mcp
npm test --prefix mcp/redmed-mcp
if [[ "${1:-}" == "--live" ]]; then
  # Unlike the transitional deploy workflow, parking / DNS failures are fatal.
  # Never provide a band URL or real profile to any ops check.
  BASE="$(python3 scripts/write-base-origin.py)" bash scripts/smoke-pages.sh
  echo "PASS automated live checks. Physical hardware and clinical review still required."
else
  echo "PASS local checks only. This does not establish production readiness."
fi
