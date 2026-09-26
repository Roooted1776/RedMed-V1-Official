# RedMed MCP — client wiring

Bearer token file: `~/.config/redmed-mcp/token`  
Remote URL (live): `https://srv2010795.hstgr.cloud/mcp`  
Canonical (after CF DNS): `https://mcp.redmed.live/mcp`

Clone path: `~/Documents/RedMed-V1-Official` (canonical repo `Roooted1776/RedMed-V1-Official`).

## Cursor

Project: `RedMed-V1-Official/.cursor/mcp.json` (GitHub + Cloudflare entries ship in-repo).  
Wire local `redmed` stdio via `mcp/bin/run-stdio.sh` from the clone root, or add `redmed-remote` pointing at the HTTPS URL above with Bearer from the token file.  
Global: `~/.cursor/mcp.json` → same ops servers when you want them everywhere.  
Reload: Cursor Settings → MCP → refresh / restart Cursor.

## Claude Desktop

File: `~/Library/Application Support/Claude/claude_desktop_config.json`  
Entry: `redmed` (stdio via `mcp/bin/run-stdio.sh` under the clone).  
Fully quit and reopen Claude Desktop (⌘Q).

Remote HTTPS for Desktop: Settings → Connectors → add custom  
URL `https://srv2010795.hstgr.cloud/mcp`, auth Bearer from token file.

## Claude Code

```bash
claude mcp list   # should show redmed + redmed-remote when configured
```

## Perplexity Desktop (Pro/Max)

1. Settings → Connectors → install Helper if prompted → restart.
2. **Remote (preferred):** Add Custom Remote Connector  
   - Name: `RedMed`  
   - URL: `https://srv2010795.hstgr.cloud/mcp`  
   - Auth: API Key / Bearer  
   - Key: contents of `~/.config/redmed-mcp/token`  
   - Transport: Streamable HTTP  
3. **Local fallback:** Add Connector (Simple)  
   - Command: `mcp/bin/run-stdio.sh` (absolute path under your `RedMed-V1-Official` clone)  
4. Enable under Sources on a new chat.
