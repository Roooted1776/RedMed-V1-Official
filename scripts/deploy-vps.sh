#!/usr/bin/env bash
# Deploy the RedMed website (init.html + assets) to the Hostinger VPS.
# Website only. The iOS app in this repo is not touched.
#
# Source of truth: init.html (parked/index.html is the old stub — do not deploy it).
# Static hosts need the filename index.html for /, so this script stages
# init.html → index.html in the target.
#
# Usage:
#   scripts/deploy-vps.sh discover                 # read-only: find the docroot
#   DOCROOT=/path scripts/deploy-vps.sh dry-run    # show what would change
#   DOCROOT=/path scripts/deploy-vps.sh deploy     # back up, then copy to DOCROOT (/)
#   DOCROOT=/path MODE=store scripts/deploy-vps.sh deploy
#                                                  # copy to <docroot>/store/ instead
#
# Env: REMOTE (default root@2.25.249.204), DOCROOT (required except discover),
#      MODE=home|store (default home), SITE (default https://redmed.live)
set -euo pipefail

REMOTE="${REMOTE:-root@2.25.249.204}"
MODE="${MODE:-home}"
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

TARGET="$DOCROOT"
[ "$MODE" = "store" ] && TARGET="$DOCROOT/store"

# Preflight: every file the page needs must exist locally.
FILES=(init.html store.css store.js theme.js config.js)
missing=0
for f in "${FILES[@]}"; do
  [ -f "$f" ] || { echo "MISSING $f" >&2; missing=1; }
done
while read -r a; do
  [ -f "$a" ] || { echo "MISSING $a (referenced by init.html)" >&2; missing=1; }
done < <(grep -o 'assets/[A-Za-z0-9_.@-]*' init.html | sort -u)
[ "$missing" -eq 0 ] || { echo "Fix missing files, then rerun." >&2; exit 3; }

# Stage: init.html becomes index.html. Also keep init.html. No --delete anywhere.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp store.css store.js theme.js config.js "$STAGE/"
cp init.html "$STAGE/index.html"
cp init.html "$STAGE/init.html"
mkdir -p "$STAGE/assets"
grep -o 'assets/[A-Za-z0-9_.@-]*' init.html | sort -u | while read -r a; do cp "$a" "$STAGE/assets/"; done

if [ "$CMD" = "dry-run" ]; then
  rsync -avn -e "ssh -o BatchMode=yes" "$STAGE/" "$REMOTE:$TARGET/"
  exit 0
fi

STAMP="$(date +%Y%m%d%H%M%S)"
"${SSH[@]}" "test -d '$TARGET' && tar czf /root/redmed-backup-$STAMP.tgz -C '$TARGET' . || mkdir -p '$TARGET'"
echo "Backup: /root/redmed-backup-$STAMP.tgz (if target existed)"
rsync -av -e "ssh -o BatchMode=yes" "$STAGE/" "$REMOTE:$TARGET/"

# Smoke test
URL="$SITE/"; [ "$MODE" = "store" ] && URL="$SITE/store/"
code="$(curl -s -o /dev/null -w '%{http_code}' "$URL")"
echo "GET $URL -> $code"
[ "$code" = "200" ] || { echo "Smoke test failed. Roll back: ssh $REMOTE 'tar xzf /root/redmed-backup-$STAMP.tgz -C $TARGET'" >&2; exit 4; }
# Prefer /init.html when deployed; / always serves index.html (from init).
init_code="$(curl -s -o /dev/null -w '%{http_code}' "${URL%/}/init.html")"
echo "GET ${URL%/}/init.html -> $init_code"
for a in $(grep -o 'assets/[A-Za-z0-9_.@-]*' init.html | sort -u); do
  c="$(curl -s -o /dev/null -w '%{http_code}' "$URL$a")"; echo "  $a -> $c"
done
