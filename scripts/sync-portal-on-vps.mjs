#!/usr/bin/env node
/**
 * Run on the VPS (or inside the redmed-mcp container, which has the Docker socket).
 * Pulls this repo archive and publishes portal/ + tapper/ + Document/ as the
 * redmed.live site.
 *
 *   node scripts/sync-portal-on-vps.mjs https://codeload.github.com/Roooted1776/RedMed-V1-Official/tar.gz/<sha>
 */
import http from 'node:http';
import zlib from 'node:zlib';

const archiveUrl = process.argv[2];
const IMAGE = process.env.REDMED_PORTAL_IMAGE || 'redmed-portal:20260926-portal-v4';
const HOST_DIR = '/opt/redmed-portal';
if (!archiveUrl) {
  console.error('Usage: node scripts/sync-portal-on-vps.mjs <tar.gz url>');
  process.exit(1);
}

function docker(method, urlPath, body, headers = {}) {
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        socketPath: '/var/run/docker.sock',
        method,
        path: urlPath,
        headers: body
          ? { ...headers, 'Content-Length': Buffer.byteLength(body) }
          : headers,
      },
      (res) => {
        const chunks = [];
        res.on('data', (c) => chunks.push(c));
        res.on('end', () => {
          resolve({
            status: res.statusCode,
            headers: res.headers,
            body: Buffer.concat(chunks),
          });
        });
      }
    );
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

function demux(buf) {
  let out = '';
  let i = 0;
  while (i + 8 <= buf.length) {
    const size = buf.readUInt32BE(i + 4);
    out += buf.subarray(i + 8, i + 8 + size).toString('utf8');
    i += 8 + size;
  }
  return out || buf.toString('utf8');
}

function parseTar(buf) {
  const files = [];
  let offset = 0;
  let paxPath = '';
  while (offset + 512 <= buf.length) {
    const header = buf.subarray(offset, offset + 512);
    if (header.every((b) => b === 0)) break;
    const name = header.subarray(0, 100).toString('utf8').replace(/\0.*$/, '');
    const prefix = header.subarray(345, 500).toString('utf8').replace(/\0.*$/, '');
    const size = parseInt(header.subarray(124, 136).toString('utf8').replace(/\0/g, '').trim() || '0', 8) || 0;
    const type = String.fromCharCode(header[156] || 48);
    offset += 512;
    const data = buf.subarray(offset, offset + size);
    offset += Math.ceil(size / 512) * 512;
    const full = paxPath || (prefix ? `${prefix}/${name}` : name);
    paxPath = '';
    if (type === 'x' || type === 'g') {
      const text = data.toString('utf8');
      const match = text.match(/(?:^|\n)path=([^\n]+)/);
      if (match) paxPath = match[1];
      continue;
    }
    if (type === '0' || type === '\0') files.push({ name: full, data: Buffer.from(data) });
  }
  return files;
}

function octal(value, length) {
  const s = value.toString(8).padStart(length - 1, '0');
  return (s + '\0').slice(0, length);
}

function tarEntries(entries) {
  const chunks = [];
  for (const ent of entries) {
    const header = Buffer.alloc(512);
    if (ent.name.length > 100) throw new Error(`tar name too long: ${ent.name}`);
    header.write(ent.name, 0, 'utf8');
    header.write(octal(0o644, 8), 100);
    header.write(octal(0, 8), 108);
    header.write(octal(0, 8), 116);
    header.write(octal(ent.data.length, 12), 124);
    header.write(octal(0, 12), 136);
    header[156] = 48;
    header.write('ustar\0', 257);
    header.write('00', 263);
    for (let i = 148; i < 156; i += 1) header[i] = 32;
    let sum = 0;
    for (const b of header) sum += b;
    header.write(octal(sum, 8), 148);
    const pad = (512 - (ent.data.length % 512)) % 512;
    chunks.push(header, ent.data, Buffer.alloc(pad));
  }
  chunks.push(Buffer.alloc(1024));
  return Buffer.concat(chunks);
}

