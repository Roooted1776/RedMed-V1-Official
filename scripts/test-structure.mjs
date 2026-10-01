#!/usr/bin/env node
/**
 * The repo layout and the code that depends on it must agree.
 * Fails when a deploy script, workflow, Makefile or redirect points at a file
 * or folder that does not exist (for example after files are moved).
 *
 * Checked:
 *   1. scripts/stage-site.sh: every `copy <path>` source exists.
 *   2. .github/workflows/pages-deploy.yml: every path filter's folder or file exists.
 *   3. _redirects: every destination that is a local path exists (or is itself a redirect).
 *   4. Workflows, Makefile and scripts/*.sh: every `scripts/<file>` they mention exists.
 *   5. The three product folders exist: store/, tapper/, owner/.
 */
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = (rel) => readFileSync(path.join(root, rel), 'utf8');
const exists = (rel) => existsSync(path.join(root, rel));
const isDir = (rel) => exists(rel) && statSync(path.join(root, rel)).isDirectory();

const problems = [];
let checked = 0;
const need = (from, rel, what) => {
  checked++;
  if (!exists(rel)) problems.push(`${from}: ${what} "${rel}" does not exist`);
};

// 5. product folders
for (const dir of ['store', 'tapper', 'owner']) {
  checked++;
  if (!isDir(dir)) problems.push(`repo root: product folder ${dir}/ is missing`);
}

// Website source is init.html only — root index.html must stay parked.
checked++;
if (!exists('init.html')) problems.push('repo root: website source init.html is missing');
checked++;
if (exists('index.html')) problems.push('repo root: index.html must stay parked/ (website is init.html only)');
checked++;
if (!exists('parked/index.html')) problems.push('parked/index.html: old root stub missing');

// 1. stage-site.sh copy lines
for (const m of read('scripts/stage-site.sh').matchAll(/^copy\s+(\S+)\s*$/gm)) {
  need('scripts/stage-site.sh', m[1], 'copies');
}

// 2. pages-deploy.yml path filters
for (const m of read('.github/workflows/pages-deploy.yml').matchAll(/^\s+-\s+'([^']+)'\s*$/gm)) {
  const base = m[1].replace(/\/?\*\*.*$/, '');
  need('.github/workflows/pages-deploy.yml', base, 'path filter');
}

// 3. _redirects destinations
const redirectSources = new Set();
const redirectLines = read('_redirects')
  .split('\n')
  .map((l) => l.trim())
  .filter((l) => l && !l.startsWith('#'))
  .map((l) => l.split(/\s+/));
for (const [src] of redirectLines) redirectSources.add(src.replace(/\/$/, ''));
for (const [src, dest] of redirectLines) {
  if (!dest || !dest.startsWith('/')) continue; // external URL
  const clean = dest.split('#')[0].split('?')[0];
  const rel = clean.replace(/^\//, '').replace(/\/$/, '');
  checked++;
  // Root / is served from init.html (staged as index.html). Parked stub is not live.
  const ok = rel === ''
    ? exists('init.html')
    : exists(rel) || (isDir(rel) && exists(`${rel}/index.html`)) || redirectSources.has('/' + rel);
  if (!ok) problems.push(`_redirects: ${src} -> ${dest} points at nothing`);
}

// 4. scripts mentioned by workflows, Makefile and shell scripts
const sources = ['Makefile'];
for (const f of readdirSync(path.join(root, '.github/workflows'))) sources.push(`.github/workflows/${f}`);
for (const f of readdirSync(path.join(root, 'scripts'))) if (f.endsWith('.sh')) sources.push(`scripts/${f}`);
for (const file of sources) {
  if (!exists(file)) continue;
  const seen = new Set();
  for (const m of read(file).matchAll(/\bscripts\/([A-Za-z0-9_.-]+\.(?:sh|mjs|py|js))\b/g)) {
    const rel = `scripts/${m[1]}`;
    if (seen.has(rel)) continue;
    seen.add(rel);
    need(file, rel, 'mentions script');
  }
}

if (problems.length) {
  console.error(`FAIL ${problems.length} path(s) in the code point at files that do not exist:`);
  for (const p of problems) console.error(`  ${p}`);
  process.exit(1);
}
console.log(`OK   ${checked} paths in deploy scripts, workflows, Makefile and redirects all exist; store/, tapper/, owner/ present`);
