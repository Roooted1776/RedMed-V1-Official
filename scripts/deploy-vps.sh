#!/usr/bin/env bash
# Deploy RedMed static surfaces to the Hostinger VPS.
# Website only. The iOS app in this repo is not touched. tapper/ is never copied.
#
# File split (do not cross these):
#   home  — home/index.html → DOCROOT/index.html   (https://redmed.live/)
#           Requires CONFIRM_HOMEPAGE=yes. Never writes init.html.
#   store — store/index.html → DOCROOT/store/init.html (https://redmed.live/store/)
#           Never writes index.html. /store/ is served from init.html.
#
# Usage:
#   scripts/deploy-vps.sh discover                 # read-only: find the docroot
#   DOCROOT=/opt/redmed-store/site MODE=exact scripts/deploy-vps.sh compare   # read-only: staged vs live
#   DOCROOT=/path scripts/deploy-vps.sh dry-run    # show what would change
#   DOCROOT=/path scripts/deploy-vps.sh deploy     # back up, then copy to <docroot>/store/
#   DOCROOT=/opt/redmed-store/site MODE=exact SUBDIR=preview scripts/deploy-vps.sh deploy
#                                                  # additive: serves at /store/preview/, live /store untouched
#   DOCROOT=/path MODE=store scripts/deploy-vps.sh dry-run
#   DOCROOT=/path MODE=store scripts/deploy-vps.sh deploy
#   DOCROOT=/path MODE=home CONFIRM_HOMEPAGE=yes scripts/deploy-vps.sh deploy
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

SSH=(ssh -n -o BatchMode=yes -o ConnectTimeout=10 "$REMOTE")

case "$CMD" in
  discover)
    "${SSH[@]}" 'hostname; echo "--- containers ---"; docker ps --format "{{.Names}}  {{.Image}}  {{.Ports}}"; echo "--- mounts ---"; docker ps -q | xargs -r docker inspect -f "{{.Name}}: {{range .Mounts}}{{.Source}} -> {{.Destination}}; {{end}}"; echo "--- traefik host rules ---"; docker ps -q | xargs -r docker inspect -f "{{.Name}}: {{json .Config.Labels}}" | grep -o "Host([^)]*)"'
    exit 0 ;;
  dry-run|deploy|compare) ;;
  *) sed -n '2,18p' "$0"; exit 1 ;;
esac

: "${DOCROOT:?Set DOCROOT (run: scripts/deploy-vps.sh discover)}"

if [ "$MODE" != "home" ] && [ "$MODE" != "store" ] && [ "$MODE" != "exact" ]; then
  echo "MODE must be home, store or exact (got: $MODE)" >&2
  exit 2
fi

if [ "$MODE" = "home" ] && [ "${CONFIRM_HOMEPAGE:-}" != "yes" ]; then
  echo "REFUSING: MODE=home replaces the live homepage (Sign in / Create account). Set CONFIRM_HOMEPAGE=yes to proceed." >&2
  exit 2
fi

TARGET="$DOCROOT"
case "$MODE" in
  store) TARGET="$DOCROOT/store" ;;
  exact) # DOCROOT is already the folder served at /store/ (e.g. /opt/redmed-store/site)
    [ -n "${SUBDIR:-}" ] && TARGET="$DOCROOT/$SUBDIR" ;;
esac

if [ "$CMD" = "deploy" ] && [ "${ALLOW_BEHIND:-}" != "yes" ]; then
  behind="$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)"
  if [ "$behind" -gt 0 ]; then
    echo "REFUSING: local tree is $behind commit(s) behind origin/main. Run: git pull --rebase origin main" >&2
    exit 5
  fi
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
if [ "$MODE" = "home" ]; then
  # Home page file is index.html. Never stage the store page here.
  for f in home/index.html home/legacy.js home/hero.js home/theme.js home/process.js assets/hero-hd.mp4 assets/hero-mobile.mp4 assets/how-it-works.webm assets/how-it-works.mp4 assets/how-it-works-poster.jpg assets/band-spin-poster.jpg assets/Band.webp; do
    [ -f "$f" ] || { echo "MISSING $f" >&2; exit 3; }
  done
  [ -d home/assets ] || { echo "MISSING home/assets/" >&2; exit 3; }
  cp home/index.html "$STAGE/index.html"
  cp home/red-white.css "$STAGE/red-white.css"
  cp home/legacy.js "$STAGE/legacy.js"
  cp home/hero.js "$STAGE/hero.js"
  cp home/theme.js "$STAGE/theme.js"
  cp home/process.js "$STAGE/process.js"
  [ -f home/favicon.svg ] && cp home/favicon.svg "$STAGE/"
  [ -f home/band-hero.webp ] && cp home/band-hero.webp "$STAGE/"
  [ -f home/nfc-detail.webp ] && cp home/nfc-detail.webp "$STAGE/"
  mkdir -p "$STAGE/assets"
  cp -a home/assets/. "$STAGE/assets/"
  cp assets/hero-hd.mp4 assets/hero-mobile.mp4 assets/how-it-works.webm assets/how-it-works.mp4 assets/how-it-works-poster.jpg assets/band-spin-poster.jpg assets/Band.webp "$STAGE/assets/"
  grep -q 'id="auth-form"' "$STAGE/index.html" || { echo "home/index.html missing auth-form" >&2; exit 3; }
  grep -q 'hero-hd.mp4' "$STAGE/index.html" || { echo "home/index.html missing hero-hd.mp4" >&2; exit 3; }
  grep -q 'autoplay' "$STAGE/index.html" || { echo "home/index.html hero video is not set to autoplay" >&2; exit 3; }
  if [ -e "$STAGE/init.html" ]; then
    echo "REFUSING: home deploy must not write init.html (that file is the store)" >&2
    exit 3
  fi
