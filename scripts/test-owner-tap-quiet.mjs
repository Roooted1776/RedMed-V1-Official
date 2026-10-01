#!/usr/bin/env node
/**
 * Owner tap (static, no Xcode): a band tap must never arm SOS.
 * A decodable `#d=` opens bundled tapper.html, including the wearer's own band.
 * The VPS write URL and the owner database are not touched by this ingress.
 *
 *   node scripts/test-owner-tap-quiet.mjs
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const src = (f) => readFileSync(join(ROOT, 'owner/RedMed', f), 'utf8');
let failed = 0;
function assert(name, cond) {
  if (cond) console.log(`OK   ${name}`);
  else { failed += 1; console.error(`FAIL ${name}`); }
}

const app = src('RedMedApp.swift');
const ingress = app.slice(app.indexOf('final class BandTapIngress'));
assert('band tap ingress never calls armSOS', !/armSOS|CrashMotionGuard|survival/i.test(ingress));
assert('band tap ingress never dials', !/PublicEmergencyAid|tel:/i.test(ingress));
assert('decoded band opens tapper.html',
  /decodeProfile\(fromURLString: urlString\)[\s\S]{0,500}open\(urlString\)/.test(ingress));
assert('own band is not returned before the card opens',
  !/matchesBand\(chip\)[\s\S]{0,120}return/.test(ingress));
assert('URL-scheme path never ingests #d=',
  /if scheme == "redmed", host == "nfc" \{[\s\S]{0,180}return\s*\}/.test(app)
  && !/if scheme == "redmed"[\s\S]{0,180}ingest\(/.test(app));

const profile = src('ProfileData.swift');
assert('isSameWearer needs non-empty name and birth date',
  /func isSameWearer[\s\S]{0,300}!n\.isEmpty, !d\.isEmpty/.test(profile));

const armCallers = ['EmergencyView.swift', 'NFCBandManager.swift', 'NFCReader.swift', 'PasserbyHTMLCardView.swift']
  .filter((f) => /\.armSOS\(/.test(src(f)));
assert('armSOS is called only from the SOS toggle (EmergencyView)',
  armCallers.length === 1 && armCallers[0] === 'EmergencyView.swift');

if (failed) { console.error(`${failed} failed`); process.exit(1); }
console.log('all owner-tap-quiet checks passed');
