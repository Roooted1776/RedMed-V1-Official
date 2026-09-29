#!/usr/bin/env node
/**
 * Static contract for wearer account sync. Runs on Linux CI, no Xcode.
 *
 *   node scripts/test-cloud-sync.mjs
 */
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const read = (p) => readFileSync(join(ROOT, p), 'utf8');

const client = read('owner/RedMed/OwnerSupabaseClient.swift');
const sync = read('owner/RedMed/ProfileCloudSync.swift');
const account = read('owner/RedMed/OwnerAccountView.swift');
const appConfig = read('owner/RedMed/AppConfig.swift');
const plist = read('owner/RedMed/Info.plist');
const pbx = read('owner/RedMed.xcodeproj/project.pbxproj');
const baseXC = read('owner/Config/RedMed.xcconfig');
const gitignore = read('.gitignore');
const migDir = join(ROOT, 'supabase/migrations');
const migFiles = readdirSync(migDir).filter((f) => f.endsWith('.sql')).sort();
const readMig = (f) => readFileSync(join(migDir, f), 'utf8');
const sql = migFiles.map(readMig).join('\n');
// Forward migrations that bring the live schema (20260926193000) to the app contract.
const DELETE_ACCOUNT_MIG = '20260927120000_redmed_owner_delete_account.sql';
const RECONCILE_MIG = '20260927120100_redmed_owner_reconcile.sql';
// The reconcile and everything after it: the shape the database ends in.
const sqlFromReconcile = migFiles.filter((f) => f >= RECONCILE_MIG).map(readMig).join('\n');

let total = 0;
let failed = 0;
function assert(name, cond, detail) {
  total += 1;
  if (cond) console.log(`OK   ${name}`);
  else {
    failed += 1;
    console.error(`FAIL ${name}${detail ? `: ${detail}` : ''}`);
  }
}

// --- Build plumbing: key reaches Info.plist, never git ---
assert('Info.plist SUPABASE_URL from host setting', plist.includes('<string>https://$(SUPABASE_HOST)</string>'));
assert('Info.plist SUPABASE_PUBLISHABLE_KEY from build setting', plist.includes('<string>$(SUPABASE_PUBLISHABLE_KEY)</string>'));
assert('Info.plist REDMED_PROFILE_SYNC from build setting', plist.includes('<string>$(REDMED_PROFILE_SYNC)</string>'));
assert('target configs use RedMed.xcconfig', (pbx.match(/baseConfigurationReference = AAAA00000000000000000063/g) || []).length === 2);
assert('base xcconfig optional-includes Supabase.xcconfig', baseXC.includes('#include? "Supabase.xcconfig"'));
assert('base xcconfig keeps sync off and key empty', /REDMED_PROFILE_SYNC = NO/.test(baseXC) && /SUPABASE_PUBLISHABLE_KEY =\s*$/m.test(baseXC));
assert('Supabase.xcconfig is gitignored', gitignore.includes('**/Supabase.xcconfig'));
assert('no real Supabase.xcconfig committed', !existsSync(join(ROOT, 'owner/Config/Supabase.xcconfig')) || process.env.CI !== 'true');
assert('git flag stays off', appConfig.includes('static let profileSyncEnabled = false'));
assert('unexpanded $( ) treated as unset', client.includes('raw.contains("$(")'));
assert('empty host rejected', client.includes('host.contains(".")'));

// --- Secrets ---
const swiftAll = [client, sync, account, appConfig].join('\n');
assert('no service_role in app code', !/service_role/.test(swiftAll.replace(/\/\/.*$/gm, '')));
assert('no JWT literal in app', !/eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}/.test(swiftAll));
assert('no sb_secret key in app', !/sb_secret_/.test(swiftAll));

// --- Transport ---
assert('ephemeral URLSession (no disk cache of PHI)', client.includes('URLSessionConfiguration.ephemeral') && client.includes('config.urlCache = nil'));
assert('no URLSession.shared', !client.includes('URLSession.shared'));
assert('refresh is single-flight', client.includes('refreshTask') && /^actor OwnerSupabaseClient/m.test(client));
assert('only a rejected refresh token signs out (not 408/429/5xx)', client.includes('refreshRetryableStatuses: Set<Int> = [408, 429]') && client.includes('!Self.refreshRetryableStatuses.contains(response.statusCode)') && client.includes('(400...499).contains(response.statusCode)'));
assert('server owns updated_at on upsert', client.includes('row.updatedAt = nil'));

