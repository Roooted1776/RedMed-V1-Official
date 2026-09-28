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
 * Optional:
 *   HOSTINGER_USERNAME=u666300215  — prefer this plan when domain filter misses
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
const PREFERRED_USERNAME = (process.env.HOSTINGER_USERNAME || 'u666300215').trim();

if (!TOKEN) {
  console.error('HOSTINGER_API_TOKEN required');
  process.exit(1);
}
if (!fs.existsSync(path.join(STAGE_DIR, 'index.html'))) {
  console.error('Missing staged index.html — run: bash scripts/stage-site.sh');
  process.exit(1);
}

const stamp = new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14);
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

function rowsFrom(body) {
  if (Array.isArray(body)) return body;
  if (Array.isArray(body?.data)) return body.data;
  if (Array.isArray(body?.data?.data)) return body.data.data;
  return [];
}

function siteDomain(site) {
  return String(site?.domain || site?.vhost || site?.hostname || '').toLowerCase();
}

function summarizeSites(sites) {
  return sites.map((s) => ({
    domain: siteDomain(s) || '(none)',
    username: s?.username || null,
    website_type: s?.website_type || null,
    order_id: s?.order_id ?? null,
    is_enabled: s?.is_enabled ?? null,
  }));
}

async function listWebsites(query) {
  const qs = new URLSearchParams(query);
  const body = await api('get', `api/hosting/v1/websites?${qs}`);
  return rowsFrom(body);
}

async function listAllWebsites() {
  const out = [];
  for (let page = 1; page <= 20; page++) {
    const rows = await listWebsites({ page: String(page), per_page: '50' });
    out.push(...rows);
    if (rows.length < 50) break;
  }
  return out;
}

/**
 * Resolve Hostinger account username + deploy hostname.
 * Domain filter often misses when the plan hostname is a free subdomain and
 * redmed.live is only an alias / parked name (docs/domain.md).
 */
async function resolveWebsite(wantDomain) {
  const want = wantDomain.toLowerCase();

  let sites = await listWebsites({ domain: wantDomain });
  let hit = sites.find((s) => siteDomain(s) === want) || sites[0];
  if (hit?.username) {
    return { username: hit.username, domain: siteDomain(hit) || wantDomain, via: 'domain-filter' };
  }

  if (PREFERRED_USERNAME) {
    sites = await listWebsites({ username: PREFERRED_USERNAME });
    hit =
      sites.find((s) => siteDomain(s) === want) ||
      sites.find((s) => siteDomain(s).includes(want)) ||
      sites[0];
    if (hit?.username) {
      const resolvedDomain = siteDomain(hit) || wantDomain;
      console.warn(
        `Domain filter missed ${wantDomain}; using plan site ${resolvedDomain} (username=${hit.username})`,
      );
      return { username: hit.username, domain: resolvedDomain, via: 'username-filter' };
    }
  }

  sites = await listAllWebsites();
  hit =
    sites.find((s) => siteDomain(s) === want) ||
    sites.find((s) => siteDomain(s).includes(want)) ||
    (PREFERRED_USERNAME && sites.find((s) => s?.username === PREFERRED_USERNAME)) ||
    null;

  if (hit?.username) {
    const resolvedDomain = siteDomain(hit) || wantDomain;
    console.warn(
      `Using Hostinger site ${resolvedDomain} (username=${hit.username}) for requested ${wantDomain}`,
    );
    return { username: hit.username, domain: resolvedDomain, via: 'inventory' };
  }

  const inventory = summarizeSites(sites);
  throw new Error(
    `No Hostinger website for ${wantDomain}` +
      (PREFERRED_USERNAME ? ` (also tried username=${PREFERRED_USERNAME})` : '') +
      `. Inventory (${inventory.length}): ${JSON.stringify(inventory)}`,
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
  const { username, domain, via } = await resolveWebsite(DOMAIN);
  console.log(`Resolved website username=${username} domain=${domain} via=${via}`);
  const basename = await uploadArchive(username, domain, archivePath);
  // Prefer the API hostname we resolved; if that differs from the product
  // hostname, also try the product domain on the same username.
  let result;
  try {
    result = await api('post', `api/hosting/v1/accounts/${username}/websites/${domain}/deploy`, {
      archive_path: basename,
    });
  } catch (err) {
    if (domain !== DOMAIN) {
      console.warn(`Deploy on ${domain} failed (${err.message}); retrying product host ${DOMAIN}`);
      result = await api('post', `api/hosting/v1/accounts/${username}/websites/${DOMAIN}/deploy`, {
        archive_path: basename,
      });
      console.log(JSON.stringify({ domain: DOMAIN, username, archive: basename, result, via }, null, 2));
      fs.unlinkSync(archivePath);
      return;
    }
    throw err;
  }
  console.log(JSON.stringify({ domain, username, archive: basename, result, via }, null, 2));
  fs.unlinkSync(archivePath);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
