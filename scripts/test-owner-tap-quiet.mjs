#!/usr/bin/env node
/**
 * Owner tap stays quiet (static, no Xcode): a band tap must never arm SOS,
 * and the wearer's own band (exact or older, same name + birth date) must not
 * open the passerby card on their own phone.
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
assert('own exact band is quiet', /matchesBand\(chip\)/.test(ingress));
assert('own older band (same wearer) is quiet', /isSameWearer\(as: chip\)/.test(ingress));
assert('URL-scheme path never ingests #d=', !/scheme == "redmed"[\s\S]{0,200}ingest/.test(app));

const profile = src('ProfileData.swift');
assert('isSameWearer needs non-empty name and birth date',
  /func isSameWearer[\s\S]{0,300}!n\.isEmpty, !d\.isEmpty/.test(profile));

const armCallers = ['EmergencyView.swift', 'NFCBandManager.swift', 'NFCReader.swift', 'PasserbyHTMLCardView.swift']
  .filter((f) => /\.armSOS\(/.test(src(f)));
assert('armSOS is called only from the SOS toggle (EmergencyView)',
  armCallers.length === 1 && armCallers[0] === 'EmergencyView.swift');

if (failed) { console.error(`${failed} failed`); process.exit(1); }
console.log('all owner-tap-quiet checks passed');
