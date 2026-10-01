# RedMed domain — `redmed.live`

Stack as of 2026-09-28 (do not mix roles):

| Layer | Who | Job |
|-------|-----|-----|
| **Registrar + DNS** | Namecheap | BasicDNS. `@` and `www` A records point straight at the VPS. No Cloudflare in the stack. |
| **Origin** | Hostinger VPS (`2010795` / `2.25.249.204`) | `redmed-portal` container behind Traefik. Traefik terminates TLS (Let's Encrypt, `certresolver=letsencrypt`) and serves the static Assist shell. **Static files only — no PHI processing** (see product wall, `AGENTS.md`). |

Production write base:

**`https://redmed.live/tapper/`**

No RedMed server processes profile data. No database in the request path.
Profile data stays in the band URL `#d=` fragment only — a URL fragment is
never sent by the browser to any server; it's decoded client-side on the
phone. The VPS/Traefik route is a static-file reverse proxy, same privacy
property as any other static host.

`AppConfig.medicalCardCustomDomainTBD` / `medicalCardBaseURL` is
`https://redmed.live/tapper/`.

## Current

| Path | Status |
|------|--------|
| Product HTML app | Served by container `redmed-portal-live` on the Hostinger VPS, port 8090 internally, fronted by Traefik. Traefik router `redmed-live`: `` Host(`redmed.live`) || Host(`www.redmed.live`) `` → service `redmed-portal`, TLS via Let's Encrypt. |
| DNS | Namecheap BasicDNS. `@` → `2.25.249.204`, `www` → `2.25.249.204`. NS: `dns1/dns2.registrar-servers.com`. |
| Hostinger shared static-hosting plan (`u666300215`) | **Does not exist on this account's API token** — the token only sees the VPS subscription, zero websites. `scripts/deploy-hostinger-static.mjs` also **refuses** `redmed.live` / `www.redmed.live` unless `REDMED_ALLOW_HOMEPAGE_REPLACE=1`. Live `/` is `index.html` from `home/index.html` (`scripts/deploy-vps.sh` `MODE=home`). The store is `init.html`, and `/store/` opens that file (`MODE=store`). Update `index.html` as the home page. Do not copy the store over home `index.html`, and do not copy the home page over store `init.html`. This shared-static path is not the live deploy. |
| Cloudflare | **Not used.** Was planned for a DNS/SSL cutover (see historical section below) but abandoned in favor of DNS → VPS direct + Traefik's own TLS. |
| Public GitHub Pages `Roooted1776.github.io/tapper/` | **Backup only.** Its `Publish tapper` workflow now syncs from `Roooted1776/RedMed-V1-Official` (fixed 2026-09-28 — it previously pointed at the archived `frisky` repo, so backup deploys were silently stale). Keep publishing so already-written bands still resolve if the VPS is ever down. |

Smoke after DNS: `BASE=https://redmed.live bash scripts/smoke-pages.sh`.
Origin check (DNS independent): `curl -k -H "Host: redmed.live" https://2.25.249.204/tapper/` (expect a name mismatch on the TLS cert since it's issued for `redmed.live`, not the bare IP — use `-k`/`--insecure` for this specific DNS-independent check only).
CI (`Pages tapper deploy`) hard-smokes public `https://redmed.live` and the github.io backup when DNS A is the VPS (`2.25.249.204`). Shared-static Hostinger upload soft-skips: the script refuses a homepage replace, and the token currently has zero websites.

## Publish github.io (backup host)

Repo `Roooted1776/Roooted1776.github.io` already exists. Re-publish:

1. GitHub → that repo → Actions → **Publish tapper** → Run workflow
   (checks out `Roooted1776/RedMed-V1-Official` and runs `scripts/publish-github-io.sh`).
2. Or locally: `./scripts/publish-github-io.sh /path/to/Roooted1776.github.io`, then commit and push `main`.
3. Smoke: `BASE=https://roooted1776.github.io bash scripts/smoke-pages.sh`

## Product rules

1. Smoke: `https://redmed.live/tapper/` loads RedMed · 911 · Aid. Bare `/` serves the landing page and does **not** force-redirect to `/tapper/` — legacy stub URLs (`card.html`, `get.html`, `redmed-emergency.html`, `tapper.html`) still redirect there for old bands.
2. New NFC writes use `redmed.live` (`AppConfig.medicalCardBaseURL`).
3. Keep github.io backup for old bands.
4. Path stays **`/tapper/`** so SW cache keys and legacy `/get/` → `/tapper/` redirects stay coherent.

## URL contract

| Role | URL |
|------|-----|
| Product HTML app (write base) | `https://redmed.live/tapper/` |
| VPS origin IP | `2.25.249.204` (Traefik, Host-based routing) |
| Backup host (old bands) | `https://roooted1776.github.io/tapper/` |

## Historical: Cloudflare cutover (abandoned 2026-09-28)

A Cloudflare DNS + edge-SSL cutover in front of a Hostinger shared static
plan was planned and scripted (`scripts/setup-cloudflare-dns.mjs`,
`scripts/verify-cf-dns-cutover.sh`). It was abandoned once it became clear
that shared static plan (`u666300215`) does not actually exist on the
account's API token, and the VPS + Traefik route above was already live and
simpler. Those scripts are unused; do not run them without first checking
whether this doc still reflects reality. **Do not** recreate Worker
`redmed-emergency` — Traefik + Let's Encrypt already terminates TLS. **Do
not** buy/transfer the domain onto Hostinger.

Deploy deps for the (currently dead) Hostinger-static path (one-off):
`npm install --no-save axios tus-js-client` before running
`scripts/deploy-hostinger-static.mjs`.
