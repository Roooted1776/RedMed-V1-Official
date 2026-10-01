# Cloudflare in front of `redmed.live`

Status: **approved by the Owner on 2026-10-01, not yet switched on.** Until the nameservers change at
Namecheap, `docs/domain.md` still describes the live setup (Namecheap DNS straight to the VPS).

This replaces the abandoned 2026-09-28 plan. Do not use `scripts/setup-cloudflare-dns.mjs`: it targets a
Hostinger static plan that does not exist. The origin is the VPS (`2.25.249.204`): Traefik, then the
`redmed-portal-live` container (home, `/assets/`, `/tapper/`) and the `redmed-store` nginx container (`/store/`).

## What Cloudflare is for here
- Cache the big, never-changing media near visitors: `/assets/*.mp4`, `.webm`, images.
- Compression (Brotli) for text files. The home server sends none today.
- HSTS and a standard HTTPS posture. DDoS and bot absorption for the VPS.
- It is **not** an app host. Do not add a Worker, Pages, Access, Web Analytics or any script injection.

## Product wall (read first)
- A `#d=` fragment is never sent to any server, so Cloudflare cannot see it. That part is safe.
- Everything else Cloudflare can see: paths and query strings. Keep profile data out of query strings (already the rule).
- Never turn on anything that injects JS or rewrites HTML: Web Analytics / Browser Insights, Rocket Loader,
  Email Address Obfuscation, Auto Minify, Mirage, Polish lossy, Zaraz. The pages have a strict CSP
  (`script-src 'self'`) and `tapper/` must stay tracker-free (`scripts/smoke-pages.sh`).
- `/tapper/*` must load instantly for a stranger holding a phone to a band. No challenges, no interstitials.
- Do not add Workers or Transform Rules that read, log, or store request data.

## Records to recreate (checked 2026-10-01)
Cloudflare normally imports these when you add the site. Check every line against this table.

| Type | Name | Value | Proxy |
| --- | --- | --- | --- |
| A | `@` | `2.25.249.204` | **Proxied** |
| A | `www` | `2.25.249.204` | **Proxied** |
| MX | `@` | `mx1.hostinger.com` (5), `mx2.hostinger.com` (10) | DNS only |
| TXT | `@` | `v=spf1 include:_spf.mail.hostinger.com ~all` | DNS only |
| TXT | `_dmarc` | `v=DMARC1; p=none` | DNS only |
| CNAME | `hostingermail-a._domainkey` | `hostingermail-a.dkim.mail.hostinger.com` | DNS only |
| CNAME | `hostingermail-b._domainkey` | `hostingermail-b.dkim.mail.hostinger.com` | DNS only |
| CNAME | `hostingermail-c._domainkey` | `hostingermail-c.dkim.mail.hostinger.com` | DNS only |

Email (`help@redmed.live`) breaks if any mail record is missing or proxied. Mail records are never orange-clouded.
There is no `AAAA` record and no `CAA` record. `mcp.redmed.live` has a Traefik rule but no DNS record: leave it out.

## Cutover steps (Owner does steps 1, 2, 8 in their own accounts)
1. Cloudflare dashboard: **Add a site** `redmed.live`, Free plan.
2. Review the imported records against the table above. Fix the proxy column.
3. Before changing nameservers, set **SSL/TLS = Full (strict)**. The origin already has a valid Let's Encrypt certificate.
4. Settings below (Speed, Caching, Security). Leave HSTS off for now.
5. Create the Cache Rules and the one Configuration Rule below.
6. In Namecheap: Domain > Nameservers > **Custom DNS**, paste the two Cloudflare nameservers.
7. Wait until Cloudflare shows the site **Active**. Then run `bash scripts/verify-cloudflare.sh`.
8. After a week with no issues: enable **HSTS** (6 months, no preload, `includeSubDomains` off), and **DNSSEC**
   (add the DS record Cloudflare shows at Namecheap).

Rollback at any point: Namecheap > Nameservers > **Namecheap BasicDNS**, and recreate the table above there.

## Settings
| Area | Setting | Value |
| --- | --- | --- |
| SSL/TLS | Mode | Full (strict) |
| SSL/TLS | Always Use HTTPS | On |
| SSL/TLS | Minimum TLS | 1.2 |
| SSL/TLS | TLS 1.3 | On |
| SSL/TLS | Automatic HTTPS Rewrites | On |
| Network | HTTP/2, HTTP/3 | On |
| Network | WebSockets | Off (not used) |
| Speed | Brotli | On |
| Speed | Early Hints | On |
| Speed | Rocket Loader | **Off** |
| Speed | Auto Minify | **Off** |
| Speed | Polish / Mirage | Off |
| Caching | Browser Cache TTL | **Respect existing headers** |
| Caching | Always Online | Off |
| Caching | Tiered Cache | On (Smart) |
| Security | Security Level | Low |
| Security | Bot Fight Mode | **Off** (it can challenge a responder's phone) |
| Security | Browser Integrity Check | Off for `/tapper/*` (see rule below), otherwise On |
| Scrape Shield | Email Address Obfuscation | **Off** (rewrites `mailto:` and injects a script) |
| Scrape Shield | Hotlink Protection | Off |
| Analytics | Web Analytics (RUM) | **Off** |
| Network | Pseudo IPv4 / Onion Routing | Off / On |

## Rules
Order matters. Create them under Rules > Cache Rules / Configuration Rules.

1. **Cache media forever** — if URI Path starts with `/assets/` **and** the path ends with one of
   `.mp4 .webm .webp .jpg .jpeg .png`: Eligible for cache, Edge TTL **1 year**, Browser TTL **respect origin**.
   Media is `immutable` at the origin under fixed names. To replace a file, **use a new file name** (or purge that URL).
2. **Cache styles and scripts briefly** — URI Path ends with `.css` or `.js` and is not `/tapper/sw.js` or `/sw.js`:
   Edge TTL **1 hour**. The pages use `?v=` versions, so a new version fetches fresh.
3. **Never cache pages, service workers or the portal** — URI Path equals `/`, ends with `.html`, equals `/tapper/sw.js` or
   `/sw.js`, or starts with `/tapper/`: **Bypass cache**. The tap page and its service worker must always come from the origin.
4. **Tap page: no checks** (Configuration Rule) — URI Path starts with `/tapper/`: Security Level **Essentially Off**,
   Browser Integrity Check **Off**.

## Origin (VPS)
- Keep ports 80 and 443 open. Traefik renews Let's Encrypt over HTTP-01; Cloudflare passes `/.well-known/acme-challenge/`.
- Traefik will see Cloudflare's addresses as the client. Do not add logging that records query strings or fragments.
  (Fragments never arrive.) If real client IPs are ever needed, trust `CF-Connecting-IP` from Cloudflare ranges only.
- Optional later: restrict ports 80/443 to Cloudflare's published IP ranges so the origin cannot be hit directly.
- Range requests: the home server does not answer them, which stops click-to-seek in the home video section. Cloudflare
  can serve ranges for cached media; verify with `curl -sI -H 'Range: bytes=0-99' https://redmed.live/assets/how-it-works.webm`
  (expect `206`). If it stays `200`, fix `Accept-Ranges` on the portal server instead.

## After cutover
- `bash scripts/verify-cloudflare.sh` must pass.
- Update `AGENTS.md`, `docs/domain.md`, `docs/release/OPS.md` and `docs/release/PRODUCTION.md` from "no Cloudflare" to this setup.
- Deploys do not change: `scripts/deploy-vps.sh` still writes to the VPS. After replacing a media file, purge its URL.
