#!/usr/bin/env node
/**
 * Static contract for the 911 tab location features. Runs on Linux CI, no Xcode.
 *
 *   node scripts/test-emergency-location.mjs
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const read = (p) => readFileSync(join(ROOT, p), 'utf8');

const share = read('owner/RedMed/EmergencyLocationShare.swift');
const view = read('owner/RedMed/EmergencyView.swift');
const hospitals = read('owner/RedMed/NearbyHospitals.swift');
const pbx = read('owner/RedMed.xcodeproj/project.pbxproj');
const doc = read('owner/RedMed/Document/Document.html');

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

const code = share.replace(/^\s*\/\/.*$/gm, '');
const bodyFn = code.slice(code.indexOf('static func body('), code.indexOf('static func mapsURL('));

// --- Build plumbing ---
assert('EmergencyLocationShare.swift in Sources', /AABB[0-9A-F]+ \/\* EmergencyLocationShare\.swift in Sources \*\//.test(pbx));

// --- No RedMed server, no background send ---
assert('no URLSession in location share', !/URLSession/.test(code));
assert('no Supabase in location share', !/Supabase|OwnerSupabaseClient|ProfileCloudSync/.test(code));
assert('texts go through the Messages composer', code.includes('MFMessageComposeViewController()'));
assert('no sms: URL auto-open', !/URL\(string:\s*"sms:/.test(code));
assert('no system share sheet for location text', !code.includes('UIActivityViewController'));
assert('phones that cannot text do not share the body', code.includes("This phone can't open Messages"));

// --- SMS body carries name + where only ---
assert('body takes name, location, address only', /static func body\(\s*name: String,\s*location: CLLocation\?,\s*address: String\?,/.test(code));
for (const field of ['bloodType', 'allergies', 'medications', 'conditions', 'notes', 'birthDate', 'isPregnant', 'isOrganDonor']) {
  assert(`SMS body has no ${field}`, !bodyFn.includes(field));
}
assert('body names the regional emergency number', bodyFn.includes('EmergencyNumber.current'));
assert('map link is Apple Maps https', share.includes('"https://maps.apple.com/?ll=\\(ll)&q=SOS"'));
assert('recipients de-duplicated', code.includes('seen.insert(digits).inserted'));

// --- Owner only ---
assert('share + contacts cards are owner-only', /if !isScannerSession \{\s*ShareLocationCard\(/.test(view) && view.includes('EmergencyContactsCallCard()'));

// --- Address lookup is throttled and stops off-screen ---
assert('geocoder throttled by distance', share.includes('minMoveMeters: CLLocationDistance = 25'));
assert('geocoder throttled by time', share.includes('minInterval: TimeInterval = 15'));
assert('geocoder cancelled when 911 hides', /if !visible \{ addressResolver\.stop\(\) \}/.test(view));
assert('stale address never shown or texted (100 m drift guard)',
  share.includes('maxDriftMeters: CLLocationDistance = 100') &&
  /lastResolved\.distance\(from: fix\) <= Self\.maxDriftMeters/.test(share) &&
  /address: currentAddress\s*\)/.test(view) && !/addressResolver\.address\b(?!\()/.test(view));
assert('one GPS owner on the 911 page', (view.match(/@StateObject private var locationManager = LocationManager\(\)/g) || []).length === 1);

// --- Calls open the Phone app only ---
assert('tel: open only', /URL\(string: "tel:\\\(digits\)"\)/.test(code) && !/CXCallController|CXStartCallAction/.test(code));
assert('ER directions open Apple Maps', code.includes('MKLaunchOptionsDirectionsModeDriving'));
assert('hospital distance is locale-aware', hospitals.includes('usage: .road'));

// --- Disclosure ---
assert('Privacy discloses Text My Location', doc.includes('Text My Location'));
assert('Privacy discloses street address lookup', /street address/i.test(doc));
assert('Privacy discloses Delete Account', doc.includes('Delete Account'));

console.log(`\n${total} check(s), ${failed} failed.`);
if (failed) {
  console.error(`test-emergency-location failed: ${failed} check(s)`);
  process.exit(1);
}
console.log('test-emergency-location OK');
