#!/usr/bin/env node
/**
 * redmed-mcp v0.2 — stdio MCP server for RedMed ops.
 * Product wall: refuse ICE / #d= / PHI handling.
 */
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { wallCheck, redactFragments } from '../lib/wall.mjs';
import { ACTIONS, UNITS, buildCommand } from '../lib/ops-commands.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
// Raw root shell is off by default. Opt in per session only when you are
// at the keyboard: REDMED_SSH_ALLOW_RAW=1.
const ALLOW_RAW = process.env.REDMED_SSH_ALLOW_RAW === '1';

const server = new McpServer({
  name: 'redmed-mcp',
  version: '0.3.0',
});

server.tool(
  'redmed_stack_status',
  'Read-only status of Assist hosts, DNS, backup github.io, and ops pointers. Never returns profile data.',
  {},
  async () => {
    const script = path.join(__dirname, 'redmed-stack-status.mjs');
    const r = spawnSync(process.execPath, [script], { encoding: 'utf8', timeout: 45000 });
    const out = (r.stdout || '') + (r.stderr || '');
    return {
      content: [{ type: 'text', text: redactFragments(out) || `exit ${r.status}` }],
    };
  },
);

server.tool(
  'supabase_ops_status',
  'Ops-only Supabase pointer. Confirms project ref; does not read medical rows.',
  {
    note: z.string().optional().describe('Optional ops note (no PHI)'),
  },
  async ({ note }) => {
    const blocked = wallCheck(note || '');
    if (blocked) {
      return { content: [{ type: 'text', text: blocked }], isError: true };
    }
    const ref = process.env.REDMED_SUPABASE_REF || 'mohxobgyjkcmkqxijgeg';
    const text = JSON.stringify(
      {
        project: 'RedMed Secure Data',
        ref,
        role: 'ops-metadata-only',
        productWall: 'Zero ICE/PHI profiles in this project',
        note: note || null,
      },
      null,
      2,
    );
    return { content: [{ type: 'text', text }] };
  },
);

function runSsh(command) {
  const host = process.env.REDMED_SSH_HOST || '2.25.249.204';
  const key = process.env.REDMED_SSH_KEY || `${process.env.HOME}/.ssh/hostinger_vps`;
  const user = process.env.REDMED_SSH_USER || 'root';
  try {
    const out = execFileSync(
      'ssh',
      [
        '-i', key,
        '-o', 'BatchMode=yes',
        // Pin the host key in ~/.ssh/known_hosts once (ssh-keyscan + verify
        // fingerprint in hPanel). accept-new would trust a MITM on first use.
        '-o', `StrictHostKeyChecking=${process.env.REDMED_SSH_STRICT || 'yes'}`,
        '-o', 'ConnectTimeout=15',
        '--',
        `${user}@${host}`,
        command,
      ],
      { encoding: 'utf8', timeout: 60000, maxBuffer: 2 * 1024 * 1024 },
    );
    return { content: [{ type: 'text', text: redactFragments(out).slice(0, 100_000) }] };
  } catch (e) {
    return {
      content: [
        {
          type: 'text',
          text: redactFragments(`SSH failed: ${e.message}\n${e.stdout || ''}\n${e.stderr || ''}`),
        },
      ],
      isError: true,
    };
  }
}

server.tool(
  'hostinger_ops',
  'Read-only, allow-listed ops command on the RedMed VPS (uptime, disk, docker, traefik, unit status/journal, ports, failed SSH logins). Never touches Assist #d= data.',
  {
    action: z.enum(Object.keys(ACTIONS)),
    container: z.string().regex(/^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$/).optional(),
    unit: z.enum(UNITS).optional(),
    tail: z.number().int().min(1).max(500).optional(),
  },
  async (params) => {
    let command;
    try {
      command = buildCommand(params.action, params);
    } catch (e) {
      return { content: [{ type: 'text', text: String(e.message) }], isError: true };
    }
    return runSsh(command);
  },
);

if (ALLOW_RAW) {
  server.tool(
    'hostinger_ssh_exec',
    'RAW shell on the ops VPS (enabled by REDMED_SSH_ALLOW_RAW=1). Runs as REDMED_SSH_USER. Human must review every command. Never for Assist #d= data.',
    {
      command: z.string().max(2000).describe('Shell command to run on the VPS'),
    },
    async ({ command }) => {
      const blocked = wallCheck(command);
      if (blocked) {
        return { content: [{ type: 'text', text: blocked }], isError: true };
      }
      return runSsh(command);
    },
  );
}

const transport = new StdioServerTransport();
await server.connect(transport);
