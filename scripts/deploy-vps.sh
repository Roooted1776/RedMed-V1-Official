#!/usr/bin/env bash
# Deploy the RedMed storefront (init.html + assets) to the Hostinger VPS.
# Website only. The iOS app in this repo is not touched.
#
# Usage:
#   scripts/deploy-vps.sh discover                 # read-only: find the docroot
#   DOCROOT=/opt/redmed-store/site MODE=exact scripts/deploy-vps.sh compare   # read-only: staged vs live
#   DOCROOT=/path scripts/deploy-vps.sh dry-run    # show what would change
#   DOCROOT=/path scripts/deploy-vps.sh deploy     # back up, then copy to <docroot>/store/
#   DOCROOT=/opt/redmed-store/site MODE=exact SUBDIR=preview scripts/deploy-vps.sh deploy
#                                                  # additive: serves at /store/preview/, live /store untouched
#   DOCROOT=/path MODE=home CONFIRM_HOMEPAGE=yes scripts/deploy-vps.sh deploy
#                                                  # replaces the live homepage at /
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
  dry-run|deploy|compare) ;;
  *) sed -n '2,15p' "$0"; exit 1 ;;
esac

: "${DOCROOT:?Set DOCROOT (run: scripts/deploy-vps.sh discover)}"

if [ "$MODE" = "home" ] && [ "${CONFIRM_HOMEPAGE:-}" != "yes" ]; then
  echo "REFUSING: MODE=home replaces the live homepage. Set CONFIRM_HOMEPAGE=yes to proceed." >&2
  exit 2
fi

TARGET="$DOCROOT"
case "$MODE" in
  store) TARGET="$DOCROOT/store" ;;
  exact) # DOCROOT is already the folder served at /store/ (e.g. /opt/redmed-store/site)
    [ -n "${SUBDIR:-}" ] && TARGET="$DOCROOT/$SUBDIR" ;;
esac

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

# Stage: init.html becomes index.html. No --delete anywhere.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp store.css store.js theme.js config.js "$STAGE/"
cp init.html "$STAGE/index.html"
# Preview copies must not compete with the live page in search: drop canonical/og:url, add noindex.
if [ -n "${SUBDIR:-}" ]; then
  sed -E -i.bak -e '/<link rel="canonical"/d' -e '/property="og:url"/d' -e 's|<title>|<meta name="robots" content="noindex, nofollow">\n<title>|' "$STAGE/index.html"
  rm -f "$STAGE/index.html.bak"
fi
mkdir -p "$STAGE/assets"
grep -o 'assets/[A-Za-z0-9_.@-]*' init.html | sort -u | while read -r a; do cp "$a" "$STAGE/assets/"; done

if [ "$CMD" = "compare" ]; then
  # Read-only: is the live store already this page? Compare staged files to what is served now.
  echo "Remote contents of $DOCROOT:"
  "${SSH[@]}" "ls -la '$DOCROOT' | head -40; echo; echo 'has init.html:'; test -f '$DOCROOT/init.html' && echo yes || echo no; echo 'has index.html:'; test -f '$DOCROOT/index.html' && echo yes || echo no"
  echo; echo "Staged vs live (SAME / DIFFERENT / ABSENT):"
  ( cd "$STAGE" && find . -type f | sed 's|^\./||' | sort ) | while read -r f; do
    l="$(shasum -a 256 "$STAGE/$f" | cut -d' ' -f1)"
    r="$("${SSH[@]}" "sha256sum '$DOCROOT/$f' 2>/dev/null | cut -d' ' -f1")"
    if [ -z "$r" ]; then st=ABSENT; elif [ "$r" = "$l" ]; then st=SAME; else st=DIFFERENT; fi
    printf '  %-10s %s\n' "$st" "$f"
  done
  echo; echo "Also compare live index.html to staged init.html:"
  r="$("${SSH[@]}" "sha256sum '$DOCROOT/init.html' 2>/dev/null | cut -d' ' -f1")"
  l="$(shasum -a 256 init.html | cut -d' ' -f1)"
  if [ -z "$r" ]; then echo "  live init.html: ABSENT"; elif [ "$r" = "$l" ]; then echo "  live init.html: SAME"; else echo "  live init.html: DIFFERENT"; fi
  exit 0
fi

if [ "$CMD" = "dry-run" ]; then
  rsync -avn -e "ssh -o BatchMode=yes" "$STAGE/" "$REMOTE:$TARGET/"
  exit 0
fi

STAMP="$(date +%Y%m%d%H%M%S)"
"${SSH[@]}" "test -d '$TARGET' && tar czf /root/redmed-backup-$STAMP.tgz -C '$TARGET' . || mkdir -p '$TARGET'"
echo "Backup: /root/redmed-backup-$STAMP.tgz (if target existed)"
rsync -av -e "ssh -o BatchMode=yes" "$STAGE/" "$REMOTE:$TARGET/"

# Smoke test
URL="$SITE/"
[ "$MODE" = "store" ] && URL="$SITE/store/"
[ "$MODE" = "exact" ] && URL="$SITE/store/${SUBDIR:+$SUBDIR/}"
code="$(curl -s -o /dev/null -w '%{http_code}' "$URL")"
echo "GET $URL -> $code"
[ "$code" = "200" ] || { echo "Smoke test failed. Roll back: ssh $REMOTE 'tar xzf /root/redmed-backup-$STAMP.tgz -C $TARGET'" >&2; exit 4; }
for a in $(grep -o 'assets/[A-Za-z0-9_.@-]*' init.html | sort -u); do
  c="$(curl -s -o /dev/null -w '%{http_code}' "$URL$a")"; echo "  $a -> $c"
done