function wanted(rel) {
  if (rel === 'portal/server.mjs') return 'server.mjs';
  if (rel.startsWith('portal/site/')) return rel.slice('portal/'.length);
  if (rel.startsWith('tapper/')) return `site/${rel}`;
  if (rel.startsWith('Document/')) return `site/${rel}`;
  if (rel.startsWith('get/')) return `site/${rel}`;
  if (rel.startsWith('.well-known/')) return `site/${rel}`;
  if (['get.html', 'card.html', 'tapper.html', 'redmed-emergency.html', 'apple-app-site-association'].includes(rel)) {
    return `site/${rel}`;
  }
  if (['assets/BrandLogo.png', 'assets/BrandWordmark.png', 'assets/pheart.png'].includes(rel)) {
    return `site/${rel}`;
  }
  return null;
}

async function download(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`download ${url} → ${res.status}`);
  const gz = Buffer.from(await res.arrayBuffer());
  return zlib.gunzipSync(gz);
}

const labels = {
  'traefik.enable': 'true',
  'traefik.http.services.redmed-portal.loadbalancer.server.port': '8090',
  'traefik.http.middlewares.redmed-portal-slash.redirectregex.permanent': 'true',
  'traefik.http.middlewares.redmed-portal-slash.redirectregex.regex': '^(https?://[^/]+/redmed)$',
  'traefik.http.middlewares.redmed-portal-slash.redirectregex.replacement': '${1}/',
  'traefik.http.middlewares.redmed-portal-strip.stripprefix.prefixes': '/redmed',
  'traefik.http.routers.redmed-portal.rule': 'Host(`srv2010795.hstgr.cloud`) && (Path(`/redmed`) || PathPrefix(`/redmed/`))',
  'traefik.http.routers.redmed-portal.entrypoints': 'websecure',
  'traefik.http.routers.redmed-portal.tls': 'true',
  'traefik.http.routers.redmed-portal.tls.certresolver': 'letsencrypt',
  'traefik.http.routers.redmed-portal.middlewares': 'redmed-portal-slash,redmed-portal-strip',
  'traefik.http.routers.redmed-portal.priority': '100',
  'traefik.http.routers.redmed-portal.service': 'redmed-portal',
  'traefik.http.routers.redmed-live.rule': 'Host(`redmed.live`) || Host(`www.redmed.live`)',
  'traefik.http.routers.redmed-live.entrypoints': 'websecure',
  'traefik.http.routers.redmed-live.tls': 'true',
  'traefik.http.routers.redmed-live.tls.certresolver': 'letsencrypt',
  'traefik.http.routers.redmed-live.priority': '100',
  'traefik.http.routers.redmed-live.service': 'redmed-portal',
};