elif [ "$MODE" = "store" ] || [ "$MODE" = "exact" ]; then
  # Store page source is store/index.html. It ships as init.html because the live
  # nginx opens init.html for /store/. Never stage the home page here.
  FILES=(store/index.html store/store.css store/store.js store/theme.js store/config.js)
  missing=0
  for f in "${FILES[@]}"; do
    [ -f "$f" ] || { echo "MISSING $f" >&2; missing=1; }
  done
  # Relative assets live in store/assets/. Absolute /assets/ files (the hero films) are
  # served by the home site, so MODE=home must be deployed first; they are only checked here.
  while read -r a; do
    [ -f "store/$a" ] || [ -f "$a" ] || { echo "MISSING $a (referenced by store/index.html)" >&2; missing=1; }
  done < <(grep -o 'assets/[A-Za-z0-9_.@-]*' store/index.html | sort -u)
  [ "$missing" -eq 0 ] || { echo "Fix missing files, then rerun." >&2; exit 3; }
  cp store/store.css store/store.js store/theme.js store/config.js "$STAGE/"
  PAGE=init.html
  cp store/index.html "$STAGE/$PAGE"
  if [ "$MODE" = "exact" ] || [ -n "${SUBDIR:-}" ]; then
    sed -E -i.bak -e '/<link rel="canonical"/d' -e '/property="og:url"/d' -e 's|<title>|<meta name="robots" content="noindex, nofollow">\n<title>|' "$STAGE/$PAGE"
    rm -f "$STAGE/$PAGE.bak"
  fi
  mkdir -p "$STAGE/assets"
  # Only files under store/assets are copied; /assets/hero-*.mp4 come from the home deploy.
  grep -o '[^/]assets/[A-Za-z0-9_.@-]*' store/index.html | sed 's/^.//' | sort -u | while read -r a; do
    [ -f "store/$a" ] && cp "store/$a" "$STAGE/assets/"
  done
  if [ -e "$STAGE/index.html" ]; then
    echo "REFUSING: store deploy must not write index.html (that file is the home page)" >&2
    exit 3
  fi
fi

# Quote these. An unquoted tapper/** is a shell glob and rsync then
# copies the Assist shell onto the page being deployed.
if [ "$MODE" = "store" ] || [ "$MODE" = "exact" ]; then
  RSYNC_EXCLUDE=(--exclude 'index.html' --exclude 'tapper' --exclude 'tapper/**')
else
  RSYNC_EXCLUDE=(--exclude 'init.html' --exclude 'tapper' --exclude 'tapper/**')
fi

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
  l="$(shasum -a 256 store/index.html | cut -d' ' -f1)"
  if [ -z "$r" ]; then echo "  live init.html: ABSENT"; elif [ "$r" = "$l" ]; then echo "  live init.html: SAME"; else echo "  live init.html: DIFFERENT"; fi
  exit 0
fi

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

# Smoke test
BASE="$SITE/"
PAGE="$BASE"
[ "$MODE" = "home" ] && PAGE="$SITE/" && BASE="$SITE/"
[ "$MODE" = "store" ] && BASE="$SITE/store/" && PAGE="${BASE}init.html"
[ "$MODE" = "exact" ] && BASE="$SITE/store/${SUBDIR:+$SUBDIR/}" && PAGE="${BASE}init.html"
code="$(curl -s -o /dev/null -w '%{http_code}' "$PAGE")"
echo "GET $PAGE -> $code"
[ "$code" = "200" ] || { echo "Smoke test failed. Roll back: ssh $REMOTE 'tar xzf /root/redmed-backup-$STAMP.tgz -C $TARGET'" >&2; exit 4; }
if [ "$MODE" = "home" ]; then
  body="$(curl -sL "$PAGE")"
  echo "$body" | grep -q 'Create account' || { echo "Smoke: homepage missing Create account" >&2; exit 4; }
  echo "$body" | grep -q 'Sign in' || { echo "Smoke: homepage missing Sign in" >&2; exit 4; }
  echo "$body" | grep -q 'RedMed Band | Store' && { echo "Smoke: homepage is the store page" >&2; exit 4; }
  echo "OK homepage index.html"
else
  # /store/ must open init.html. Do not rewrite index.html to get there.
  "${SSH[@]}" 'docker exec redmed-store sh -c "grep -q \"index init.html\" /etc/nginx/conf.d/default.conf || sed -i \"s|location /store/ { try_files|location /store/ { index init.html; try_files|\" /etc/nginx/conf.d/default.conf; nginx -t && nginx -s reload"'
  store_open="$(curl -sL "${BASE}")"
  echo "$store_open" | grep -q 'RedMed Band | Store' || { echo "Smoke: /store/ did not open init.html" >&2; exit 4; }
  echo "$store_open" | grep -q 'id="auth-form"' && { echo "Smoke: /store/ is the home page" >&2; exit 4; }
  echo "OK /store/ opens init.html"
  for a in $(grep -o '[^/]assets/[A-Za-z0-9_.@-]*' store/index.html | sed 's/^.//' | sort -u); do
    c="$(curl -s -o /dev/null -w '%{http_code}' "$BASE$a")"; echo "  $a -> $c"
  done
fi
