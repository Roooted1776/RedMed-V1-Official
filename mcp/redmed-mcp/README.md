# redmed-mcp v0.3

Cursor MCP server for **RedMed ops** (Hostinger API status, SSH exec helper hooks, Supabase project health).

## Product wall (do not break)

This MCP must **never**:

- Accept, decode, store, or log Assist `#d=` fragments or ICE medical profiles
- Write medical data to Supabase, VPS disk, or Hostinger files
- Treat the VPS as the Assist write origin (`redmed.live/tapper/` stays Hostinger static)

Ops-only Supabase project: `mohxobgyjkcmkqxijgeg` (`RedMed Secure Data`). Keep tables free of PHI.

## Tools

| Tool | Purpose |
|------|---------|
| `redmed_stack_status` | DNS / origin / github.io / Supabase project summary (read-only) |
| `hostinger_ops` | Allow-listed read-only VPS command: `uptime`, `disk`, `memory`, `docker_ps`, `traefik_ps`, `container_logs`, `unit_status`, `unit_journal`, `failed_logins`, `listening_ports` |
| `hostinger_ssh_exec` | **Off by default.** Raw shell, only registered when `REDMED_SSH_ALLOW_RAW=1`. Human reviews every command. |
| `supabase_ops_status` | Project ref + table count (no row reads of medical data) |

Hostinger product MCPs (websites, DNS, VPS power) remain on Cursor’s Hostinger plugin — this package complements them.

## Security model (v0.3)

- **Allow-list, not deny-list.** v0.2 took a free-form root shell string and blocked "destructive" regexes. That regex missed `rm -rf /` itself (trailing `\b` after `/`), `rm -r -f /`, `systemctl poweroff`, and any base64-wrapped command. An MCP tool is driven by a model that reads untrusted text (prompt injection), so its input is untrusted. v0.3 maps input to fixed commands and validates every parameter (`lib/ops-commands.mjs`).
- **Wall regex fixed.** v0.2's `\b(#d=…)\b` never matched a real band URL (`/tapper/#d=…`), because `#` is not a word char. `lib/wall.mjs` matches `#d=` anywhere and redacts it from tool output.
- **Host key pinned.** `StrictHostKeyChecking=yes` by default. Pin once: `ssh-keyscan -t ed25519 2.25.249.204 >> ~/.ssh/known_hosts`, then compare the fingerprint against hPanel's VPS console before trusting it. Override with `REDMED_SSH_STRICT=accept-new` only if you know why.
- **Next step (Max):** create a non-root `redmed-ops` user on the VPS in the `docker` group and set `REDMED_SSH_USER=redmed-ops`. Root is still the default so nothing breaks.

Tests: `npm test` (runs in `.github/workflows/gates.yml`).

## Run

```bash
cd mcp/redmed-mcp && npm ci
export HOSTINGER_API_TOKEN=…   # optional for richer status
export REDMED_SSH_HOST=2.25.249.204
export REDMED_SSH_KEY=~/.ssh/hostinger_vps
node bin/redmed-mcp.mjs
```

CLI status without MCP:

```bash
node bin/redmed-stack-status.mjs
```

## Cursor entry

See repo [`.cursor/mcp.json`](../../.cursor/mcp.json) — server id `redmed`.