async function main() {
  console.log('download', archiveUrl);
  const raw = await download(archiveUrl);
  const files = parseTar(raw);
  const entries = [];
  for (const file of files) {
    const parts = file.name.split('/');
    const rel = parts.slice(1).join('/');
    const dest = wanted(rel);
    if (!dest) continue;
    entries.push({ name: dest, data: file.data });
  }
  const names = new Set(entries.map((e) => e.name));
  for (const required of ['server.mjs', 'site/index.html', 'site/legacy.js', 'site/tapper/index.html', 'site/Document/index.html']) {
    if (!names.has(required)) throw new Error(`archive missing ${required}`);
  }
  console.log('files', entries.length);

  const list = JSON.parse((await docker('GET', '/containers/json?all=1')).body.toString());
  const byName = (n) => list.find((c) => (c.Names || []).includes(n));

  async function remove(name) {
    const existing = byName(name);
    if (!existing) return;
    await docker('POST', `/containers/${existing.Id}/stop?t=5`);
    const del = await docker('DELETE', `/containers/${existing.Id}?force=1`);
    console.log('removed', name, del.status);
  }

  await remove('/redmed-portal-seed');
  const seedBody = JSON.stringify({
    Image: IMAGE,
    Cmd: ['sleep', '180'],
    HostConfig: { Binds: [`${HOST_DIR}:/dest`] },
  });
  const seed = await docker('POST', '/containers/create?name=redmed-portal-seed', seedBody, {
    'Content-Type': 'application/json',
  });
  if (seed.status !== 201) throw new Error(`seed create ${seed.status} ${seed.body.toString().slice(0, 300)}`);
  const seedId = JSON.parse(seed.body.toString()).Id;
  const seedStart = await docker('POST', `/containers/${seedId}/start`);
  if (seedStart.status !== 204 && seedStart.status !== 304) {
    throw new Error(`seed start ${seedStart.status} ${seedStart.body.toString().slice(0, 300)}`);
  }
  const tar = tarEntries(entries);
  const put = await docker(
    'PUT',
    `/containers/${seedId}/archive?path=${encodeURIComponent('/dest')}`,
    tar,
    { 'Content-Type': 'application/x-tar' }
  );
  if (put.status !== 200) throw new Error(`archive put ${put.status} ${put.body.toString().slice(0, 300)}`);
  console.log('wrote', HOST_DIR);
  await docker('POST', `/containers/${seedId}/stop?t=2`);
  await docker('DELETE', `/containers/${seedId}?force=1`);

  const old = byName('/redmed-portal-20260926-portal-v4');
  if (old) {
    await docker('POST', `/containers/${old.Id}/stop?t=5`);
    console.log('stopped previous portal');
  }
  await remove('/redmed-portal-live');

  const liveBody = JSON.stringify({
    Image: IMAGE,
    Cmd: ['node', '/server.mjs'],
    Env: ['PORT=8090', 'STATIC_ROOT=/site'],
    Labels: labels,
    HostConfig: {
      NetworkMode: 'host',
      Binds: [`${HOST_DIR}/server.mjs:/server.mjs:ro`, `${HOST_DIR}/site:/site:ro`],
      RestartPolicy: { Name: 'unless-stopped' },
    },
  });
  const live = await docker('POST', '/containers/create?name=redmed-portal-live', liveBody, {
    'Content-Type': 'application/json',
  });
  if (live.status !== 201) throw new Error(`live create ${live.status} ${live.body.toString().slice(0, 400)}`);
  const liveId = JSON.parse(live.body.toString()).Id;
  const liveStart = await docker('POST', `/containers/${liveId}/start`);
  if (liveStart.status !== 204 && liveStart.status !== 304) {
    throw new Error(`live start ${liveStart.status} ${liveStart.body.toString().slice(0, 400)}`);
  }

  await new Promise((r) => setTimeout(r, 400));
  const health = await new Promise((resolve, reject) => {
    http.get('http://127.0.0.1:8090/healthz', (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => resolve({ status: res.statusCode, body: Buffer.concat(chunks).toString('utf8') }));
    }).on('error', reject);
  });
  const home = await new Promise((resolve, reject) => {
    http.get('http://127.0.0.1:8090/', (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    }).on('error', reject);
  });
  const tap = await new Promise((resolve, reject) => {
    http.get('http://127.0.0.1:8090/tapper/', (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => resolve({ status: res.statusCode, body: Buffer.concat(chunks).toString('utf8') }));
    }).on('error', reject);
  });
  console.log('health', health.status, health.body);
  console.log('home title', (home.match(/<title>[^<]+/) || [''])[0]);
  console.log('tapper', tap.status, (tap.body.match(/<title>[^<]+/) || ['no title'])[0]);
  if (health.status !== 200 || !home.includes('A small band') || tap.status !== 200 || !tap.body.includes('data-tab="medical"')) {
    console.error(demux(Buffer.from('')));
    throw new Error('portal health check failed');
  }
  console.log('portal live on 127.0.0.1:8090');
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
