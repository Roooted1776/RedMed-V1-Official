#!/usr/bin/env node
/**
 * Upsert DNS-only A record mcp.redmed.live → VPS IP on the Hostinger zone.
 *
 * Nameservers are still Hostinger dns-parking, so this zone is what the
 * public resolver uses. Does not change the apex or www records.
 *
 *   HOSTINGER_API_TOKEN=… node scripts/upsert-mcp-dns-hostinger.mjs
 *   DRY_RUN=1 node scripts/upsert-mcp-dns-hostinger.mjs
 */
const TOKEN = process.env.HOSTINGER_API_TOKEN;
const DOMAIN = process.env.REDMED_DOMAIN || "redmed.live";
const NAME = process.env.MCP_DNS_NAME || "mcp";
const CONTENT = process.env.REDMED_VPS_IP || "2.25.249.204";
const DRY_RUN = process.env.DRY_RUN === "1" || process.env.DRY_RUN === "true";
const API = "https://developers.hostinger.com";

if (!TOKEN) {
  console.error("Set HOSTINGER_API_TOKEN");
  process.exit(1);
}

async function api(method, urlPath, body) {
  const res = await fetch(`${API}${urlPath}`, {
    method,
    headers: {
      Authorization: `Bearer ${TOKEN}`,
      Accept: "application/json",
      "Content-Type": "application/json",
      "User-Agent": "redmed-upsert-mcp-dns",
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const message = data?.message || res.statusText;
    throw new Error(`${method} ${urlPath} → ${res.status}: ${message}`);
  }
  return data;
}

function findA(zone, name) {
  return (Array.isArray(zone) ? zone : []).find(
    (row) => row?.type === "A" && row?.name === name
  );
}

async function main() {
  const zone = await api("GET", `/api/dns/v1/zones/${encodeURIComponent(DOMAIN)}`);
  const apex = findA(zone, "@");
  const existing = findA(zone, NAME);
  const current = existing?.records?.[0]?.content;
  if (apex?.records?.[0]?.content === CONTENT) {
    throw new Error(
      `Refusing: apex A already points at the VPS (${CONTENT}). Assist must not move onto the KVM.`
    );
  }
  if (current === CONTENT) {
    console.log(`OK  A ${NAME}.${DOMAIN} → ${CONTENT}`);
    return;
  }

  const payload = {
    overwrite: false,
    zone: [
      {
        name: NAME,
        type: "A",
        ttl: 300,
        records: [{ content: CONTENT }],
      },
    ],
  };

  await api("POST", `/api/dns/v1/zones/${encodeURIComponent(DOMAIN)}/validate`, payload);
  if (DRY_RUN) {
    console.log(
      `[dry-run] would PUT A ${NAME}.${DOMAIN} → ${CONTENT} (apex unchanged: ${apex?.records?.[0]?.content || "absent"})`
    );
    return;
  }
  await api("PUT", `/api/dns/v1/zones/${encodeURIComponent(DOMAIN)}`, payload);
  const after = await api("GET", `/api/dns/v1/zones/${encodeURIComponent(DOMAIN)}`);
  const written = findA(after, NAME)?.records?.[0]?.content;
  const apexAfter = findA(after, "@")?.records?.[0]?.content;
  if (written !== CONTENT) {
    throw new Error(`A ${NAME} is ${written || "missing"} after update`);
  }
  if (apex?.records?.[0]?.content && apexAfter !== apex.records[0].content) {
    throw new Error("Apex A changed; expected it to stay put");
  }
  console.log(`Updated A ${NAME}.${DOMAIN} → ${CONTENT} (apex still ${apexAfter})`);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
