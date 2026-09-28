#!/usr/bin/env node
/**
 * Deploy staged passerby static assets to Hostinger (no build step).
 *
 * Prereqs:
 *   bash scripts/stage-site.sh
 *   HOSTINGER_API_TOKEN in env (hPanel → Profile & settings → API Tokens)
 *   Optional: HOSTINGER_USERNAME (hPanel plan user, e.g. u666300215) when the
 *   websites?domain= filter returns empty — common for parked hostnames.
 *
 * Usage:
 *   npm install --no-save axios tus-js-client   # once per machine
 *   node scripts/deploy-hostinger-static.mjs redmed.live
 *   node scripts/deploy-hostinger-static.mjs redmed.live dist/passerby
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';
import axios from 'axios';
import tus from 'tus-js-client';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const BASE = 'https://developers.hostinger.com/';
const TOKEN = process.env.HOSTINGER_API_TOKEN;
const DOMAIN = process.argv[2] || 'redmed.live';
const STAGE_DIR = path.resolve(ROOT, process.argv[3] || 'dist/passerby');

if (!TOKEN) {
  console.error('HOSTINGER_API_TOKEN required');
  process.exit(1);
}
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
    throw new Error(`${method} ${urlPath} → ${res.status}: ${JSON.stringify(res.data)}`);
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

async function resolveUsername(domain) {
  const forced = (process.env.HOSTINGER_USERNAME || '').trim();
  if (forced) {
    console.log(`Using HOSTINGER_USERNAME=${forced}`);
    return forced;
  }

  const needle = String(domain || '').toLowerCase();
  const filtered = websitesFrom(
    await api('get', `api/hosting/v1/websites?domain=${encodeURIComponent(domain)}`),
  );
  let hit = filtered.find((s) => siteDomain(s) === needle && s?.username) || filtered.find((s) => s?.username);
  if (hit?.username) return hit.username;

  // Domain filter is empty for some parked / alias hostnames — scan the account.
  const all = websitesFrom(await api('get', 'api/hosting/v1/websites?per_page=100'));
  hit = all.find((s) => siteDomain(s) === needle && s?.username);
  if (hit?.username) return hit.username;

  // Documented product plan for redmed.live (docs/domain.md).
  if (needle === 'redmed.live') {
    console.warn('No websites?domain=redmed.live hit — falling back to u666300215');
    return 'u666300215';
  }

  const names = all.map((s) => siteDomain(s) || '(no-domain)').filter(Boolean).slice(0, 20);
  throw new Error(
    `No Hostinger website for ${domain}` +
      (names.length ? ` (saw: ${names.join(', ')})` : ' (websites list empty)'),
  );
}

async function uploadArchive(username, domain, filePath) {
  const creds = await api('post', 'api/hosting/v1/files/upload-urls', { username, domain });
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
  const username = await resolveUsername(DOMAIN);
  const basename = await uploadArchive(username, DOMAIN, archivePath);
  const result = await api('post', `api/hosting/v1/accounts/${username}/websites/${DOMAIN}/deploy`, {
    archive_path: basename,
  });
  console.log(JSON.stringify({ domain: DOMAIN, username, archive: basename, result }, null, 2));
  fs.unlinkSync(archivePath);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
