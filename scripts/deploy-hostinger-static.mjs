#!/usr/bin/env node
/**
 * Deploy staged passerby static assets to Hostinger (no build step).
 *
 * Prereqs:
 *   bash scripts/stage-site.sh
 *   HOSTINGER_API_TOKEN in env (hPanel → Profile & settings → API Tokens)
 *
 * Usage:
 *   npm install --no-save axios tus-js-client   # once per machine
 *   node scripts/deploy-hostinger-static.mjs redmed.live
 *   node scripts/deploy-hostinger-static.mjs redmed.live dist/passerby
 *
 * redmed.live / www.redmed.live refuse this upload unless
 * REDMED_ALLOW_HOMEPAGE_REPLACE=1. The archive is a full docroot replace.
 * Live / is index.html (home/index.html). The store is init.html. Both go
 * out through scripts/deploy-vps.sh. This shared-static path is dead on
 * this account and must not overwrite either file.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const BASE = 'https://developers.hostinger.com/';
const TOKEN = process.env.HOSTINGER_API_TOKEN;
const DOMAIN = process.argv[2] || 'redmed.live';
const STAGE_DIR = path.resolve(ROOT, process.argv[3] || 'dist/passerby');

function isLiveMarketingHost(domain) {
  const host = String(domain || '').toLowerCase().replace(/\.$/, '');
  return host === 'redmed.live' || host === 'www.redmed.live';
}

// Refuse before zip, token use, or the Hostinger API. A missing axios install
// must not be the only thing standing between this archive and the homepage.
if (isLiveMarketingHost(DOMAIN) && process.env.REDMED_ALLOW_HOMEPAGE_REPLACE !== '1') {
  console.error(
    `REFUSING upload to ${DOMAIN} — use scripts/deploy-vps.sh. Live / is index.html (home/index.html). The store is init.html. Shared-static upload left unchanged. Assist stays at /tapper/. Set REDMED_ALLOW_HOMEPAGE_REPLACE=1 only for a deliberate shared-static replace.`,
  );
  process.exit(2);
}

if (!TOKEN) {
  console.error('HOSTINGER_API_TOKEN required');
  process.exit(1);
}

const { default: axios } = await import('axios');
const { default: tus } = await import('tus-js-client');
if (!fs.existsSync(path.join(STAGE_DIR, 'index.html'))) {
  console.error('Missing staged index.html — run: bash scripts/stage-site.sh');
  process.exit(1);
}

const stamp = new Date().toISOString().replace(/[-:TZ]/g, '').slice(0, 14);
const archiveName = `passerby_${stamp}.zip`;
const archivePath = path.join('/tmp', archiveName);

execSync(`cd "${STAGE_DIR}" && zip -r "${archivePath}" . -x "*.DS_Store"`, { stdio: 'inherit' });

const headers = { Accept: 'application/json', Authorization: `Bearer ${TOKEN}` };

async function api(method, urlPath, data) {
  const res = await axios({
    method,
    url: new URL(urlPath, BASE).toString(),
    headers: { ...headers, ...(data ? { 'Content-Type': 'application/json' } : {}) },
    data,
    validateStatus: () => true,
    timeout: 120000,
  });
  if (res.status >= 400) {
    const err = new Error(`${method} ${urlPath} → ${res.status}: ${JSON.stringify(res.data)}`);
    err.status = res.status;
    err.body = res.data;
    throw err;
  }
  return res.data;
}

function websitesFrom(body) {
  if (Array.isArray(body?.data)) return body.data;
  if (Array.isArray(body)) return body;
  return [];
}

function siteDomain(site) {
  return String(site?.domain || site?.domain_name || site?.vhost || '').toLowerCase();
}

function inventoryLine(site) {
  const d = siteDomain(site) || '(no-domain)';
  const u = site?.username || '(no-user)';
  const t = site?.website_type || site?.vhost_type || '?';
  const en = site?.is_enabled === false ? 'disabled' : 'enabled';
  return `${u} ${d} type=${t} ${en}`;
}

async function listAllWebsites() {
  const all = [];
  for (let page = 1; page <= 10; page++) {
    const body = await api('get', `api/hosting/v1/websites?per_page=100&page=${page}`);
    const batch = websitesFrom(body);
    all.push(...batch);
    const total = body?.meta?.total ?? body?.total;
    if (!batch.length) break;
    if (typeof total === 'number' && all.length >= total) break;
    if (batch.length < 100) break;
  }
  return all;
}

// Exit code for "this token has no usable website for this domain" — a known,
// expected condition (e.g. an account that only holds a VPS product), distinct
// from exit 1 (an unexpected/real error) and exit 2 (homepage-replace refusal).
// Callers (CI) should branch on this code, not on error message text, which
// can be reworded without anyone remembering to update a grep elsewhere.
const NO_WEBSITE_EXIT_CODE = 3;

function noWebsiteError(message) {
  const err = new Error(message);
  err.deployExitCode = NO_WEBSITE_EXIT_CODE;
  return err;
}

/**
 * Resolve { username, domain } for the deploy API.
 * Requires an exact website row for the requested hostname — never guesses
 * at a "close enough" site, since a wrong guess means uploading production
 * content to someone else's website with no way to detect it downstream.
 */