// --- Band privacy ---
assert('band write hashes URL before upload', client.includes('SHA256.hash(data: Data(url.utf8))') && client.includes('packedUrlSha256: hex'));
assert('band write re-validates URL + NTAG216 cap', client.includes('isValidWriteURL(url)') && client.includes('byteLength <= 850'));
assert('no #d= string in any request body', !/"d"\s*:|#d=\\\(/.test(client));

// --- Sync engine ---
assert('pushes are serialized', sync.includes('private actor PushQueue') && sync.includes('while let job = pending'));
assert('stamps compared as dates', sync.includes('SyncStamp.isNewer'));
assert('conflict never silently overwrites', sync.includes('profile.cloudConflict = remote'));
assert('pull waits while Edit is open', sync.includes('guard !profile.holdsEditingSession'));
assert('erase is durable + blocks pull', sync.includes('pendingEraseKey') && /if hasPendingErase \{\s*await performPendingErase\(\)\s*return/.test(sync));
assert('sign-in resets bookkeeping', /func didSignIn[\s\S]*?resetBookkeeping\(\)/.test(sync));
assert('availability needs key + opt-in', sync.includes('(AppConfig.profileSyncEnabled || SupabaseConfig.buildOptIn) && SupabaseConfig.isConfigured'));

// Linked is device-local CoreNFC verify — pull must not overwrite from the account row.
{
  const profile = read('owner/RedMed/ProfileData.swift');
  const applyFn = (/func applyCloudRecord\(_ record: OwnerProfileRecord\) \{[\s\S]*?\n    \}/.exec(profile) || [''])[0];
  assert('applyCloudRecord exists', applyFn.includes('func applyCloudRecord'));
  assert(
    'applyCloudRecord never adopts braceletLinked from the account row',
    applyFn.length > 0 && !/braceletLinked\s*=\s*record\.braceletLinked/.test(applyFn)
  );
  assert('cloudFields still reports local braceletLinked', /func cloudFields\(\)[\s\S]*?braceletLinked:\s*braceletLinked/.test(profile));
}

// --- Server schema ---
for (const t of ['profiles', 'band_writes']) {
  assert(`${t}: RLS enabled`, sql.includes(`alter table redmed_owner.${t} enable row level security`));
  assert(`${t}: RLS forced`, sql.includes(`alter table redmed_owner.${t} force row level security`));
  assert(`${t}: anon revoked`, sql.includes(`revoke all on redmed_owner.${t} from public, anon`));
}
assert('schema usage anon revoked', sql.includes('revoke all on schema redmed_owner from public, anon'));
for (const verb of ['select', 'insert', 'update', 'delete']) {
  assert(`profiles ${verb} policy own row`, new RegExp(`profiles_${verb}_own[\\s\\S]*?for ${verb} to authenticated[\\s\\S]*?id = \\(select auth\\.uid\\(\\)\\)`).test(sql));
}
assert('band_writes append-only', !/create policy band_writes_update/.test(sqlFromReconcile)
  && !/grant[^;]*\bupdate\b[^;]*on redmed_owner\.band_writes/.test(sqlFromReconcile)
  && sql.includes('grant select, insert, delete on redmed_owner.band_writes to authenticated'));

// --- Reconcile: 20260926193000 (live) granted band_writes UPDATE + anon schema USAGE ---
assert('reconcile migration present', migFiles.includes(RECONCILE_MIG));
const reconcile = migFiles.includes(RECONCILE_MIG) ? readMig(RECONCILE_MIG) : '';
assert('reconcile drops the live update policy', reconcile.includes('drop policy if exists band_writes_update on redmed_owner.band_writes'));
assert('reconcile revokes UPDATE on band_writes', reconcile.includes('revoke all on redmed_owner.band_writes from public, anon, authenticated;')
  && reconcile.includes('grant select, insert, delete on redmed_owner.band_writes to authenticated;'));
assert('reconcile revokes anon schema usage', reconcile.includes('revoke all on schema redmed_owner from public, anon;'));
assert('reconcile stamps updated_at on insert too', reconcile.includes('before insert or update on redmed_owner.profiles')
  && reconcile.includes("set search_path = ''"));
for (const live of ['profiles_select', 'profiles_insert', 'profiles_update', 'profiles_delete', 'band_writes_select', 'band_writes_insert', 'band_writes_delete']) {
  assert(`reconcile drops live policy ${live}`, reconcile.includes(`drop policy if exists ${live} on redmed_owner.`));
}
assert('reconcile runs after the live schema and delete_my_account',
  migFiles.includes(DELETE_ACCOUNT_MIG)
  && migFiles.indexOf(RECONCILE_MIG) > migFiles.indexOf(DELETE_ACCOUNT_MIG)
  && migFiles.indexOf(RECONCILE_MIG) > migFiles.indexOf('20260926194500_owner_touch_search_path.sql'));
{
  const runner = read('scripts/test-supabase-rls.sh');
  assert('RLS runner applies live base once, owner migrations twice',
    runner.includes('20260926193000_redmed_owner_profiles.sql') && /\*owner\*\.sql/.test(runner)
    && /run "\$db" "\$f"; run "\$db" "\$f"/.test(runner) && /^scenario live$/m.test(runner));
}
assert('band_writes sha256 shape', sql.includes("packed_url_sha256 ~ '^[0-9a-f]{64}$'"));
assert('band_writes NTAG216 cap', sql.includes('byte_length between 1 and 850'));
assert('updated_at trigger', sql.includes('new.updated_at := now()') && sql.includes('before insert or update on redmed_owner.profiles'));
assert('trigger fn pins search_path', sql.includes("set search_path = ''"));
{
  const code = sql.replace(/--.*$/gm, ''); // comments may say "fragment"; columns may not
  assert('no raw band URL column', !/packed_url\s+text(?!_)/.test(code) && !/\bfragment\b/.test(code));
}

// --- Account management ---
assert('delete_my_account is security definer with pinned search_path',
  /function redmed_owner\.delete_my_account\(\)[\s\S]*?security definer[\s\S]*?set search_path = ''/.test(sql));
assert('delete_my_account deletes only auth.uid()',
  /caller uuid := auth\.uid\(\)/.test(sql) && sql.includes('delete from auth.users where id = caller'));
assert('delete_my_account refuses a null caller', /if caller is null then\s*raise exception/.test(sql));
assert('delete_my_account execute revoked from public, anon',
  sql.includes('revoke all on function redmed_owner.delete_my_account() from public, anon'));
assert('delete_my_account execute granted to authenticated only',
  sql.includes('grant execute on function redmed_owner.delete_my_account() to authenticated'));
assert('profiles + band_writes cascade from auth.users',
  (sql.match(/references auth\.users \(id\) on delete cascade/g) || []).length >= 2);
assert('client calls the RPC in the redmed_owner schema',
  /rpc\/delete_my_account[\s\S]*?profile: "redmed_owner"/.test(client));
assert('client drops session only after server confirms delete',
  /func deleteAccount\(\)[\s\S]*?requireOK\(response\)\s*dropSession\(\)/.test(client));
assert('global sign-out throws unless confirmed',
  /func signOutAllDevices\(\) async throws[\s\S]*?scope=global[\s\S]*?requireOK\(response\)\s*dropSession\(\)/.test(client));
assert('delete account resets sync bookkeeping', /func deleteAccount\(\)[\s\S]*?resetBookkeeping\(\)/.test(sync));
assert('account screen confirms before delete', account.includes('confirmDelete = true') && account.includes('"Delete this account?"'));
assert('account screen confirms before global sign-out', account.includes('confirmSignOutAll = true'));

// Column names the Swift CodingKeys expect.
for (const col of ['birth_date', 'blood_type', 'bracelet_linked', 'is_organ_donor', 'is_pregnant', 'is_deaf_or_vision_impaired', 'last_updated', 'updated_at']) {
  assert(`column ${col} in SQL + Swift`, sql.includes(`  ${col} `) && client.includes(`"${col}"`));
}

const finishMigName = '20260929120000_portal_admin_finish_auth.sql';
assert('portal_admin_finish auth migration present', migFiles.includes(finishMigName));
const finishMig = migFiles.includes(finishMigName) ? readMig(finishMigName) : '';
assert('portal_admin_finish requires the event actor to be an admin',
  /function redmed_private\.portal_admin_finish[\s\S]*admin_members[\s\S]*update redmed_private\.admin_events/.test(finishMig));
assert('portal_admin_finish stays service_role only',
  finishMig.includes('revoke all on function public.portal_admin_finish(uuid, text, uuid) from public, anon, authenticated')
  && finishMig.includes('grant execute on function redmed_private.portal_admin_finish(uuid, text, uuid) to service_role'));
const portalHtml = read('portal/index.html');
const portalJs = read('portal/app.js');
assert('account portal CSP allows only this Supabase project',
  portalHtml.includes('Content-Security-Policy')
  && portalHtml.includes("script-src 'self'")
  && portalHtml.includes('https://mohxobgyjkcmkqxijgeg.supabase.co')
  && portalHtml.includes('wss://mohxobgyjkcmkqxijgeg.supabase.co'));
assert('account contacts are built without innerHTML', !portalJs.includes('innerHTML'));

console.log(`\n${total} check(s), ${failed} failed.`);
if (failed) {
  console.error(`test-cloud-sync failed: ${failed} check(s)`);
  process.exit(1);
}
console.log('test-cloud-sync OK');
