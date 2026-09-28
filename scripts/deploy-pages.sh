#!/usr/bin/env bash
# Tapper shell local serve / legacy Hostinger shared-static push.
#
# Bracelet taps must open AppConfig.medicalCardBaseURL#d=… as RedMed · 911 · Aid.
# Live product host: https://redmed.live/tapper/ — served by the Hostinger VPS +
# Traefik (docs/domain.md), which this script does not deploy to. github.io
# kept as backup for already-written bands.
# (quick, no login, no server, no app). Repo tapper/index.html is that shell.
# Legacy /get/ / redmed-emergency.html redirect to /tapper/ and keep #d=.
#
# Usage:
#   ./scripts/deploy-pages.sh              # local http://127.0.0.1:8787/tapper/
#   PORT=9000 ./scripts/deploy-pages.sh
#   DEPLOY=1 ./scripts/deploy-pages.sh     # legacy Hostinger shared-static upload
#                                          # (needs HOSTINGER_API_TOKEN) — always
#                                          # refused for redmed.live unless
#                                          # REDMED_ALLOW_HOMEPAGE_REPLACE=1, since
#                                          # that would replace the live marketing
#                                          # homepage, not this repo's stub. Not the
#                                          # real deploy path (see docs/domain.md).
#
# Hostinger (legacy path only, see above):
#   export HOSTINGER_API_TOKEN=…
#   npm install --no-save axios tus-js-client   # once per machine
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SHELL="tapper/index.html"
# Sanity: refuse to serve/deploy if the tapper shell is missing tabs or is band-setup.
if ! grep -q 'data-tab="medical"' "$SHELL" \
  || ! grep -q 'data-tab="911"' "$SHELL" \
  || ! grep -q 'id="tab-aid"' "$SHELL"; then
  echo "$SHELL is missing RedMed · 911 · Aid tabs — abort." >&2
  exit 1
fi
if grep -q 'id="tab-nfc"' "$SHELL"; then
  echo "$SHELL has NFC tab — passerby is RedMed · 911 · Aid only — abort." >&2
  exit 1
fi
if grep -q 'Checking your phone' "$SHELL" \
  || grep -q 'Set up your RedMed band' "$SHELL"; then
  echo "$SHELL looks like the old band-setup page — abort." >&2
  exit 1
fi

if [[ "${DEPLOY:-0}" == "1" ]]; then
  if [[ -z "${HOSTINGER_API_TOKEN:-}" ]]; then
    echo "DEPLOY=1 needs HOSTINGER_API_TOKEN (hPanel → API Tokens). See docs/domain.md." >&2
    exit 1
  fi
  bash scripts/stage-site.sh
  echo "Legacy Hostinger shared-static push → redmed.live (will be refused unless REDMED_ALLOW_HOMEPAGE_REPLACE=1 — see docs/domain.md; the real live origin is the VPS, not this path)"
  if ! node -e "import('axios')" 2>/dev/null || ! node -e "import('tus-js-client')" 2>/dev/null; then
    npm install --no-save axios tus-js-client
  fi
  exec node scripts/deploy-hostinger-static.mjs redmed.live
fi

PORT="${PORT:-8787}"
HOST="${HOST:-127.0.0.1}"
URL="http://${HOST}:${PORT}/tapper/"
ROOT_URL="http://${HOST}:${PORT}/"
echo "Local tapper shell → ${URL}"
echo "  Site root ${ROOT_URL} is the main page (https://redmed.live/). It does not redirect to /tapper/."
echo "  Use 127.0.0.1 (not a LAN IP) so #d= AES decrypt works."
echo "  Legacy Hostinger push (usually refused, see docs/domain.md): DEPLOY=1 HOSTINGER_API_TOKEN=… $0"
echo "Ctrl-C to stop."

(
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if curl -sf -o /dev/null "$URL"; then
      if command -v open >/dev/null 2>&1; then
        open "$URL"
      fi
      exit 0
    fi
    sleep 0.2
  done
) >/dev/null 2>&1 &

exec python3 -m http.server "$PORT" --bind "$HOST"