async function resolveTarget(domain) {
  const needle = String(domain || '').toLowerCase();
  const all = await listAllWebsites();

  console.log(`Hostinger websites visible to token (${all.length}):`);
  for (const site of all.slice(0, 40)) {
    console.log(`  - ${inventoryLine(site)}`);
  }
  if (!all.length) {
    throw noWebsiteError(
      `No Hostinger shared-hosting website is visible to this token for ${needle}. ` +
        'This account may only hold a VPS/other product — redmed.live is actually served ' +
        'from the Hostinger VPS + Traefik, not this deploy path (see docs/release/OPS.md).',
    );
  }

  const exact = all.find((s) => siteDomain(s) === needle && s?.username);
  if (exact) {
    return { username: exact.username, domain: siteDomain(exact) };
  }

  throw noWebsiteError(
    `No exact Hostinger website match for ${needle}. Token sees: ${all.map(inventoryLine).join(' | ')}`,
  );
}

async function uploadArchive(username, domain, filePath) {
  let creds;
  try {
    creds = await api('post', 'api/hosting/v1/files/upload-urls', { username, domain });
  } catch (err) {
    if (err.status === 404) {
      throw new Error(
        `upload-urls 404 for username=${username} domain=${domain}. ` +
          'That site is not on this token — recreate the Hostinger website or check the domain.',
      );
    }
    throw err;
  }
  const { url: uploadUrl, auth_key: authToken, rest_auth_key: authRestToken } = creds;
  const basename = path.basename(filePath);
  const stats = fs.statSync(filePath);
  const uploadUrlWithFile = `${uploadUrl.replace(/\/$/, '')}/${basename}?override=true`;
  const requestHeaders = {
    'X-Auth': authToken,
    'X-Auth-Rest': authRestToken,
    'upload-length': String(stats.size),
    'upload-offset': '0',
  };

  await axios.post(uploadUrlWithFile, '', {
    headers: requestHeaders,
    validateStatus: (s) => s === 201,
    timeout: 120000,
  });

  await new Promise((resolve, reject) => {
    const upload = new tus.Upload(fs.createReadStream(filePath), {
      uploadUrl: uploadUrlWithFile,
      retryDelays: [1000, 2000, 4000, 8000],
      uploadDataDuringCreation: false,
      parallelUploads: 1,
      chunkSize: 10485760,
      headers: requestHeaders,
      uploadSize: stats.size,
      metadata: { filename: basename },
      onError: reject,
      onSuccess: resolve,
    });
    upload.start();
  });

  return basename;
}

async function main() {
  console.log(`Deploying ${archivePath} → ${DOMAIN}`);
  const target = await resolveTarget(DOMAIN);
  console.log(`Resolved deploy target username=${target.username} domain=${target.domain}`);
  const basename = await uploadArchive(target.username, target.domain, archivePath);
  const result = await api(
    'post',
    `api/hosting/v1/accounts/${target.username}/websites/${target.domain}/deploy`,
    { archive_path: basename },
  );
  console.log(JSON.stringify({ requested: DOMAIN, ...target, archive: basename, result }, null, 2));
  fs.unlinkSync(archivePath);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(err.deployExitCode || 1);
});
