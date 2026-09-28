#!/usr/bin/env node
/**
 * Deploy staged passerby static assets to Hostinger (no build step).
 *
 * Prereqs:
 *   bash scripts/stage-site.sh
 *   HOSTINGER_API_TOKEN in env (hPanel → Profile & settings → API Tokens)
 *   Optional: HOSTINGER_USERNAME (hPanel plan user) when domain lookup is ambiguous.
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

/**
 * Resolve { username, domain } for the deploy API.
 * Prefer an exact website row for the requested hostname; never invent a
 * username that is not on the token's website list (upload-urls 404s).
 */
async function resolveTarget(domain) {
  const needle = String(domain || '').toLowerCase();
  const forcedUser = (process.env.HOSTINGER_USERNAME || '').trim();
  const all = await listAllWebsites();

  console.log(`Hostinger websites visible to token (${all.length}):`);
  for (const site of all.slice(0, 40)) {
    console.log(`  - ${inventoryLine(site)}`);
  }
  if (!all.length) {
    throw new Error(
      'Hostinger websites list is empty for this token — check HOSTSTINGER / HOSTINGER_API_TOKEN scope (hosting read+write).',
    );
  }

  const exact = all.find((s) => siteDomain(s) === needle && s?.username);
  if (exact) {
    return { username: exact.username, domain: siteDomain(exact) };
  }

  const fuzzy = all.find(
    (s) => siteDomain(s).includes(needle) && s?.username,
  );
  if (fuzzy) {
    console.warn(`No exact ${needle}; using ${siteDomain(fuzzy)}`);
    return { username: fuzzy.username, domain: siteDomain(fuzzy) };
  }

  if (forcedUser) {
    const forUser = all.filter((s) => s?.username === forcedUser);
    if (forUser.length) {
      // Prefer a site whose domain mentions redmed / the needle; else first.
      const preferred =
        forUser.find((s) => siteDomain(s).includes('redmed')) ||
        forUser.find((s) => siteDomain(s).includes(needle.split('.')[0])) ||
        forUser[0];
      console.warn(
        `No website row for ${needle}; using HOSTINGER_USERNAME=${forcedUser} site ${siteDomain(preferred)}`,
      );
      return { username: forcedUser, domain: siteDomain(preferred) };
    }
    console.warn(
      `HOSTINGER_USERNAME=${forcedUser} not in websites list — ignoring override`,
    );
  }

  // Last resort: single CloudLinux site on the account.
  const cloud = all.filter((s) => s?.username && siteDomain(s));
  if (cloud.length === 1) {
    console.warn(
      `Only one Hostinger site on token — deploying to ${siteDomain(cloud[0])} (requested ${needle})`,
    );
    return { username: cloud[0].username, domain: siteDomain(cloud[0]) };
  }

  throw new Error(
    `No Hostinger website for ${needle}. Token sees: ${all.map(inventoryLine).join(' | ')}`,
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
          'That site is not on this token — fix HOSTINGER_USERNAME / domain or recreate the Hostinger website.',
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
  process.exit(1);
});
