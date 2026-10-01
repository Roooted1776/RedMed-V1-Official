#!/usr/bin/env node
/**
 * The Store's pack settings (store/config.js) must be safe and consistent:
 *   - pack ids are unique, prices are positive whole numbers, band counts are positive
 *   - any pack link that is filled in is a public Square link (same rule as
 *     store/store.js), never a token, never another site
 *   - no secret-looking value (access token) is present in config.js
 *   - the support email in config.js is the one the Store page links to
 *   - the starting prices in store/index.html match config.js (default pack: Pair)
 * Empty links are allowed: the Store then offers "Order by email".
 */
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import vm from 'node:vm';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const configSrc = readFileSync(path.join(root, 'store/config.js'), 'utf8');
const storeJs = readFileSync(path.join(root, 'store/store.js'), 'utf8');

const sandbox = { window: {} };
vm.runInNewContext(configSrc, sandbox);
const cfg = sandbox.window.REDMED_STORE;

const problems = [];
const fail = (m) => problems.push(m);

if (!cfg || !Array.isArray(cfg.tiers) || cfg.tiers.length === 0) {
  fail('store/config.js: window.REDMED_STORE.tiers is missing or empty');
} else {
  const ids = new Set();
  // Same rule as `var ok = ...` in store/store.js
  const ruleMatch = storeJs.match(/var ok = (\/\^https[^;]+\/);/);
  if (!ruleMatch) fail('store/store.js: could not find the live-link rule (var ok = /^https.../)');
  const liveRule = ruleMatch ? new RegExp(ruleMatch[1].slice(1, ruleMatch[1].lastIndexOf('/'))) : null;

  for (const t of cfg.tiers) {
    const name = t.id || '(no id)';
    if (!t.id) fail('a pack has no id');
    if (ids.has(t.id)) fail(`pack id "${t.id}" is used twice`);
    ids.add(t.id);
    if (!Number.isInteger(t.price) || t.price <= 0) fail(`${name}: price must be a positive whole number, got ${t.price}`);
    if (!Number.isInteger(t.bands) || t.bands <= 0) fail(`${name}: bands must be a positive whole number, got ${t.bands}`);
    if (typeof t.link !== 'string') fail(`${name}: link must be a string ("" until the Square link exists)`);
    else if (t.link !== '' && liveRule && !liveRule.test(t.link)) {
      fail(`${name}: link "${t.link}" is not a public Square link (https://square.link/u/... or https://checkout.square.site/...)`);
    }
  }
}

if (/EAAA[A-Za-z0-9_-]{20,}|sq0[a-z]{3}-[A-Za-z0-9_-]{20,}/.test(configSrc)) {
  fail('store/config.js: looks like it contains a Square access token or secret. Remove it immediately.');
}

const html = readFileSync(path.join(root, 'store/index.html'), 'utf8');
if (cfg && cfg.supportEmail && !html.includes(cfg.supportEmail)) {
  fail(`store/index.html does not mention the support email "${cfg.supportEmail}" from config.js`);
}

// Before the script runs, the page shows the default pack's price (Pair is selected first).
// Those starting prices must match config.js.
const dflt = cfg && cfg.tiers && cfg.tiers.find((t) => t.id === 'pair');
if (dflt) {
  for (const [what, re] of [
    ['order summary', /id="sumPrice">([^<]*)</],
    ['sticky bar', /id="stickyText">[^<]*?&middot;\s*([^<]*)</],
    ['checkout box', /id="reviewPrice">([^<]*)</],
  ]) {
    const m = html.match(re);
    if (!m) fail(`store/index.html: could not find the starting price in the ${what}`);
    else if (m[1].trim() !== `$${dflt.price}`) fail(`store/index.html: ${what} starts at ${m[1].trim()} but config.js says $${dflt.price} for Pair`);
  }
}

if (problems.length) {
  console.error(`FAIL ${problems.length} Store config problem(s):`);
  for (const p of problems) console.error(`  ${p}`);
  process.exit(1);
}
const live = cfg.tiers.filter((t) => t.link).length;
console.log(`OK   ${cfg.tiers.length} packs, ${live} with a live Square link, ${cfg.tiers.length - live} on "Order by email"; no secrets in store/config.js`);
