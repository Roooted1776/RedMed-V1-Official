#!/usr/bin/env bash
# Print V1 go-live checklist + run in-repo gates. Does not mutate DNS/hosting.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== In-repo gates =="
bash scripts/sync-tapper.sh
node scripts/test-d-codec.mjs
node scripts/test-sw-offline.mjs
node scripts/test-product-independence.mjs
bash scripts/stage-site.sh
test -f dist/passerby/.htaccess

echo
echo "== Max / secrets (agent cannot finish without these) =="
cat <<'EOF'
1. Do not upload dist/passerby onto redmed.live /. That replaces the live marketing homepage. The deploy script refuses unless REDMED_ALLOW_HOMEPAGE_REPLACE=1 (docs/domain.md). Assist is already at /tapper/ on the VPS.
2. CLOUDFLARE_API_TOKEN → node scripts/setup-cloudflare-dns.mjs redmed.live
3. Namecheap → Custom DNS → Cloudflare NS (DNSSEC off first)
4. bash scripts/verify-cf-dns-cutover.sh
5. BASE=https://redmed.live bash scripts/smoke-pages.sh
6. scripts/mirror-to-v1.sh   # if Cloud Agent cannot git-push V1
7. CI secrets on RedMed-V1-Official: HOSTINGER_API_TOKEN, CLOUDFLARE_API_TOKEN
8. Paid Apple Program → docs/release/OWNER-PARKED.md / NFC-RESTORE / associated-domains-restore
9. Connect Privacy URL = https://redmed.live/Document/  (docs/release/APP-STORE.md)
EOF
