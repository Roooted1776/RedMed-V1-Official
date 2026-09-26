/**
 * RedMed product wall: ops tooling must never carry Assist #d= payloads,
 * ICE profiles, or PHI.
 *
 * Note on the old regex: `\b(#d=...)\b` never matched a real band URL.
 * `\b` needs a word char on one side, and `#` is not a word char, so
 * `https://redmed.live/tapper/#d=eyJ...` slipped through. The fragment
 * marker is matched with no word boundary here; only the English
 * keywords use `\b`.
 */
const FRAGMENT = /#d=/i;
const KEYWORDS =
  /\b(ice[\s_-]*profile|medical[\s_-]*card|phi|health[\s_-]*record|patient[\s_-]*data)\b/i;

export const WALL_MESSAGE =
  'Blocked by RedMed product wall: do not pass Assist #d= / ICE / PHI through MCP.';

export function wallCheck(text) {
  if (!text) return null;
  const s = String(text);
  if (FRAGMENT.test(s) || KEYWORDS.test(s)) return WALL_MESSAGE;
  return null;
}

/** Redact any #d= fragment that shows up in tool output (logs, curl bodies). */
export function redactFragments(text) {
  return String(text ?? '').replace(/#d=[^\s"'<>]*/gi, '#d=[REDACTED]');
}
