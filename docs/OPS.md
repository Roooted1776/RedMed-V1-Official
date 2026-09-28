# RedMed ops stack

Ops is separate from the Assist band **data** path. **Never** put Assist `#d=` payloads or wearer profile bodies through MCP, or through any server code / DB / logging on the VPS. Supabase `redmed_ops` stays release evidence. Supabase `redmed_owner` is the signed-in wearer store and is not an MCP or VPS tool. The public tap page does not query either schema. See `docs/adr/002-owner-account-sync.md`.

As of 2026-09-28 the VPS also happens to be Assist's static-file origin (see
below) — that's a hosting decision, not a data-path exception. `#d=` is a URL
fragment the browser never sends to any server, so serving static HTML/JS/CSS
from the VPS carries the same (zero) PHI exposure as any other static host.
The wall is still: no app logic, DB, or log config on the VPS may ever read a
fragment, query string, or `redmed_owner` row.

## Topology

| Layer | Role |
|-------|------|
| **Assist origin** | Hostinger VPS `redmed-portal` container behind Traefik (`redmed.live`, `www.redmed.live` → port 8090, TLS via Let's Encrypt). Static files only. |
| **DNS** | Namecheap BasicDNS. `@`/`www` A records → `2.25.249.204` directly. No Cloudflare. |
| **Registrar** | Namecheap |
| **Backup Assist** | `Roooted1776.github.io` via `scripts/publish-github-io.sh` / its `Publish tapper` Action (now correctly synced from `RedMed-V1-Official`) |
| **VPS** | Hostinger KVM `2010795` / `srv2010795.hstgr.cloud` / `2.25.249.204` — Docker/Traefik. Runs ops tooling (the ops MCP server) **and** the `redmed-portal` static Assist container. See product-wall note above — "runs on the VPS" is not the same as "touches Assist data." |
| **Supabase** | Project `mohxobgyjkcmkqxijgeg` (`RedMed Secure Data`) — `redmed_ops` release ledger; `redmed_owner` signed-in wearer rows. MCP does not read wearer rows. Not involved in serving Assist content. |
| **MCP** | Not part of this repository. Assist, the website, Owner, and `supabase/` do not call one. |

## VPS

- SSH: `hostinger-vps` → `root@2.25.249.204` with `~/.ssh/hostinger_vps` (helper `hostinger-vps` in `~/.local/bin` when installed).
- Companion: `hostinger-vps-ssh` MCP for SFTP/rich SSH.
- Hostinger product MCP (`Hostinger-vps`): power, firewall, snapshots — not shell.
- Confirm before destructive changes (reboot, recreate, firewall wipe, `rm -rf`).
- Containers as of 2026-09-28: `traefik-traefik-1` (reverse proxy, ports 80/443), `redmed-portal-live` (static Assist shell, image `redmed-portal:*`, internal port 8090), the ops MCP server. Adding app logic to `redmed-portal` that reads `#d=`, query strings, or writes to a DB breaks the product wall — don't.

## Secrets matrix

| Secret | Where | Used for |
|--------|-------|----------|
| `HOSTINGER_API_TOKEN` | CI + agent env + MCP | VPS-account APIs only — this account has no static-hosting website product, so the shared-hosting deploy script/CI step are currently dead code |
| `CLOUDFLARE_API_TOKEN` | Unused | Cloudflare cutover was abandoned 2026-09-28 (`docs/domain.md`) — script kept but not wired into CI |
| SSH `hostinger_vps` | Max machines + agent | VPS shell |
| Supabase service role | Ops only (never Assist client) | Ops tables if any |
| Supabase anon key | Only if a future non-PHI ops UI needs it | Never band decode |

Store in 1Password / CI secrets. Do not commit tokens.

## Product wall

This tree does not contain an MCP package, an MCP workflow, or an MCP database component. Assist, Owner, the static site, and `supabase/` must not call an MCP. ICE profiles and Assist `#d=` payloads must not be sent to an MCP, Supabase, or the VPS.

## Side repos

| Repo | Role |
|------|------|
| `Roooted1776/RedMed-V1-Official` | Canonical product (this tree) |
| `Roooted1776/frisky` | Legacy name — archive or redirect to V1 after mirror |
| `Roooted1776/Roooted1776.github.io` | Assist Pages backup |
| `Roooted1776/redmed-privacy` | Standalone privacy HTML — **not** Connect Privacy URL |
