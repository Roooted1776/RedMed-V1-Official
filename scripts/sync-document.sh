#!/usr/bin/env bash
# Keep hosted /Document/ lockstep with the in-app Help source of truth.
# Authoring source: Roooted1776/RedMed-iOS owner/RedMed/Document/.
# Host:   Document/index.html (full policy) + Document.html (thin #hash redirect)
#         + legal-doc.css. If the iOS tree is not beside this script, the
#         hosted copy in this repo is what redmed.live serves.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SRC=owner/RedMed/Document
DST=Document
mkdir -p "$DST"

# Authoring source lives in the iOS repo. When that tree is checked out beside
# this script, refresh the hosted copy. Otherwise the hosted Document/index.html
# in this repo is what redmed.live serves.
if [[ -f "$SRC/Document.html" && -f "$SRC/legal-doc.css" ]]; then
  cp "$SRC/Document.html" "$DST/index.html"
  cp "$SRC/legal-doc.css" "$DST/legal-doc.css"
fi
test -f "$DST/index.html"
test -f "$DST/legal-doc.css"

# Hosted Document.html is a stub so /Document/Document.html and /Document/
# stay one policy tree (index.html), not two full copies that can drift.
cat > "$DST/Document.html" <<'EOF'
<!doctype html>
<html lang="en-US">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<meta name="theme-color" content="#fff7f7">
<meta name="referrer" content="no-referrer">
<meta http-equiv="refresh" content="0;url=./">
<link rel="canonical" href="./">
<title>RedMed Policies</title>
<script>
(function () {
  location.replace("./" + (location.search || "") + (location.hash || ""));
})();
</script>
</head>
<body style="margin:0;background:#fff7f7;font:17px/1.5 -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#1c1917">
<main style="max-width:40rem;margin:0 auto;padding:1.5rem 1.25rem">
  <p>Policies live at <a id="go" href="./">/Document/</a> (same text as in-app Help → Policies).</p>
  <script>
    document.getElementById("go").href = "./" + (location.search || "") + (location.hash || "");
  </script>
</main>
</body>
</html>
EOF

# Hosted index must point passerby card at /tapper/ (not a local tapper.html).
grep -q 'href="/tapper/"' "$DST/index.html"
grep -q 'href="legal-doc.css"' "$DST/index.html"
grep -q 'data-tab="medical"' "$DST/index.html" && {
  echo "FAIL hosted Document/index.html looks like tapper shell" >&2
  exit 1
}
# Stub must not contain the full policy body.
! grep -q 'Automatic crash / severe-impact alarm' "$DST/Document.html"
grep -q 'location.replace("./"' "$DST/Document.html"

# privacy/ is a bounce to Document — never a second policy tree.
grep -q '/Document/' privacy/index.html

# Honesty trio (audit P2/P3/P4): Help/Document must not cite the empty-file
# era, HIPAA heading must not look like a badge, versions lockstep with consent.
# Legal body is not rewritten here — these are fail-closed greps.
SRC_HTML="$DST/index.html"
if grep -q 'docs/SECURITY.md' "$SRC_HTML"; then
  echo "FAIL $SRC_HTML still cites docs/SECURITY.md — point at Help → Security, not the pointer file" >&2
  exit 1
fi
if grep -q 'HIPAA alignment (operator)' "$SRC_HTML"; then
  echo "FAIL $SRC_HTML HIPAA heading still says alignment (operator)" >&2
  exit 1
fi
grep -q 'HIPAA — not a covered entity' "$SRC_HTML" || {
  echo "FAIL $SRC_HTML missing Security heading HIPAA — not a covered entity" >&2
  exit 1
}
grep -q 'signed-in wearer copy' "$SRC_HTML" || {
  echo "FAIL $SRC_HTML missing signed-in wearer copy disclosure" >&2
  exit 1
}
grep -q 'Supabase' "$SRC_HTML" || {
  echo "FAIL $SRC_HTML missing Supabase disclosure" >&2
  exit 1
}
grep -q 'tap page does not look the profile up' "$SRC_HTML" || {
  echo "FAIL $SRC_HTML missing tap-page disclosure" >&2
  exit 1
}
grep -q 'public fragment' "$SRC_HTML" || {
  echo "FAIL $SRC_HTML missing public fragment disclosure" >&2
  exit 1
}
grep -q 'not a HIPAA certification' "$SRC_HTML" || {
  echo "FAIL $SRC_HTML missing not-a-HIPAA-certification line" >&2
  exit 1
}
if [[ -f owner/RedMed/ConsentGateView.swift ]]; then
  CONSENT="$(sed -n 's/^[[:space:]]*static let currentVersion = "\([^"]*\)".*/\1/p' owner/RedMed/ConsentGateView.swift)"
else
  CONSENT="$(python3 -c 'import json; print(json.load(open("contracts/d-codec-fixtures.json"))["consentVersion"])')"
fi
if [[ -z "$CONSENT" ]]; then
  echo "FAIL could not read consent version" >&2
  exit 1
fi
if grep -E '<strong>Version</strong> ' "$SRC_HTML" | grep -vqF "$CONSENT"; then
  echo "FAIL Document Version line != consent $CONSENT" >&2
  grep -E '<strong>Version</strong> ' "$SRC_HTML" >&2
  exit 1
fi
VERSION_N="$(grep -cE '<strong>Version</strong> ' "$SRC_HTML" || true)"
if [[ "$VERSION_N" -lt 5 ]]; then
  echo "FAIL expected ≥5 Document Version lines, got $VERSION_N" >&2
  exit 1
fi
if ! grep -q 'Document.html' docs/SECURITY.md || ! grep -q '#security' docs/SECURITY.md; then
  echo "FAIL docs/SECURITY.md must stay a pointer into Document.html #security (do not restore the old dump)" >&2
  exit 1
fi
if grep -qiE 'HIPAA certified|HIPAA-aligned product|HIPAA compliant' docs/SECURITY.md; then
  echo "FAIL docs/SECURITY.md grew a HIPAA badge — keep it a pointer" >&2
  exit 1
fi

if [[ -f "$SRC/Document.html" ]]; then
  echo "OK Document host lockstep with $SRC (index=full, Document.html=redirect; consent $CONSENT)"
else
  echo "OK hosted Document/index.html (iOS authoring tree not checked out; consent $CONSENT)"
fi
