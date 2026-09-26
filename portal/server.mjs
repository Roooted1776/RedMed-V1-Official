import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

const root = path.resolve(process.env.STATIC_ROOT || '/site');
const types = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.webp': 'image/webp',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.json': 'application/json',
  '.txt': 'text/plain; charset=utf-8',
  '.webmanifest': 'application/manifest+json',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ico': 'image/x-icon',
};

// Account portal only. Assist (/tapper/) and policy pages keep their own inline
// scripts and must not inherit this policy.
const accountPolicy = [
  "default-src 'self'",
  "script-src 'self'",
  "style-src 'self' 'unsafe-inline' https://api.fontshare.com",
  "font-src 'self' https://cdn.fontshare.com https://api.fontshare.com",
  "img-src 'self' data:",
  "connect-src 'self' https://mohxobgyjkcmkqxijgeg.supabase.co",
  "frame-ancestors 'none'",
  "base-uri 'self'",
  "object-src 'none'",
  "form-action 'self'",
  'upgrade-insecure-requests',
].join('; ');

function send(res, status, body, headers) {
  res.writeHead(status, headers);
  res.end(body);
}

http.createServer((req, res) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=(), nfc=(self)');

  let pathname;
  try {
    pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  } catch {
    return send(res, 400, 'Bad request');
  }

  if (pathname === '/healthz') {
    return send(res, 200, '{"ok":true,"service":"redmed-portal"}', {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
    });
  }

  // Old VPS path. Traefik already strips /redmed on the PTR host, so this
  // only runs for the main domain.
  if (pathname === '/redmed' || pathname.startsWith('/redmed/')) {
    const dest = pathname.slice('/redmed'.length) || '/';
    res.writeHead(301, { Location: dest });
    return res.end();
  }

  if (!['GET', 'HEAD'].includes(req.method)) {
    res.writeHead(405, { Allow: 'GET, HEAD' });
    return res.end();
  }

  if (pathname === '/' || pathname === '/index.html') {
    res.setHeader('Content-Security-Policy', accountPolicy);
  }

  const rel = pathname.endsWith('/') ? pathname + 'index.html' : pathname;
  const target = path.resolve(root, '.' + rel);
  if (!target.startsWith(root + '/') || !fs.existsSync(target) || !fs.statSync(target).isFile()) {
    return send(res, 404, 'Not found');
  }

  const base = path.basename(target);
  const ext = path.extname(target);
  const type = base === 'apple-app-site-association'
    ? 'application/json'
    : (types[ext] || 'application/octet-stream');
  res.setHeader('Content-Type', type);
  res.setHeader(
    'Cache-Control',
    ext === '.html' || base === 'apple-app-site-association'
      ? 'no-store'
      : pathname.startsWith('/assets/')
        ? 'public, max-age=31536000, immutable'
        : 'public, max-age=3600'
  );
  if (req.method === 'HEAD') return res.end();

  const stream = fs.createReadStream(target);
  stream.on('error', () => res.destroy());
  if (/\bgzip\b/.test(req.headers['accept-encoding'] || '') && ['.html', '.css', '.js', '.svg'].includes(ext)) {
    res.setHeader('Content-Encoding', 'gzip');
    res.setHeader('Vary', 'Accept-Encoding');
    stream.pipe(zlib.createGzip()).pipe(res);
  } else {
    stream.pipe(res);
  }
}).listen(Number(process.env.PORT || 8090), '127.0.0.1');
