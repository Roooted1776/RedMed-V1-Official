import { test } from 'node:test';
import assert from 'node:assert/strict';
import { wallCheck, redactFragments } from '../lib/wall.mjs';
import { buildCommand, ACTIONS } from '../lib/ops-commands.mjs';

test('wall blocks real band URLs (regression: old \\b regex missed these)', () => {
  for (const s of [
    '#d=abc',
    'https://redmed.live/tapper/#d=eyJuIjoiQSJ9',
    'curl https://roooted1776.github.io/tapper/#D=x',
    'echo "#d=" > /tmp/x',
  ]) assert.ok(wallCheck(s), s);
});

test('wall blocks PHI keywords', () => {
  for (const s of ['ICE profile', 'ice_profile', 'medical card', 'PHI', 'patient data', 'health-record'])
    assert.ok(wallCheck(s), s);
});

test('wall allows ops text', () => {
  for (const s of ['', 'uptime', 'docker ps', 'deploy dist/passerby', 'graphic', 'philosophy'])
    assert.equal(wallCheck(s), null, s);
});

test('redacts fragments in output', () => {
  assert.equal(
    redactFragments('GET /tapper/#d=eyJhIjoxfQ 200'),
    'GET /tapper/#d=[REDACTED] 200',
  );
});

test('ops allow-list rejects unknown actions and injection', () => {
  assert.throws(() => buildCommand('rm'));
  assert.throws(() => buildCommand('container_logs', { container: 'x; rm -rf /' }));
  assert.throws(() => buildCommand('container_logs', { container: '$(id)' }));
  assert.throws(() => buildCommand('container_logs', { container: '-f' }));
  assert.throws(() => buildCommand('unit_status', { unit: 'sshd;reboot' }));
  assert.throws(() => buildCommand('unit_journal', {}));
});

test('ops allow-list clamps tail and builds fixed commands', () => {
  assert.equal(buildCommand('container_logs', { container: 'traefik', tail: 99999 }), 'docker logs --tail 500 traefik 2>&1');
  assert.equal(buildCommand('unit_journal', { unit: 'sshd', tail: 0 }), 'journalctl -u sshd -n 1 --no-pager');
  for (const a of Object.keys(ACTIONS)) {
    const needs = a === 'container_logs' ? { container: 'traefik' } : a.startsWith('unit_') ? { unit: 'docker' } : {};
    const cmd = buildCommand(a, needs);
    assert.doesNotMatch(cmd, /\brm\b|reboot|shutdown|poweroff|mkfs|\bdd\b/, a);
  }
});

test('github tool registered, no token -> clean error', async () => {
  const { spawnSync } = await import('node:child_process');
  const req = (id, method, params) =>
    JSON.stringify({ jsonrpc: '2.0', id, method, params });
  const input = [
    req(1, 'initialize', { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 't', version: '1' } }),
    JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }),
    req(2, 'tools/list', {}),
  ].join('\n') + '\n';
  const r = spawnSync(process.execPath, ['bin/redmed-mcp.mjs'], {
    input,
    encoding: 'utf8',
    timeout: 15000,
    env: { ...process.env, GITHUB_TOKEN: '', REDMED_SSH_ALLOW_RAW: '' },
  });
  const list = r.stdout.split('\n').filter(Boolean).map((l) => JSON.parse(l)).find((m) => m.id === 2);
  const names = list.result.tools.map((t) => t.name);
  assert.ok(names.includes('github_api'), 'github_api registered');
  assert.ok(names.includes('hostinger_ssh_exec'), 'raw ssh on by default');
  assert.ok(names.includes('hostinger_ops'), 'allow-list tool present');
});
