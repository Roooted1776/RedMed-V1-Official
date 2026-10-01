#!/usr/bin/env bash
# Stage the public Assist site into dist/passerby for Hostinger static deploy.
# Keeps owner / docs / scripts out of the upload.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="dist/passerby"
rm -rf "$OUT"
mkdir -p "$OUT"

copy() {
  local src="$1"
  if [[ -e "$src" ]]; then
    mkdir -p "$OUT/$(dirname "$src")"
    cp -a "$src" "$OUT/$src"
  else
    echo "missing required path: $src" >&2
    exit 1
  fi
}

copy _headers
copy _redirects
copy favicon.svg
copy card.html
copy get.html
copy tapper.html
copy redmed-emergency.html
copy sw.js
copy apple-app-site-association
copy tapper
copy assets
copy get
copy Document
copy privacy
copy support
copy store
copy .well-known
# Hostinger Apache AASA Content-Type (CF _headers is ignored on origin)
if [[ -f .htaccess ]]; then
  cp -a .htaccess "$OUT/.htaccess"
fi

# Website source of truth is init.html (parked/ holds the old root stub).
# Static hosts serve / as index.html — emit it only in the stage tree.
test -f init.html || { echo "missing init.html (website source)" >&2; exit 1; }
for f in store.css store.js theme.js config.js; do
  test -f "$f" || { echo "missing $f (required by init.html)" >&2; exit 1; }
  cp -a "$f" "$OUT/$f"
done
cp -a init.html "$OUT/index.html"
cp -a init.html "$OUT/init.html"

# Sanity: Aid tab present, no NFC tab.
SHELL="$OUT/tapper/index.html"
grep -q 'id="tab-aid"' "$SHELL" || { echo "$SHELL missing tab-aid" >&2; exit 1; }
! grep -q 'id="tab-nfc"' "$SHELL" || { echo "$SHELL has NFC tab" >&2; exit 1; }

echo "Staged $(find "$OUT" -type f | wc -l | tr -d ' ') files → $OUT (website from init.html)"
