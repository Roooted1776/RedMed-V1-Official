/**
 * Allow-listed, read-only VPS ops commands.
 *
 * Why an allow-list: the previous tool took a free-form root shell string
 * and tried to block "destructive" patterns. Deny-lists lose: `rm -r -f /`,
 * `systemctl poweroff`, `sh -c "$(echo ...|base64 -d)"`, and even plain
 * `rm -rf /` (trailing `\b` after `/` never matched) all passed. An MCP
 * tool is driven by a model that reads untrusted text, so treat its input
 * like any other untrusted request body: map it to a fixed set of
 * commands, validate every parameter, never interpolate raw strings.
 *
 * ssh joins argv into one remote shell string, so every dynamic value here
 * must match a strict pattern before it is placed in the command.
 */
const NAME = /^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$/;

export const UNITS = ['docker', 'ssh', 'sshd', 'fail2ban', 'ufw', 'cron'];

function lines(n) {
  const v = Number.isInteger(n) ? n : 100;
  return Math.min(Math.max(v, 1), 500);
}

export const ACTIONS = {
  uptime: () => 'uptime',
  disk: () => 'df -h -x tmpfs -x devtmpfs',
  memory: () => 'free -m',
  docker_ps: () => "docker ps --format '{{.Names}}\\t{{.Image}}\\t{{.Status}}'",
  traefik_ps: () => "docker ps --filter name=traefik --format '{{.Names}}\\t{{.Status}}'",
  container_logs: ({ container, tail }) => {
    if (!NAME.test(container || '')) throw new Error('container must match ' + NAME);
    return `docker logs --tail ${lines(tail)} ${container} 2>&1`;
  },
  unit_status: ({ unit }) => {
    if (!UNITS.includes(unit)) throw new Error('unit must be one of: ' + UNITS.join(', '));
    return `systemctl status ${unit} --no-pager -n 0`;
  },
  unit_journal: ({ unit, tail }) => {
    if (!UNITS.includes(unit)) throw new Error('unit must be one of: ' + UNITS.join(', '));
    return `journalctl -u ${unit} -n ${lines(tail)} --no-pager`;
  },
  failed_logins: ({ tail }) => `journalctl -u ssh -u sshd -n ${lines(tail)} --no-pager | grep -Ei 'failed|invalid' || true`,
  listening_ports: () => 'ss -tulpn',
};

export function buildCommand(action, params = {}) {
  const fn = ACTIONS[action];
  if (!fn) throw new Error('unknown action: ' + action);
  return fn(params);
}
