#!/usr/bin/env bash
# Read-only checks for redmed.live behind Cloudflare. Nothing here changes anything.
#   scripts/verify-cloudflare.sh --pre    # before the nameserver change: mail + site records are intact
#   scripts/verify-cloudflare.sh          # after: proxied, cached, nothing injected, tap page not challenged
# Exit 0 = all checks passed. See docs/cloudflare.md.
set -uo pipefail

HOST="${HOST:-redmed.live}"
ORIGIN_IP="${ORIGIN_IP:-2.25.249.204}"
PRE=0; [ "${1:-}" = "--pre" ] && PRE=1
fail=0
ok()   { printf 'OK    %s\n' "$1"; }
bad()  { printf 'FAIL  %s\n' "$1"; fail=$((fail+1)); }
note() { printf 'NOTE  %s\n' "$1"; }
hdr()  { curl -sI -H 'Accept-Encoding: gzip, br' "$1" 2>/dev/null; }
get()  { curl -s -H 'Accept-Encoding: identity' "$1" 2>/dev/null; }

# --- DNS records that must survive the move (mail first: a missing record silently breaks email)
mx="$(dig +short MX "$HOST")"
echo "$mx" | grep -qi 'mx1.hostinger.com' && echo "$mx" | grep -qi 'mx2.hostinger.com' && ok "MX records (Hostinger mail)" || bad "MX records missing"
dig +short TXT "$HOST" | grep -q 'include:_spf.mail.hostinger.com' && ok "SPF record" || bad "SPF record missing"
dig +short TXT "_dmarc.$HOST" | grep -q 'v=DMARC1' && ok "DMARC record" || bad "DMARC record missing"
for s in a b c; do
  dig +short CNAME "hostingermail-$s._domainkey.$HOST" | grep -q "hostingermail-$s.dkim.mail.hostinger.com" \
    && ok "DKIM hostingermail-$s" || bad "DKIM hostingermail-$s missing"
done
for h in "$HOST" "www.$HOST"; do
  [ -n "$(dig +short A "$h")" ] && ok "A record resolves: $h" || bad "no A record: $h"
done

if [ "$PRE" = 1 ]; then
  echo; [ "$fail" -eq 0 ] && echo "Records look right. Safe to compare against Cloudflare's imported list." || echo "$fail check(s) failed."
  exit "$fail"
fi

# --- Is Cloudflare actually in front?
dig +short NS "$HOST" | grep -qi 'ns.cloudflare.com' && ok "nameservers are Cloudflare" || bad "nameservers are not Cloudflare yet"
for h in "$HOST" "www.$HOST"; do
  ips="$(dig +short A "$h")"
  if echo "$ips" | grep -q "^$ORIGIN_IP$"; then bad "$h still resolves to the origin IP (not proxied)"; else ok "$h resolves to a Cloudflare address"; fi
done

for p in / /store/ /tapper/; do
  h="$(hdr "https://$HOST$p")"
  echo "$h" | grep -qi '^cf-ray:' && ok "served through Cloudflare: $p" || bad "no cf-ray on $p"
  echo "$h" | head -1 | grep -q ' 200' && ok "200 OK: $p" || bad "$p did not return 200 ($(echo "$h" | head -1 | tr -d '\r'))"
done

# --- Nothing injected, nothing challenged (product wall: no trackers, no script rewriting)
for p in / /store/ /tapper/; do
  body="$(get "https://$HOST$p")"
  if echo "$body" | grep -qiE 'cloudflareinsights|rocket-loader|email-decode|/cdn-cgi/(scripts|challenge)|cf-challenge|Just a moment'; then
    bad "Cloudflare injected or challenged on $p"
  else ok "no injected script, no challenge: $p"; fi
done
hdr "https://$HOST/" | grep -qi '^content-security-policy:' && ok "CSP header still reaches visitors" || bad "CSP header missing on /"

# --- Caching: media cached, pages and the tap page's service worker never cached
m="https://$HOST/assets/hero-hd.mp4"
hdr "$m" >/dev/null; st="$(hdr "$m" | grep -i '^cf-cache-status:' | awk '{print toupper($2)}' | tr -d '\r')"
[ "$st" = "HIT" ] && ok "media is cached at the edge (hero-hd.mp4)" || bad "media not a cache HIT (got: ${st:-none})"
for p in / /tapper/ /tapper/sw.js; do
  st="$(hdr "https://$HOST$p" | grep -i '^cf-cache-status:' | awk '{print toupper($2)}' | tr -d '\r')"
  case "$st" in HIT|REVALIDATED) bad "$p is being cached ($st)";; *) ok "$p is not cached (${st:-no status})";; esac
done

# --- Compression and HTTPS
enc="$(hdr "https://$HOST/assets/index-persist-admin.js" | grep -i '^content-encoding:' | awk '{print tolower($2)}' | tr -d '\r')"
case "$enc" in br|gzip) ok "text is compressed ($enc)";; *) bad "text not compressed (home bundle)";; esac
loc="$(curl -sI "http://$HOST/" | grep -i '^location:' | tr -d '\r')"
echo "$loc" | grep -qi 'https://' && ok "http redirects to https" || bad "http does not redirect to https"
hdr "https://$HOST/" | grep -qi '^strict-transport-security:' && ok "HSTS present" || note "HSTS not on yet (turn it on after a week; docs/cloudflare.md)"

# --- Range requests (click-to-seek in the home video)
rc="$(curl -s -o /dev/null -w '%{http_code}' -H 'Range: bytes=0-99' "https://$HOST/assets/how-it-works.webm")"
[ "$rc" = "206" ] && ok "range requests answered (206): video seeking can work" || note "range request returned $rc: click-to-seek stays off until the origin or edge sends 206"

echo; [ "$fail" -eq 0 ] && echo "All checks passed." || echo "$fail check(s) failed."
exit "$fail"
