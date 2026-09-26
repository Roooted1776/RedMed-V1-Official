/**
 * GitHub REST API tool for the RedMed org (Roooted1776).
 * Auth: GITHUB_TOKEN env (fine-grained PAT). Token is never logged or echoed.
 */
import { z } from 'zod';

const API = 'https://api.github.com';

export function githubTokenPresent() {
  return Boolean(process.env.GITHUB_TOKEN?.trim());
}

export async function githubRequest(method, path, body) {
  const url = path.startsWith('http') ? path : API + path;
  const token = process.env.GITHUB_TOKEN?.trim();
  const headers = {
    Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'redmed-mcp',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...(body ? { 'Content-Type': 'application/json' } : {}),
  };
  const res = await fetch(url, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let data = text;
  try {
    data = JSON.parse(text);
  } catch {
    /* keep raw text */
  }
  return {
    status: res.status,
    ok: res.ok,
    rateRemaining: res.headers.get('x-ratelimit-remaining'),
    link: res.headers.get('link'),
    data,
  };
}

export function registerGithubTools(server) {
  server.tool(
    'github_api',
    'Call the GitHub REST API as Roooted1776 (repos, issues, PRs, releases, contents, actions). path is absolute on api.github.com (e.g. /repos/Roooted1776/RedMed-V1-Official) or a full URL for pagination.',
    {
      method: z.enum(['GET', 'POST', 'PATCH', 'PUT', 'DELETE']).default('GET'),
      path: z.string().describe('API path starting with / or a full URL'),
      body: z.record(z.unknown()).optional().describe('JSON body for POST/PATCH/PUT'),
    },
    async ({ method, path, body }) => {
      if (!githubTokenPresent()) {
        return {
          content: [{ type: 'text', text: 'GITHUB_TOKEN not set in env' }],
          isError: true,
        };
      }
      try {
        const out = await githubRequest(method, path, body);
        return {
          content: [{ type: 'text', text: JSON.stringify(out, null, 2).slice(0, 100_000) }],
        };
      } catch (err) {
        return {
          content: [{ type: 'text', text: err instanceof Error ? err.message : String(err) }],
          isError: true,
        };
      }
    },
  );
}
