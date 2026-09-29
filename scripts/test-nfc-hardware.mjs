#!/usr/bin/env node
/**
 * NFC hardware contract (static, no Xcode): chip model, RF constants, tap
 * geometry, write gate, NDEF contract, read-back verify, no permanent lock
 * bytes, CoreNFC session type, simulator guard. Reads the Swift/plist source
 * as text (same approach as test-d-codec.mjs) so it runs on Linux CI.
 *
 *   node scripts/test-nfc-hardware.mjs
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

let failed = 0;
let total = 0;
function assert(name, cond, detail) {
  total += 1;
  if (cond) {
    console.log(`OK   ${name}`);
  } else {
    failed += 1;
    console.error(`FAIL ${name}${detail ? `: ${detail}` : ''}`);
  }
}

const appConfig = readFileSync(join(ROOT, 'owner/RedMed/AppConfig.swift'), 'utf8');
const redMedApp = readFileSync(join(ROOT, 'owner/RedMed/RedMedApp.swift'), 'utf8');
const writer = readFileSync(join(ROOT, 'owner/RedMed/NFCWriter.swift'), 'utf8');
const reader = readFileSync(join(ROOT, 'owner/RedMed/NFCReader.swift'), 'utf8');
const manager = readFileSync(join(ROOT, 'owner/RedMed/NFCBandManager.swift'), 'utf8');
const codec = readFileSync(join(ROOT, 'owner/RedMed/ProfileNFCCodec.swift'), 'utf8');
const contentView = readFileSync(join(ROOT, 'owner/RedMed/ContentView.swift'), 'utf8');
const entitlements = readFileSync(join(ROOT, 'owner/RedMed/RedMed.entitlements'), 'utf8');
const infoPlist = readFileSync(join(ROOT, 'owner/RedMed/Info.plist'), 'utf8');
const doc = readFileSync(join(ROOT, 'owner/RedMed/Document/Document.html'), 'utf8');

// --- Chip model (NTAG216-only) ---
assert('chip part is NXP NTAG216', appConfig.includes('static let chipPart = "NXP NTAG216"'));
assert('chip family ISO 14443A Type 2 (NXP NTAG216)', appConfig.includes('static let family = "ISO 14443A Type 2 (NXP NTAG216)"'));
assert('writer rejects non-NTAG216 families by name', writer.includes('Not NTAG213/215, MIFARE, LF, or UHF'));
assert('writer capacity error names NXP NTAG216', writer.includes('Product band is NXP NTAG216'));
assert('codec capacity note names NXP NTAG216', codec.includes('too large for NXP NTAG216') && codec.includes('bytes on tag — NXP NTAG216'));
assert('AppConfig chip-sourcing comment names NTAG215 alongside NTAG213', appConfig.includes('Do not source NTAG213, NTAG215, MIFARE, LF (~125 kHz), or UHF (~860–960 MHz).'));
assert('Document.html names passive NXP NTAG216 chip', doc.includes('<strong>passive NXP NTAG216</strong> at 13.56 MHz (ISO 14443A Type 2, NDEF blank unlocked)'));

// --- RF constants ---
assert('carrier is 13.56 MHz', /static let carrierMHz: Double = 13\.56/.test(appConfig));
assert('walk-by standoff min 6"', /static let walkByStandoffInchesMin = 6/.test(appConfig));
assert('walk-by standoff max 8"', /static let walkByStandoffInchesMax = 8/.test(appConfig));
assert('intentional tap min 1"', /static let intentionalTapInchesMin = 1/.test(appConfig));
assert('intentional tap max 2"', /static let intentionalTapInchesMax = 2/.test(appConfig));
assert('reliable coupling max 4"', /static let reliableCouplingInchesMax = 4/.test(appConfig));

// --- Tap geometry ---
assert('face art logo lockstep (30x9mm)', appConfig.includes('(30×9 mm) on black'));
assert('Document.html face art lockstep', doc.includes('on black silicone (<code>#232425</code>) at 30×9 mm'));
assert('RedMed never starts NFC on mere proximity', /static let requiresExplicitUserSession = true/.test(appConfig));
assert('tap distance summary: walk-by does not fire, deliberate tap does', appConfig.includes("Walk-by won't fire (\\(walkByRangeLabel)). Only a deliberate \\(intentionalTapRangeLabel) antenna tap opens the card."));
assert('ContentView hold-to-write geometry comment', contentView.includes('Hold the band ~1–2″ finishes the program — iOS has no silent write.'));

// --- Write gate ---
assert('writeBand refuses scanner sessions', manager.includes('guard !isScannerSession else { return }'));
assert('writeBand refuses while busy', manager.includes('guard !isBusy else { return }'));
assert('writeBand requires sensitive profile data', manager.includes('guard profile.hasSensitiveProfileData else { return }'));
assert('writeBand enforces NTAG216 850-byte cap', manager.includes('guard urlString.utf8.count <= 850 else {'));
assert('NFCWriter refuses non #d= write URLs', writer.includes('guard AppConfig.OwnerBandURI.isValidWriteURL(urlString) else {'));
assert('NFCWriter gated on nfcHardwareEnabled', writer.includes('guard AppConfig.nfcHardwareEnabled else {'));
assert('NFCWriter requires NFC hardware available', writer.includes('guard NFCNDEFReaderSession.readingAvailable else {'));
assert('parked builds only pack — never open a CoreNFC write session', manager.includes('// Parked: pack only — never a Write, never Linked.'));

// --- Parked outside-writer copy (NFC Tools) ---
{
  const nfcView = readFileSync(join(ROOT, 'owner/RedMed/NFCView.swift'), 'utf8');
  const copyFn = (/func copyBandLinkForExternalWriter[\s\S]*?\n    }\n/.exec(manager) || [''])[0];
  assert('band-link copy exists only while parked', copyFn.includes('guard !AppConfig.nfcHardwareEnabled else { return }'));
  assert('band-link copy refuses scanner sessions', copyFn.includes('guard !isScannerSession else { return }'));
  const packFn = (/func packAndValidate[\s\S]*?\n    }\n/.exec(manager) || [''])[0];
  assert('band-link copy requires a valid #d= write URL', copyFn.includes('packAndValidate(profile: profile)') && packFn.includes('AppConfig.OwnerBandURI.isValidWriteURL(urlString)'));
  assert('band-link copy enforces NTAG216 850-byte cap', copyFn.includes('packAndValidate(profile: profile)') && packFn.includes('guard urlString.utf8.count <= 850 else {'));
  assert('band-link copy uses local-only expiring pasteboard', copyFn.includes('SecurePasteboard.copyEphemeral(') && !copyFn.includes('UIPasteboard'));
  assert('band-link copy never marks Linked', !copyFn.includes('writeVerified = true') && !copyFn.includes('setBraceletPaired') && !copyFn.includes('BandFreshness'));
  const life = Number((/externalCopyLifetimeSeconds: TimeInterval = (\d+)/.exec(appConfig) || [])[1]);
  assert('band-link copy expires within 5 minutes', life > 0 && life <= 300, `lifetime=${life}`);
  const expiryFn = (/func scheduleCopiedLinkExpiry[\s\S]*?\n    }\n/.exec(manager) || [''])[0];
  assert('copied-link message is swapped when the pasteboard expires', copyFn.includes('scheduleCopiedLinkExpiry()')
    && expiryFn.includes('externalCopyLifetimeSeconds') && expiryFn.includes('clock: .continuous')
    && expiryFn.includes('statusMessage == AppConfig.NFCWriteCopy.externalCopiedDetail')
    && expiryFn.includes('statusMessage = AppConfig.NFCWriteCopy.externalCopyExpiredDetail'));
  assert('copied-link expired line is not styled as an error', /externalCopyExpiredDetail \{ return false \}/.test(nfcView));
  assert('Copy Band Link button sits in the parked branch only', /if AppConfig\.nfcHardwareEnabled \{\s*writeBandButton\s*tipRow\(AppConfig\.NFCWriteCopy\.holdTopTip\)\s*\} else \{[\s\S]*?copyBandLinkForExternalWriter/.test(nfcView));
  assert('parked Do This Now puts Copy Band Link before Write The Band', /copyBandLinkForExternalWriter[\s\S]*?externalCopyPrivacyTip\)\s*writeBandButton\s*\}/.test(nfcView));
  assert('copied-link line sits directly under Copy Band Link, above the privacy tip', /copyBandLinkForExternalWriter\(from: profile, isScannerSession: isScannerSession\)\s*\}\s*copiedLinkStatus\s*tipRow\(AppConfig\.NFCWriteCopy\.externalCopyPrivacyTip\)/.test(nfcView)
    && /private var hidesWriteStatus[\s\S]*?isCopiedLinkStatus/.test(nfcView));
  const parkedSteps = (/static var tutorialSteps[\s\S]*?\n            return \[([\s\S]*?)\n            \]/.exec(appConfig) || [])[1] || '';
  const order = ['Fill your card', 'Copy Band Link', 'Write with NFC Tools', 'Helpers tap to open'].map((t) => parkedSteps.indexOf(t));
  assert('parked How It Works follows fill → copy → NFC Tools → helpers tap', order.every((i, n) => i >= 0 && (n === 0 || i > order[n - 1])), `order=${order}`);

  // Empty card: one live Fill Medical ID, checked before Copy / Write branches.
  const actions = (/private var actionsCard[\s\S]*?\n    }\n/.exec(nfcView) || [''])[0];
  const emptyIdx = actions.indexOf('if !profile.hasSensitiveProfileData {');
  assert('empty card shows Fill Medical ID before any Copy / Write button', emptyIdx >= 0 && actions.indexOf('fillCardTitle') > emptyIdx && actions.indexOf('fillCardTitle') < actions.indexOf('copyBandLinkForExternalWriter'));
  assert('Fill Medical ID hands off via onFillCard (Face ID-gated Edit on RedMed)', actions.includes('action: onFillCard') && /\.onChange\(of: fillCardRequest\) \{ _, _ in requestEdit\(\) \}/.test(readFileSync(join(ROOT, 'owner/RedMed/RedMedView.swift'), 'utf8')));
  const writeBtn = (/private var writeBandButton[\s\S]*?\n    }\n/.exec(nfcView) || [''])[0];
  assert('parked Write The Band is a non-writing row, never a PrimaryButton', /if AppConfig\.nfcHardwareEnabled \{[\s\S]*?band\.writeBand\([\s\S]*?\} else \{\s*parkedWriteRow\s*\}/.test(writeBtn));
  const redmedView = readFileSync(join(ROOT, 'owner/RedMed/RedMedView.swift'), 'utf8');
  assert('parked unlinked status reads Band Not Checked, hardware keeps Not Linked', /static var unlinkedTitle: String \{\s*AppConfig\.nfcHardwareEnabled \? "Not Linked" : "Band Not Checked"\s*\}/.test(appConfig));
  assert('RedMed header and NFC chip share unlinkedTitle (no hardcoded Not Linked)', redmedView.includes('linked ? "Linked Bracelet" : AppConfig.NFCWriteCopy.unlinkedTitle') && nfcView.includes('return (AppConfig.NFCWriteCopy.unlinkedTitle,') && !/"Not Linked"/.test(redmedView + nfcView));
  assert('parked RedMed header status is grey, not red', /static var unlinkedIsAlert: Bool \{ AppConfig\.nfcHardwareEnabled \}/.test(appConfig) && /linked \|\| AppConfig\.NFCWriteCopy\.unlinkedIsAlert \? \.redmedAccent : \.redmedMuted/.test(redmedView) && redmedView.includes('.foregroundColor(statusColor)'));
  assert('copied-link detail and Help answer name the same parked status', appConfig.includes('so it shows Band Not Checked.') && /Why does RedMed say \\\(NFCWriteCopy\.unlinkedTitle\)\?/.test(appConfig));

  // Help: band row + Common Questions copy come from AppConfig (no drift from the NFC tab).
  const helpView = readFileSync(join(ROOT, 'owner/RedMed/HelpMenuView.swift'), 'utf8');
  assert('Help band row title comes from AppConfig.NFCWriteCopy.helpBandRowTitle', helpView.includes('AppConfig.NFCWriteCopy.helpBandRowTitle') && !helpView.includes('"Set Up Your Band"'));
  const helpQs = (/enum HelpQuestions[\s\S]*?\n    }\n/.exec(appConfig) || [''])[0];
  assert('Help Common Questions reuse band fact lines', ['BraceletRF.passerbyTapSummary', 'BraceletRF.tapDistanceSummary', 'OwnerBandURI.storesIndependenceSummary'].every((k) => helpQs.includes(k)) && helpView.includes('AppConfig.HelpQuestions.all'));

  // Main tabs open at their top: every tab page scrolls through TabScrollView.
  const contentView = readFileSync(join(ROOT, 'owner/RedMed/ContentView.swift'), 'utf8');
  const tabPages = ['RedMedView', 'EmergencyView', 'AidView', 'NFCView'].map((n) => [n, readFileSync(join(ROOT, `owner/RedMed/${n}.swift`), 'utf8')]);
  assert('every main tab page scrolls with TabScrollView (no plain vertical ScrollView)', tabPages.every(([, src]) => src.includes('TabScrollView {') && !/\bScrollView \{/.test(src.replace(/TabScrollView \{/g, ''))), tabPages.filter(([, src]) => /\bScrollView \{/.test(src.replace(/TabScrollView \{/g, ''))).map(([n]) => n).join(','));
  assert('leaving a tab resets it; re-tap scrolls up', /\.onChange\(of: tab\) \{ oldTab, newTab in[\s\S]*?scrollRequests\[visibleTab\(oldTab\)[^\]]*\]\.bump\(animated: false\)/.test(contentView) && /onReselect: \{ current in\s*scrollRequests\[current[^\]]*\]\.bump\(animated: true\)/.test(contentView) && contentView.includes('.environment(\\.tabScrollRequest, scrollRequests[tab]') && /if tab == next \{\s*onReselect\?\(next\)/.test(contentView));
  assert('backgrounding resets every mounted tab to its top (owner and scanner)', /\.onChange\(of: scenePhase\) \{ _, phase in\s*(\/\/[^\n]*\s*)*if phase == \.background \{\s*for mounted in mountedTabs \{\s*scrollRequests\[mounted[^\]]*\]\.bump\(animated: false\)/.test(contentView));
  assert('parked owner copy has no "Tag Reading" jargon', !/Tag Reading/.test(appConfig.slice(appConfig.indexOf('enum NFCWriteCopy'), appConfig.indexOf('enum QuietPrayer'))));
}

// --- NDEF contract ---
assert('NDEF record is Well Known Type "U"', writer.includes('type: Data("U".utf8)'));
assert('URI identifier 0x04 maps to https://', writer.includes('(0x04, "https://")'));
assert('write message is a single-record NFCNDEFMessage', writer.includes('let message = NFCNDEFMessage(records: [payload])'));
assert('write checks message length against tag capacity', writer.includes('if capacity > 0, message.length > capacity {'));
assert('queryNDEFStatus handles notSupported/readOnly/readWrite/@unknown', writer.includes('case .notSupported:') && writer.includes('case .readOnly:') && writer.includes('case .readWrite:') && writer.includes('@unknown default:'));
assert('NFCReader decodes only via NFCURICodec.string(from:)', reader.includes('NFCURICodec.string(from: payload)'));
assert('decodeProfile requires a #d= fragment', codec.includes('urlString.range(of: "#d=") != nil'));

// --- Read-back verify ---
assert('write is followed by a readNDEF read-back', writer.includes('tag.writeNDEF(message) { error in') && writer.includes('tag.readNDEF { readMessage, readError in'));
assert('read-back is compared against the written URL via NFCURICodec.match', writer.includes('let ok = written.map { NFCURICodec.match($0, urlString) } ?? false'));
assert('linkBracelet requires a verified read-back before pairing', manager.includes('guard AppConfig.nfcHardwareEnabled, writeVerified else { return }'));

// --- No permanent lock bytes ---
assert('factory does not pre-lock the tag', /static let factoryLock = false/.test(appConfig));
assert('band stays rewritable (not permanently locked)', /static let isRewritable = true/.test(appConfig));
assert('factory does not pre-encode NDEF', /static let factoryPreEncode = false/.test(appConfig));
assert('locked/read-only tags are refused, never force-written', writer.includes('This tag is locked/read-only. RedMed needs NDEF blank unlocked — no factory lock.'));
assert('no lock-byte / permalock API is ever invoked', !writer.includes('writeLock') && !reader.includes('writeLock') && !manager.includes('writeLock'));

// --- CoreNFC session type ---
assert('NFCWriter opens an NDEF (not raw tag) session', writer.includes('NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)'));
assert('NFCReader opens an NDEF (not raw tag) session', reader.includes('NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)'));
assert('neither session uses raw NFCTagReaderSession (lock-byte capable)', !writer.includes('NFCTagReaderSession') && !reader.includes('NFCTagReaderSession'));
assert('both delegates conform to NFCNDEFReaderSessionDelegate', writer.includes('extension NFCWriter: NFCNDEFReaderSessionDelegate') && reader.includes('extension NFCReader: NFCNDEFReaderSessionDelegate'));

// --- Simulator guard ---
assert('NFCWriter has no Simulator fake-success path', writer.includes('No Simulator fake-success path — failures stay failures.'));
assert('NFCReader has no Simulator fake-success path', reader.includes('No Simulator fake-success path — failures stay failures.'));
assert('NFCReader also requires hardware NFC availability', reader.includes('guard NFCNDEFReaderSession.readingAvailable else {'));
{
  const hardwareEnabled = /static let nfcHardwareEnabled = true/.test(appConfig);
  const entitled = entitlements.includes('com.apple.developer.nfc.readersession') && infoPlist.includes('NFCReaderUsageDescription');
  assert(
    'NFC entitlement + usage description stay in lockstep with nfcHardwareEnabled',
    hardwareEnabled === entitled,
    `nfcHardwareEnabled=${hardwareEnabled} entitled=${entitled}`,
  );
  // Written bands need Universal Links to reach the owner's app: the tapper
  // has no redmed:// fallback. Never ship chip writes without applinks.
  const udlEnabled = /static let associatedDomainsEnabled = true/.test(appConfig);
  // Must cover the host bands are written with, not just any applinks: entry.
  const baseHost = (/static var medicalCardBaseURL[\s\S]*?return "https:\/\/([^/"]+)\//.exec(appConfig) || [])[1] || '';
  assert('medicalCardBaseURL host parsed for applinks check', /^[a-z0-9.-]+\.[a-z]{2,}$/i.test(baseHost), `host=${baseHost}`);
  const udlEntitled = entitlements.includes('com.apple.developer.associated-domains') && !!baseHost && entitlements.includes(`applinks:${baseHost}`);
  assert(
    'nfcHardwareEnabled requires Associated Domains enabled + applinks:<write-base host>',
    !hardwareEnabled || (udlEnabled && udlEntitled),
    `nfcHardwareEnabled=${hardwareEnabled} associatedDomainsEnabled=${udlEnabled} applinks=${udlEntitled}`,
  );
}

assert('https tapper URLs ingest from onOpenURL', redMedApp.includes('TapperWebLink.isCardURL(url)') && redMedApp.includes('bandTap.ingest(url.absoluteString, profile: profile)'));
assert('UL prefers a candidate that still decodes #d=', redMedApp.includes('ProfileNFCCodec.decodeProfile(fromURLString: candidate)'));
assert('custom scheme is not a band ingest path', !redMedApp.includes('redmed://band') && redMedApp.includes('redmed:// is never ingested'));

console.log(`\n${total} check(s), ${failed} failed.`);
if (failed) {
  console.error(`test-nfc-hardware failed: ${failed} check(s)`);
  process.exit(1);
}
console.log('test-nfc-hardware OK');
