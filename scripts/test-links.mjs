#!/usr/bin/env node
/**
 * Every local link on the published static pages must point at a real file.
 * Catches things like a <link rel="icon" href="/favicon.svg"> with no
 * favicon.svg in the repo.
 *
 * Checked: href / src / poster attributes in the published HTML pages, and
 * url(...) in the store stylesheet. Skipped: external URLs, mailto/tel/custom
 * schemes (redmed://), #fragments, and data: URIs.
 *
 * Also fails if a public page links to /tapper/ (it opens a wearer's profile).
 * Not checked on purpose: owner/ (native app, not the website).
 */
import { readFileSync, existsSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

const pages = [
  'init.html',
  'store/index.html',
  'support/index.html',
  'privacy/index.html',
  'Document/index.html',
  'Document/Document.html',
  'portal/index.html',
  'tapper/index.html',
];
const stylesheets = ['store.css', 'store/store.css'];

// /store -> /store/ style redirects in _redirects count as real targets.
const redirected = new Set();
if (existsSync(path.join(root, '_redirects'))) {
  for (const line of readFileSync(path.join(root, '_redirects'), 'utf8').split('\n')) {
    const m = line.trim().match(/^(\/\S*)\s+\S+\s+\d{3}$/);
    if (m) redirected.add(m[1].replace(/\/$/, '') || '/');
  }
}

function isReal(rel) {
  // Site root / is init.html (staged/deployed as index.html). No root index.html in git.
  if (rel === '' || rel === '.') return existsSync(path.join(root, 'init.html'));
  const p = path.join(root, rel);
  if (!p.startsWith(root)) return false;
  if (!existsSync(p)) return false;
  if (statSync(p).isDirectory()) {
    return existsSync(path.join(p, 'index.html')) || (rel === '' && existsSync(path.join(p, 'init.html')));
  }
  return true;
}

function resolve(fromFile, url) {
  const clean = url.split('#')[0].split('?')[0];
  if (!clean) return null; // fragment-only
  if (/^([a-z][a-z0-9+.-]*:|\/\/)/i.test(clean)) return null; // external / other scheme
  const rel = clean.startsWith('/')
    ? clean.slice(1)
    : path.posix.normalize(path.posix.join(path.posix.dirname(fromFile), clean));
  return rel;
}

const problems = [];
let checked = 0;

function check(fromFile, url) {
  const rel = resolve(fromFile, url);
  if (rel === null) return;
  checked++;
  const key = '/' + rel.replace(/\/$/, '');
  if (isReal(rel) || redirected.has(key === '/' ? '/' : key)) return;
  problems.push(`${fromFile}: ${url}`);
}

// The tap page (/tapper/) opens a wearer's real profile from the band link, so
// public site pages must never link to it. (The band-address redirect stubs at the
// repo root, like tapper.html and card.html, are not in `pages` and keep working.)
const noTapperLinks = pages.filter((p) => p !== 'tapper/index.html');

for (const page of pages) {
  const file = path.join(root, page);
  if (!existsSync(file)) {
    problems.push(`${page}: page itself is missing`);
    continue;
  }
  const html = readFileSync(file, 'utf8');
  for (const m of html.matchAll(/\b(?:href|src|poster)\s*=\s*"([^"]*)"/g)) check(page, m[1]);
  if (noTapperLinks.includes(page)) {
    for (const m of html.matchAll(/<a\b[^>]*\bhref\s*=\s*"([^"]*tapper[^"]*)"/gi)) {
      problems.push(`${page}: links to the tap page (${m[1]}); public pages must not`);
    }
  }
}

for (const css of stylesheets) {
  const file = path.join(root, css);
  if (!existsSync(file)) {
    problems.push(`${css}: stylesheet itself is missing`);
    continue;
  }
  for (const m of readFileSync(file, 'utf8').matchAll(/url\(\s*['"]?([^'")]+)['"]?\s*\)/g)) check(css, m[1]);
}

if (problems.length) {
  console.error(`FAIL ${problems.length} link(s) point at files that do not exist:`);
  for (const p of problems) console.error(`  ${p}`);
  process.exit(1);
}
console.log(`OK   ${checked} local links across ${pages.length} pages + ${stylesheets.length} stylesheet all point at real files`);
