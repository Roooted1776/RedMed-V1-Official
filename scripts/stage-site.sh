#!/usr/bin/env bash
# Stage the public Assist site into dist/passerby for Hostinger static deploy.
# Keeps owner / docs / scripts out of the upload.
#
# /          ← home/ (Sign in / Create account / Supabase email links — keep)
# /store/    ← store/ (+ init.html storefront assets at root for that page)
# /tapper/   ← Assist shell
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

# Landing / = home/ (member portal: Supabase sign-in, signup, email-link verify).
# Do not replace this with init.html — init is the storefront only.
test -f home/index.html || { echo "missing home/index.html (landing + auth)" >&2; exit 1; }
test -f home/legacy.js || { echo "missing home/legacy.js" >&2; exit 1; }
test -f home/hero.js || { echo "missing home/hero.js" >&2; exit 1; }
test -f assets/hero-hd.mp4 || { echo "missing assets/hero-hd.mp4" >&2; exit 1; }
test -f assets/hero-mobile.mp4 || { echo "missing assets/hero-mobile.mp4" >&2; exit 1; }
test -f home/theme.js || { echo "missing home/theme.js" >&2; exit 1; }
test -f home/process.js || { echo "missing home/process.js" >&2; exit 1; }
for f in how-it-works.webm how-it-works.mp4 how-it-works-poster.jpg band-spin-poster.jpg Band.webp; do test -f "assets/$f" || { echo "missing assets/$f" >&2; exit 1; }; done
test -d home/assets || { echo "missing home/assets/" >&2; exit 1; }
cp -a home/index.html "$OUT/index.html"
cp -a home/red-white.css "$OUT/red-white.css"
cp -a home/legacy.js "$OUT/legacy.js"
cp -a home/hero.js "$OUT/hero.js"
cp -a home/theme.js "$OUT/theme.js"
cp -a home/process.js "$OUT/process.js"
cp -a home/favicon.svg "$OUT/favicon.svg" 2>/dev/null || true
cp -a home/band-hero.webp home/nfc-detail.webp "$OUT/" 2>/dev/null || true
mkdir -p "$OUT/assets"
cp -a home/assets/. "$OUT/assets/"
# Hero film lives in repo assets/ (copied above). Keep it if a later merge replaces the folder.
test -f "$OUT/assets/herovideo.MP4" || cp -a assets/herovideo.MP4 "$OUT/assets/herovideo.MP4"
for f in hero-hd.mp4 hero-mobile.mp4 how-it-works.webm how-it-works.mp4 how-it-works-poster.jpg band-spin-poster.jpg Band.webp; do test -f "$OUT/assets/$f" || cp -a "assets/$f" "$OUT/assets/$f"; done

# Storefront source init.html (also under /store/ via store/). Parked stub stays out.
test -f init.html || { echo "missing init.html (storefront)" >&2; exit 1; }
for f in store.css store.js theme.js config.js; do
  test -f "$f" || { echo "missing $f (required by init.html)" >&2; exit 1; }
  cp -a "$f" "$OUT/$f"
done
cp -a init.html "$OUT/init.html"

# Sanity: Aid tab present, no NFC tab.
SHELL="$OUT/tapper/index.html"
grep -q 'id="tab-aid"' "$SHELL" || { echo "$SHELL missing tab-aid" >&2; exit 1; }
! grep -q 'id="tab-nfc"' "$SHELL" || { echo "$SHELL has NFC tab" >&2; exit 1; }
# Sanity: landing kept the Supabase auth UI
grep -q 'id="auth-form"' "$OUT/index.html" || { echo "staged / missing auth-form (home/ Sign in)" >&2; exit 1; }
grep -q 'Create account' "$OUT/index.html" || { echo "staged / missing Create account" >&2; exit 1; }
grep -q 'id="hero-video"' "$OUT/index.html" || { echo "staged / missing hero video" >&2; exit 1; }
grep -q 'herovideo.MP4' "$OUT/index.html" || { echo "staged / hero is not herovideo.MP4" >&2; exit 1; }
grep -q 'autoplay' "$OUT/index.html" || { echo "staged / hero video is not set to autoplay" >&2; exit 1; }
! grep -q 'id="auth-form"' "$OUT/init.html" || { echo "init.html must not be the auth portal" >&2; exit 1; }

echo "Staged $(find "$OUT" -type f | wc -l | tr -d ' ') files → $OUT (/ from home/, storefront init.html)"
