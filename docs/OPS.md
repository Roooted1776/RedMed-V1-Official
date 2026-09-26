# RedMed ops stack

Ops is separate from the Assist band write path. **Never** put Assist `#d=` payloads or wearer profile bodies through MCP or the VPS. Supabase `redmed_ops` stays release evidence. Supabase `redmed_owner` is the signed-in wearer store and is not an MCP or VPS tool. The public tap page does not query either schema. See `docs/adr/002-owner-account-sync.md`.

## Topology

| Layer | Role |
|-------|------|
| **Assist origin** | Hostinger shared static (`redmed.live` / plan IP `195.35.60.70`) |
| **DNS + edge SSL** | Cloudflare (cutover: `scripts/setup-cloudflare-dns.mjs`) |
| **Registrar** | Namecheap (NS → Cloudflare after cutover) |
| **Backup Assist** | `Roooted1776.github.io` via `scripts/publish-github-io.sh` |
| **VPS** | Hostinger KVM `2010795` / `srv2010795.hstgr.cloud` / `2.25.249.204` — Docker/Traefik for **ops tools only** |
| **Supabase** | Project `mohxobgyjkcmkqxijgeg` (`RedMed Secure Data`) — `redmed_ops` release ledger; `redmed_owner` signed-in wearer rows. MCP does not read wearer rows. |
| **MCP** | Not part of this repository. Assist, the website, Owner, and `supabase/` do not call one. |

## VPS (ops only)

- SSH: `hostinger-vps` → `root@2.25.249.204` with `~/.ssh/hostinger_vps` (helper `hostinger-vps` in `~/.local/bin` when installed).
- Companion: `hostinger-vps-ssh` MCP for SFTP/rich SSH.
- Hostinger product MCP (`Hostinger-vps`): power, firewall, snapshots — not shell.
- Confirm before destructive changes (reboot, recreate, firewall wipe, `rm -rf`).

**Do not** point `redmed.live` A records at the VPS for Assist in this sprint. Assist stays on Hostinger static.

## Secrets matrix

| Secret | Where | Used for |
|--------|-------|----------|
| `HOSTINGER_API_TOKEN` | CI + agent env + MCP | Static deploy, website APIs |
| `CLOUDFLARE_API_TOKEN` | CI + agent env | DNS/SSL cutover script |
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
