# RedMed V1 go-live audit

**Checked:** 2026-09-26 against sprint branch `cursor/redmed-v1-golive-c874`  
**Canonical repo:** `Roooted1776/RedMed-V1-Official` (mirror from `frisky`)

## Scorecard

| Surface | Deployable? | Notes |
|---------|-------------|-------|
| Assist code (`tapper/`, SW, `#d=` tests) | **Yes** | CI gates: d-codec, nfc-hardware (51), sw-offline, worker-device |
| Public `https://redmed.live/` | **Portal on the VPS** | Account site at `/`, Assist shell at `/tapper/`, synced from `portal/` + `tapper/` |
| Origin `195.35.60.70` + Host `redmed.live` | **Parking HTML** | Must attach/deploy real static files |
| Backup `roooted1776.github.io/tapper/` | **Yes** | Live Assist while custom domain parks |
| Owner iOS | Compile yes / NFC no | Flags parked; restore docs ready |
| Ops MCP (`mcp/redmed-mcp`) | **CI package** | Allow-listed SSH, wall tests in `gates.yml` |
| Ops MCP (`mcp/` on VPS) | **Running v0.2.0** | Container `redmed-mcp` + Traefik. Health `https://srv2010795.hstgr.cloud/healthz`. Public name `https://mcp.redmed.live/mcp` |
| Supabase `mohxobgyjkcmkqxijgeg` | Active | Ops only — keep free of medical data |
| VPS `2010795` | **Running** | KVM 2, Ubuntu 24.04 + Docker/Traefik. Projects: `redmed-mcp`, `traefik`. Not Assist origin |
| Hostinger websites on the VPS token | **None** | `GET /api/hosting/v1/websites` total 0, so Assist static deploy cannot run with that token |

## Invariants (must stay green)

- Assist no-auth, no-ads; path `/tapper/`
- No profile backend / no PHI on servers
- SOS = full sound + light; never arm on band tap alone
- No `redmed://band#d=` handoff
- NTAG216 unlocked only; 51 NFC static checks
- SW CACHE lockstep across `sw.js`, `tapper/sw.js`, `owner/RedMed/sw.js`
- Face ID UI-only; Keychain `WhenPasscodeSetThisDeviceOnly` without biometry ACL

## Go-live remaining (Max + agent)

1. Hostinger: un-park website / deploy staged `dist/passerby` (`HOSTINGER_API_TOKEN` on the account that owns the static site — the VPS token currently sees zero websites)
1b. ~~Ops hostname~~ Applied 2026-09-26: Hostinger `A mcp → 2.25.249.204` (apex still `2.57.91.91`). `https://mcp.redmed.live/healthz` returns `redmed-mcp` v0.2.0 with a Let's Encrypt cert. Apex Assist is still the parking page.
2. Cloudflare DNS script + Namecheap Custom NS
3. Smoke: `BASE=https://redmed.live bash scripts/smoke-pages.sh`
4. AASA JSON (not parking) at `/apple-app-site-association` + `.well-known/`
5. ~~Mirror-push history~~ Done 2026-09-26: frisky full history merged into V1 `main` (non-force, `--allow-unrelated-histories`). Macs: `git remote set-url origin https://github.com/Roooted1776/RedMed-V1-Official.git && git fetch && git reset --keep origin/main`
6. CI secrets on V1 remote: `HOSTINGER_API_TOKEN`, `CLOUDFLARE_API_TOKEN`
7. Paid Apple Program → NFC + Associated Domains restore → App Store (`docs/APP-STORE.md`)

## Side repos

| Repo | Role |
|------|------|
| `RedMed-V1-Official` | Canonical product |
| `frisky` | Legacy name — point README at V1 after mirror |
| `Roooted1776.github.io` | Assist backup |
| `redmed-privacy` | Not Connect Privacy URL |
