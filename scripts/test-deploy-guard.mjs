#!/usr/bin/env node
/**
 * The Hostinger static upload is a full docroot replace. Live / is
 * index.html (home/index.html) and the store is init.html (deploy-vps.sh).
 * The shared-static script must refuse redmed.live before it zips, talks
 * to the API, or needs axios.
 */
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const script = path.join(path.dirname(fileURLToPath(import.meta.url)), 'deploy-hostinger-static.mjs');

function run(args, env) {
  return spawnSync(process.execPath, [script, ...args], {
    env: { ...process.env, ...env },
    encoding: 'utf8',
  });
}

function fail(msg) {
  console.error(`FAIL ${msg}`);
  process.exit(1);
}

const refused = run(['redmed.live'], { HOSTINGER_API_TOKEN: 'must-not-be-sent', REDMED_ALLOW_HOMEPAGE_REPLACE: '' });
const refusedText = `${refused.stdout || ''}\n${refused.stderr || ''}`;
if (refused.status !== 2) fail(`redmed.live exit ${refused.status}, want 2\n${refusedText}`);
if (!/REFUSING upload to redmed\.live/.test(refusedText)) fail(`missing REFUSING line\n${refusedText}`);
if (/Deploying /.test(refusedText)) fail('refuse path still started an upload');
if (/developers\.hostinger\.com/.test(refusedText)) fail('refuse path contacted Hostinger');
console.log('OK   redmed.live upload refused before any API call');

const www = run(['www.redmed.live'], { HOSTINGER_API_TOKEN: 'must-not-be-sent', REDMED_ALLOW_HOMEPAGE_REPLACE: '' });
const wwwText = `${www.stdout || ''}\n${www.stderr || ''}`;
if (www.status !== 2 || !/REFUSING upload to www\.redmed\.live/.test(wwwText)) {
  fail(`www host not refused\n${wwwText}`);
}
console.log('OK   www.redmed.live upload refused');

const other = run(['example.test'], { HOSTINGER_API_TOKEN: '', REDMED_ALLOW_HOMEPAGE_REPLACE: '' });
const otherText = `${other.stdout || ''}\n${other.stderr || ''}`;
if (other.status === 2 || /REFUSING upload/.test(otherText)) fail('refuse applied to a non-production host');
if (other.status !== 1 || !/HOSTINGER_API_TOKEN required/.test(otherText)) {
  fail(`other host should stop on missing token, got ${other.status}\n${otherText}`);
}
console.log('OK   other hosts still require a token');

const override = run(['redmed.live'], {
  HOSTINGER_API_TOKEN: '',
  REDMED_ALLOW_HOMEPAGE_REPLACE: '1',
});
const overrideText = `${override.stdout || ''}\n${override.stderr || ''}`;
if (/REFUSING upload/.test(overrideText)) fail('explicit override still refused');
if (override.status !== 1 || !/HOSTINGER_API_TOKEN required/.test(overrideText)) {
  fail(`override should stop on missing token, got ${override.status}\n${overrideText}`);
}
console.log('OK   REDMED_ALLOW_HOMEPAGE_REPLACE=1 skips the refuse');
