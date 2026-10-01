#!/usr/bin/env bash
# Deploy RedMed static surfaces to the Hostinger VPS.
# Website only. The iOS app in this repo is not touched.
#
# Modes:
#   home  — home/ → DOCROOT /   (Sign in / Create account / Supabase email links)
#           Requires CONFIRM_HOMEPAGE=yes (replaces live landing).
#   store — init.html → DOCROOT/store/  (storefront; default)
#
# Usage:
#   scripts/deploy-vps.sh discover
#   DOCROOT=/path MODE=store scripts/deploy-vps.sh dry-run
#   DOCROOT=/path MODE=store scripts/deploy-vps.sh deploy
#   DOCROOT=/path MODE=home CONFIRM_HOMEPAGE=yes scripts/deploy-vps.sh deploy
#
# Env: REMOTE (default root@2.25.249.204), DOCROOT (required except discover),
#      MODE=store|home (default store), SITE (default https://redmed.live)
set -euo pipefail

REMOTE="${REMOTE:-root@2.25.249.204}"
MODE="${MODE:-store}"
SITE="${SITE:-https://redmed.live}"
CMD="${1:-}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

SSH=(ssh -o BatchMode=yes -o ConnectTimeout=10 "$REMOTE")

case "$CMD" in
  discover)
    "${SSH[@]}" 'hostname; echo "--- containers ---"; docker ps --format "{{.Names}}  {{.Image}}  {{.Ports}}"; echo "--- mounts ---"; docker ps -q | xargs -r docker inspect -f "{{.Name}}: {{range .Mounts}}{{.Source}} -> {{.Destination}}; {{end}}"; echo "--- traefik host rules ---"; docker ps -q | xargs -r docker inspect -f "{{.Name}}: {{json .Config.Labels}}" | grep -o "Host([^)]*)"'
    exit 0 ;;
  dry-run|deploy) ;;
  *) sed -n '2,18p' "$0"; exit 1 ;;
esac

: "${DOCROOT:?Set DOCROOT (run: scripts/deploy-vps.sh discover)}"

if [ "$MODE" != "home" ] && [ "$MODE" != "store" ]; then
  echo "MODE must be home or store (got: $MODE)" >&2
  exit 2
fi

if [ "$MODE" = "home" ] && [ "${CONFIRM_HOMEPAGE:-}" != "yes" ]; then
  echo "REFUSING: MODE=home replaces the live homepage (Sign in / Create account). Set CONFIRM_HOMEPAGE=yes to proceed." >&2
  exit 2
fi

TARGET="$DOCROOT"
[ "$MODE" = "store" ] && TARGET="$DOCROOT/store"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

if [ "$MODE" = "home" ]; then
  # Keep the Supabase-synced member portal at /.
  for f in home/index.html home/legacy.js; do
    [ -f "$f" ] || { echo "MISSING $f" >&2; exit 3; }
  done
  [ -d home/assets ] || { echo "MISSING home/assets/" >&2; exit 3; }
  cp home/index.html "$STAGE/index.html"
  cp home/red-white.css "$STAGE/red-white.css"
  cp home/legacy.js "$STAGE/legacy.js"
  [ -f home/favicon.svg ] && cp home/favicon.svg "$STAGE/"
  [ -f home/band-hero.webp ] && cp home/band-hero.webp "$STAGE/"
  [ -f home/nfc-detail.webp ] && cp home/nfc-detail.webp "$STAGE/"
  mkdir -p "$STAGE/assets"
  cp -a home/assets/. "$STAGE/assets/"
  grep -q 'id="auth-form"' "$STAGE/index.html" || { echo "home/index.html missing auth-form" >&2; exit 3; }
else
  # Storefront from init.html.
  FILES=(init.html store.css store.js theme.js config.js)
  missing=0
  for f in "${FILES[@]}"; do
    [ -f "$f" ] || { echo "MISSING $f" >&2; missing=1; }
  done
  while read -r a; do
    [ -f "$a" ] || { echo "MISSING $a (referenced by init.html)" >&2; missing=1; }
  done < <(grep -o 'assets/[A-Za-z0-9_.@-]*' init.html | sort -u)
  [ "$missing" -eq 0 ] || { echo "Fix missing files, then rerun." >&2; exit 3; }
  # Storefront file is init.html. Never copy it over index.html.
  cp store.css store.js theme.js config.js "$STAGE/"
  cp init.html "$STAGE/init.html"
  mkdir -p "$STAGE/assets"
  grep -o 'assets/[A-Za-z0-9_.@-]*' init.html | sort -u | while read -r a; do cp "$a" "$STAGE/assets/"; done
fi

# Store deploys must not replace index.html (homepage or an older store index).
RSYNC_EXCLUDE=()
[ "$MODE" = "store" ] && RSYNC_EXCLUDE=(--exclude index.html)

if [ "$CMD" = "dry-run" ]; then
  rsync -avn --chmod=D755,F644 "${RSYNC_EXCLUDE[@]}" -e "ssh -o BatchMode=yes" "$STAGE/" "$REMOTE:$TARGET/"
  exit 0
fi

STAMP="$(date +%Y%m%d%H%M%S)"
"${SSH[@]}" "test -d '$TARGET' && tar czf /root/redmed-backup-$STAMP.tgz -C '$TARGET' . || mkdir -p '$TARGET'"
echo "Backup: /root/redmed-backup-$STAMP.tgz (if target existed)"
rsync -av --chmod=D755,F644 "${RSYNC_EXCLUDE[@]}" -e "ssh -o BatchMode=yes" "$STAGE/" "$REMOTE:$TARGET/"
# mktemp stages are mode 700; never leave the live docroot unreadable.
"${SSH[@]}" "chmod 755 '$TARGET'"

BASE="$SITE/"; PAGE="$BASE"
[ "$MODE" = "store" ] && BASE="$SITE/store/" && PAGE="${BASE}init.html"
code="$(curl -s -o /dev/null -w '%{http_code}' "$PAGE")"
echo "GET $PAGE -> $code"
[ "$code" = "200" ] || { echo "Smoke test failed. Roll back: ssh $REMOTE 'tar xzf /root/redmed-backup-$STAMP.tgz -C $TARGET'" >&2; exit 4; }
if [ "$MODE" = "home" ]; then
  body="$(curl -sL "$PAGE")"
  echo "$body" | grep -q 'Create account' || { echo "Smoke: homepage missing Create account" >&2; exit 4; }
  echo "$body" | grep -q 'Sign in' || { echo "Smoke: homepage missing Sign in" >&2; exit 4; }
  echo "OK homepage auth chrome present"
else
  for a in $(grep -o 'assets/[A-Za-z0-9_.@-]*' init.html | sort -u); do
    c="$(curl -s -o /dev/null -w '%{http_code}' "$BASE$a")"; echo "  $a -> $c"
  done
fi
