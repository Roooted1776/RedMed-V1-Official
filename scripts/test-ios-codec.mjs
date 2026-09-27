#!/usr/bin/env node
/**
 * iOS side of the #d= lockstep. The web repo checks tapper/index.html
 * against the same contracts/d-codec-fixtures.json.
 *
 *   node scripts/test-ios-codec.mjs
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const fixtures = JSON.parse(readFileSync(join(ROOT, 'contracts/d-codec-fixtures.json'), 'utf8'));
const swift = readFileSync(join(ROOT, 'owner/RedMed/ProfileNFCCodec.swift'), 'utf8');
const appConfig = readFileSync(join(ROOT, 'owner/RedMed/AppConfig.swift'), 'utf8');
const profileData = readFileSync(join(ROOT, 'owner/RedMed/ProfileData.swift'), 'utf8');
const consent = readFileSync(join(ROOT, 'owner/RedMed/ConsentGateView.swift'), 'utf8');
const doc = readFileSync(join(ROOT, 'owner/RedMed/Document/Document.html'), 'utf8');

let failed = 0;
function assert(name, cond, detail) {
  if (cond) console.log(`OK   ${name}`);
  else {
    failed += 1;
    console.error(`FAIL ${name}${detail ? `: ${detail}` : ''}`);
  }
}

assert('KEY_LABEL in Swift', swift.includes(`keyLabel = "${fixtures.keyLabel}"`));
assert('AES version Swift', swift.includes(`aesVersion: UInt8 = 0x0${fixtures.aesVersion}`));
assert('zlib version Swift', swift.includes(`zlibVersion: UInt8 = 0x0${fixtures.zlibVersion}`));
assert('MAX_PAYLOAD Swift', swift.includes(`maxEncodedLength = ${fixtures.maxPayload}`));
assert('MAX_STR Swift', new RegExp(`maxStr = ${fixtures.maxStr}`).test(swift));
assert('MAX_LIST Swift', new RegExp(`maxList = ${fixtures.maxList}`).test(swift));
assert('current idx name=4 Swift', /static let name = 4/.test(swift));
assert('current idx blood=0 Swift', /static let blood = 0/.test(swift));
assert('current idx notes=12 Swift', /static let notes = 12/.test(swift));
assert('legacy idx name=0 Swift', /static let name = 0/.test(swift));
assert('write base AppConfig', appConfig.includes(`"${fixtures.writeBase}"`));
assert('empty persist guard', profileData.includes('guard hasSensitiveProfileData else { return false }') || (profileData.includes('hasSensitiveProfileData') && profileData.includes('return false')));
assert('embed escapes lt', swift.includes('u003c'));
assert('Swift strips amp in extract', /firstIndex\(of: "&"\)/.test(swift));
assert('Swift decode charset gate', swift.includes('isBase64urlCharset'));
assert('tapper note in AppConfig', appConfig.includes(fixtures.tapperNote));
assert('findHelp note in AppConfig', appConfig.includes(fixtures.findHelpNote));
assert('localOnlyLine in AppConfig', appConfig.includes(fixtures.localOnlyLine));
assert('profile sync default off', appConfig.includes('static let profileSyncEnabled = false'));
assert('consent version', consent.includes(`currentVersion = "${fixtures.consentVersion}"`));
assert('policy discloses wearer copy', doc.includes('signed-in wearer copy') && doc.includes('Supabase') && doc.includes('tap page does not look the profile up') && doc.includes('public fragment'));

if (failed) {
  console.error(`test-ios-codec FAILED ${failed}`);
  process.exit(1);
}
console.log('test-ios-codec OK');
