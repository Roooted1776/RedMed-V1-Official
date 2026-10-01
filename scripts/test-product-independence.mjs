#!/usr/bin/env node
/**
 * Assist, Owner, the static site, and the ops database do not depend on an MCP.
 *   node scripts/test-product-independence.mjs
 */
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const skip = new Set(['node_modules', 'dist', '.git']);
const needles = ['mcp/redmed-mcp', 'redmed-mcp'];
const roots = [
  'owner',
  'tapper',
  'Document',
  'assets',
  'privacy',
  'support',
  'worker',
  'supabase',
  'scripts',
  '.github',
  'docs',
];
const files = [
  'Makefile',
  'README.md',
  'AGENTS.md',
  'SECURITY.md',
  '.cursor/mcp.json',
  '.cursor/environment.json',
];

let failed = 0;
function fail(message) {
  failed += 1;
  console.error(`FAIL ${message}`);
}

if (existsSync(join(root, 'mcp'))) {
  fail('mcp/ is inside the product tree');
} else {
  console.log('OK   no mcp/ directory');
}

function walk(dir, hits) {
  for (const name of readdirSync(dir)) {
    if (skip.has(name)) continue;
    const path = join(dir, name);
    const st = statSync(path);
    if (st.isDirectory()) walk(path, hits);
    else if (st.isFile() && st.size < 2_000_000) hits.push(path);
  }
}

const hits = [];
for (const rel of roots) {
  const path = join(root, rel);
  if (existsSync(path)) walk(path, hits);
}
for (const rel of files) {
  const path = join(root, rel);
  if (existsSync(path)) hits.push(path);
}

for (const path of hits) {
  if (path.endsWith('test-product-independence.mjs')) continue;
  const text = readFileSync(path, 'utf8');
  for (const needle of needles) {
    if (text.includes(needle)) fail(`${path.slice(root.length)} contains ${needle}`);
  }
  const rel = path.slice(root.length);
  const historicalLedger = rel.endsWith('supabase/migrations/20260926064135_redmed_ops_release_ledger.sql')
    || rel.endsWith('supabase/migrations/20260926155408_drop_mcp_from_release_ledger.sql');
  if (path.includes(`${join('supabase', '')}`) && text.includes("'mcp'") && !historicalLedger) {
    fail(`${rel} still names mcp in the database contract`);
  }
}

const drop = readFileSync(join(root, 'supabase/migrations/20260926155408_drop_mcp_from_release_ledger.sql'), 'utf8');
if (!drop.includes("check (component in ('assist', 'owner', 'ops'))")) {
  fail('release ledger still allows an mcp component');
}
if (drop.includes("'mcp',") || drop.includes(", 'mcp'")) {
  fail('release ledger still allows an mcp gate');
}

if (failed === 0) console.log('OK   product, website, database, and structure do not reference the MCP package');
else process.exit(1);
