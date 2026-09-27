# RedMed V1 Official

Medical ID band + iPhone app. The band card is still the `#d=` fragment. A signed-in wearer copy can live in Supabase `redmed_owner`. **Not HIPAA-certified.** The public tap page does not look the profile up.

| Surface | Path | Audience |
|---------|------|----------|
| **Assist** | [`tapper/`](tapper/) → `https://redmed.live/tapper/` | Person who taps the band |
| **Owner** | [`owner/`](owner/) | Wearer with the App Store app (`com.redmed.app`) |

Canonical git remote: **`Roooted1776/RedMed-V1-Official`** (migrated from `frisky`; history preserved when mirrored). Ship branch: `main`.

## Development control center

Start with [`docs/DEVELOPMENT-PLAN.md`](docs/DEVELOPMENT-PLAN.md) for priorities,
owners, launch blockers and acceptance criteria. Architecture boundaries are
recorded in [`docs/adr/001-emergency-path-and-ops.md`](docs/adr/001-emergency-path-and-ops.md);
the release procedure is [`docs/RELEASE-RUNBOOK.md`](docs/RELEASE-RUNBOOK.md).

```bash
make setup          # pinned deploy-script dependencies, no lifecycle scripts
make check          # local automated gates; no deployment or database writes
make release-check  # same gates + mandatory live product-origin smoke
make stage          # static-only deploy bundle
```

A passing build is not launch approval. Public-origin, physical-band and
clinical-content gates remain separate. `supabase/` keeps the ops release
ledger in `redmed_ops`. Wearer rows, when account sync is on, live only in
`redmed_owner` and are not what a band tap reads.

## Write base

**`https://redmed.live/tapper/`** — Hostinger static origin + Cloudflare DNS/SSL.  
Backup for already-written bands: `https://roooted1776.github.io/tapper/`.

A band tap reads only the URL `#d=` fragment (the browser decodes on device). The Owner app keeps Keychain on-device and, when account sync is on, a signed-in row in Supabase. Rewriting the cloud row does not rewrite the band.

## Quick start (Assist)

```bash
# Local
python3 -m http.server 8787
# open http://127.0.0.1:8787/tapper/

# Pre-merge gates
bash scripts/sync-tapper.sh
node scripts/test-d-codec.mjs
node scripts/test-nfc-hardware.mjs
node scripts/test-sw-offline.mjs
node scripts/test-product-independence.mjs

# Stage + deploy to Hostinger
bash scripts/stage-site.sh
HOSTINGER_API_TOKEN=… node scripts/deploy-hostinger-static.mjs redmed.live

# Smoke (after DNS cutover)
BASE=https://redmed.live bash scripts/smoke-pages.sh
# Origin without public DNS:
BASE=http://195.35.60.70 HOST_HEADER=redmed.live bash scripts/smoke-pages.sh
```

DNS cutover: [`docs/domain.md`](docs/domain.md). Production matrix: [`docs/PRODUCTION.md`](docs/PRODUCTION.md). Agent rules: [`AGENTS.md`](AGENTS.md).

## Parked (Owner) until paid Apple Developer

| Flag | Default | Restore |
|------|---------|---------|
| `nfcHardwareEnabled` | `false` | [`docs/NFC-RESTORE.md`](docs/NFC-RESTORE.md) |
| `associatedDomainsEnabled` | `false` | [`docs/associated-domains-restore.md`](docs/associated-domains-restore.md) |
| `healthKitImportEnabled` | `false` | [`docs/healthkit-restore.md`](docs/healthkit-restore.md) |
| App Store listing | parked | [`docs/APP-STORE.md`](docs/APP-STORE.md) |

Do not market “write from the app” until Tag Reading + Write The Band on blank NTAG216 is proven.

## Ops (not the band host)

- VPS / Traefik / Docker: **ops only** — never Assist `#d=` origin ([`docs/OPS.md`](docs/OPS.md)).
- No MCP in this repository. Assist, the website, and the band tap do not call one. Product wall: no `#d=` fragment through an MCP or the VPS. The public tap page does not query Supabase.
- Supabase project `RedMed Secure Data` (`mohxobgyjkcmkqxijgeg`): `redmed_ops` is the release ledger. `redmed_owner` is the signed-in wearer copy. Not a HIPAA certification.
- Side repos: `Roooted1776.github.io` (Assist backup), `redmed-privacy` (do **not** use as Connect Privacy URL — use live `/Document/`).

One public site: Hostinger static at `https://redmed.live/tapper/`. Cloudflare is DNS and SSL only. Do not add a Worker. `github.io` is only the backup for bands already written to that host.
