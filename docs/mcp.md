# RedMed MCP

Ops-facing Model Context Protocol server for agents. Package lives in [`mcp/`](../mcp/).

## Project

| | |
|--|--|
| Supabase project | `mohxobgyjkcmkqxijgeg` |
| API URL | `https://mohxobgyjkcmkqxijgeg.supabase.co` |
| Dashboard | https://supabase.com/dashboard/project/mohxobgyjkcmkqxijgeg |
| Transport (local) | **Cursor stdio** (`npx tsx src/index.ts` from `mcp/`) |
| Transport (remote) | **Streamable HTTP** `https://mcp.redmed.live/mcp` (Bearer `REDMED_MCP_TOKEN`). `https://srv2010795.hstgr.cloud/mcp` is the same container via the PTR name. |
| VPS | Hostinger KVM `2010795` / `2.25.249.204` (`srv2010795`) |

## Product wall

Assist (`tapper/` → `https://redmed.live/tapper/`) stays no-auth / no RedMed DB.
Band ICE profiles stay in `#d=` (+ Owner Keychain). **Do not** put medical card
payloads in Supabase or expose them through MCP tools.

## Secrets

Set (never commit):

- `SUPABASE_URL` (optional; defaults to the project URL above)
- `SUPABASE_PUBLISHABLE_KEY` (`sb_publishable_…`)
- `SUPABASE_SECRET_KEY` (`sb_secret_…`, MCP process only)
- `HOSTINGER_API_TOKEN` (or `~/.config/hostinger-mcp/api_token`)
- `REDMED_VPS_IDENTITY` (default `~/.ssh/hostinger_vps`)
- `REDMED_MCP_TOKEN` (remote HTTP Bearer; VPS + Cursor only)

See [`mcp/.env.example`](../mcp/.env.example). Rotate any key that appeared in chat
before treating it as production-trusted.

Cursor entries: [`.cursor/mcp.json`](../.cursor/mcp.json) → `redmed` / `redmed-remote`.
Also wired in Claude Desktop, Claude Code, and Perplexity (see [`mcp/CLIENTS.md`](../mcp/CLIENTS.md)).

## Tools (v0.2)

- `redmed_ping`
- `redmed_stack_status`
- `supabase_project_info`
- `supabase_list_tables`
- `hostinger_vps_info`
- `hostinger_websites`
- `hostinger_ssh_exec` — SSH from Mini (`REDMED_EXEC_MODE=ssh`) or local bash on VPS (`local`)
- `hostinger_ssh_probe`

No arbitrary SQL. Power actions (reboot/shutdown) are blocked in the shell policy.

## Two packages

| Path | Role |
|------|------|
| `mcp/` | What the VPS runs (this document). Docker Compose at `/opt/redmed-mcp`. |
| `mcp/redmed-mcp/` | Allow-listed Node MCP exercised by `.github/workflows/gates.yml`. |

## Hosting

- Assist static stays on Hostinger shared hosting for `https://redmed.live/tapper/`. Do not point the apex A record at the VPS.
- Ops MCP remote: Docker + Traefik on the VPS at `/opt/redmed-mcp`.
  - Health: `https://srv2010795.hstgr.cloud/healthz` and `https://mcp.redmed.live/healthz`
  - MCP path: `https://mcp.redmed.live/mcp`
- While Namecheap still uses Hostinger `dns-parking` nameservers, the authoritative zone is Hostinger DNS:

```bash
HOSTINGER_API_TOKEN=… node scripts/upsert-mcp-dns-hostinger.mjs
```

That upserts only `A mcp → 2.25.249.204` (`overwrite` false). It does not change `@` or `www`.

- After Cloudflare becomes authoritative, keep the same grey-cloud record:

```bash
CLOUDFLARE_API_TOKEN=… node scripts/upsert-mcp-dns.mjs
```
