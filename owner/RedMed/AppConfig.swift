import Foundation

enum AppConfig {
    /// Passerby / rescuer shell written to passive NFC bands. Any phone that taps
    /// the bracelet opens this page in a browser — read-only medical card + 911 + Aid.
    /// No NFC / Edit on the tap card (those are owner-app only). No Face ID /
    /// biometrics / login / passcode to view — tap-to-view is ungated on every
    /// phone. Nothing covers or blocks the tap card. Medical data is only in the
    /// `#d=` fragment (flat array → AES-GCM → base64url; no server storage).
    /// `sw.js` cache-first stores the static layout for instant offline / EMT taps
    /// (activate clears prior CACHE buckets). Owner edit / treatments live in
    /// `Main.swift`, not here.
    /// Source page: `tapper/index.html` (the only shell). Xcode copies it into
    /// the app bundle as `tapper.html` at build. Repo-root `tapper.html` is a
    /// `#d=`-preserving redirect to `/tapper/`. Legacy `card/` / `get/` URLs
    /// redirect to `/tapper/` (preserve `#d=`). NFC Preview / Scan always use
    /// the **bundled** tapper.html (local-only). Hosted Pages must serve the
    /// tapper shell (RedMed · 911 · Aid).
    /// Local: `./scripts/deploy-pages.sh`. Live Hostinger: stage +
    /// `node scripts/deploy-hostinger-static.mjs redmed.live` (`docs/domain.md`),
    /// or the `Pages tapper deploy` GitHub Action on `main`.
    ///
    /// Product HTML app URL — Hostinger static only. No RedMed server, no DB,
    /// no HIPAA backend. Profile stays in `#d=` on the band. github.io remains
    /// a backup host for already-written bands — do not delete it.
    static let medicalCardCustomDomainTBD: String? = "https://redmed.live/tapper/"

    /// NFC write + passerby open URL. Hostinger `redmed.live` static shell.
    /// github.io remains a backup host for already-written bands — do not delete it.
    static var medicalCardBaseURL: String {
        if let custom = medicalCardCustomDomainTBD?.trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            return custom.hasSuffix("/") ? custom : custom + "/"
        }
        return "https://redmed.live/tapper/"
    }

    /// Deep link target for policy / card HTML “open owner app” redirects.
    static let mainAppURL = "redmed://main"

    /// Owner RedMed embed status line → native NFC tab (`ContentView` / WK intercept).
    static let nfcTabURL = "redmed://nfc"

    /// Live App Store listing URL. `nil` until a paid Apple Developer account
    /// has a real app ID — never write a placeholder onto QR or NFC.
    static let appStoreURL: String? = nil
    /// Unused in Swift (in-app Help is bundled `Document/Document.html`). Connect placeholders
    /// stay in this repo — not jsDelivr `@main` of a second tree.
    /// Live support page on the custom domain. Not the archived frisky GitHub blob.
    static let supportURL = "https://redmed.live/support/"
    /// Owner Help → Contact Support. Same address as Document.html Contact sections.
    static let supportEmail = "help@redmed.live"

    /// Owner band NDEF contract (permanent): write only
    /// `medicalCardBaseURL + "#d=" + base64url`. Profile stays in the fragment —
    /// no vendor tag-management cloud, no social/short-link redirect, no BLE.
    /// Pages hosts the static shell; PHI never leaves the `#d=` fragment.
    enum OwnerBandURI {
        /// NFC tab fact line — single source for “data independence” copy.
        static var dataIndependenceSummary: String {
            "Owner writes #d= on-chip — no vendor cloud, no social/short URL, no BLE."
        }

        /// Phone Keychain and chip are two copies. Neither depends on the other.
        static var storesIndependenceSummary: String {
            "This iPhone keeps your ID in Keychain. The chip keeps its own copy. Phone off, wiped, or in another state does not blank the band."
        }

        /// True only for live owner writes: exact tapper base + non-empty `#d=` payload.
        /// `nonisolated` — codec pack path runs off the main actor.
        nonisolated static func isValidWriteURL(_ urlString: String) -> Bool {
            let base = AppConfig.medicalCardBaseURL
            guard urlString.hasPrefix(base) else { return false }
            let rest = urlString.dropFirst(base.count)
            guard rest.hasPrefix("#d=") else { return false }
            let payload = rest.dropFirst(3)
            guard !payload.isEmpty else { return false }
            // Fragment only — reject query smuggling / `&tab=` / second hashes / whitespace.
            // Charset below also rejects `&`; keep the explicit set for fail-closed clarity.
            if payload.contains(where: {
                $0 == "#" || $0 == "?" || $0 == "&" || $0 == " " || $0 == "\n" || $0 == "\r"
            }) {
                return false
            }
            // AES-GCM wire is base64url (A–Z a–z 0–9 - _).
            return payload.unicodeScalars.allSatisfy { scalar in
                switch scalar.value {
                case 0x30...0x39, 0x41...0x5A, 0x61...0x7A, 0x2D, 0x5F: return true
                default: return false
                }
            }
        }
    }

    // MARK: - Paid Apple Developer Program (temporarily parked — do not delete)
    // CoreNFC Tag Reading, HealthKit, and a live App Store URL need a paid team
    // + App ID capabilities. Keep these false/nil until Max re-enables them.
    // Restore: docs/hardware/NFC-RESTORE.md, docs/hardware/associated-domains-restore.md,
    // docs/hardware/healthkit-restore.md. Do not remove code paths.

    /// Product kill switch for CoreNFC write/read sessions only.
    /// Owner still always sees the NFC tab (ContentView.showsNFC); scanners never do.
    /// `true` = owner Write/Scan start real `NFCNDEFReaderSession` against blank
    /// unlocked NXP NTAG216 (ISO 14443A Type 2). Write packs live RedMed into
    /// `medicalCardBaseURL#d=` (`OwnerBandURI`). Requires NFC Tag Reading on App ID
    /// `com.redmed.app` + paid Apple Developer — see `docs/hardware/NFC-RESTORE.md`.
    /// Keep this flag in lockstep with `RedMed.entitlements` + `NFCReaderUsageDescription`.
    /// `false` parks hardware sessions (Write The Band shown disabled).
    /// Gate logic stays correct for restore — see `docs/hardware/NFC-RESTORE.md`.
    /// Parked: entitlement + `NFCReaderUsageDescription` removed (bf3ee60).
    /// Keep flag false until restore steps in `docs/hardware/NFC-RESTORE.md`.
    /// No Share control — helpers open the card only by tapping the band
    /// (~1–2″); it loads in their browser.
    static let nfcHardwareEnabled = false

    /// `true` = `RedMed.entitlements` includes `applinks:redmed.live` so a phone
    /// with RedMed installed opens bundled tapper.html on `/tapper/` band taps
    /// instead of Safari. The band URL stays on the VPS. Requires Associated
    /// Domains on App ID `com.redmed.app` + a paid Apple Developer team — see
    /// `docs/hardware/associated-domains-restore.md`. Keep in lockstep with the
    /// entitlement. No custom-scheme fallback. NFC write stays separately parked.
    static let associatedDomainsEnabled = true

    /// Product kill switch for the optional Apple Health import on the empty-profile
    /// funnel / Edit. `true` = `HealthKitProfileImport` may call HealthKit.
    /// Requires the HealthKit capability on App ID `com.redmed.app` + paid Apple
    /// Developer — see `docs/hardware/healthkit-restore.md`. Parked (`false`): personal/free
    /// teams cannot provision HealthKit (same class of problem as NFC Tag Reading),
    /// so the entitlement stays out of `RedMed.entitlements` and the
    /// "Fill From Apple Health" button stays hidden until restored.
    static let healthKitImportEnabled = false

    /// Signed-in wearer copy in Supabase `redmed_owner`. Stays false in git.
    /// A local build turns sync on with `REDMED_PROFILE_SYNC = YES` next to the
    /// publishable key in `owner/Config/Supabase.xcconfig` (gitignored); see
    /// `ProfileCloudSync.isAvailable`. Document version 4.17 discloses it. The
    /// public tap page never calls Supabase. Sync does not rewrite a band.
    static let profileSyncEnabled = false

    /// Hardware RF contract for the RedMed bracelet.
    /// - Band is **passive**: no battery, no BLE/Wi‑Fi radio. RedMed only starts
    ///   CoreNFC on explicit Write/Scan. Separately, iOS Background Tag Reading
    ///   can energise a written NDEF URI tag on a deliberate tap even when the
    ///   phone is off or locked (antenna ~top ~1–2″ from the band) — RedMed
    ///   cannot disable that OS path. Write does not change BTR likelihood.
    ///   Band stays passive — no battery (not AirTag / BLE).
    /// - Band RF is **HF NFC at 13.56 MHz**, **ISO 14443A Type 2**, **NXP NTAG216**
    ///   NDEF blank unlocked. Different carrier from Bluetooth (~2.4 GHz).
    ///   Do not source NTAG213, NTAG215, MIFARE, LF (~125 kHz), or UHF (~860–960 MHz).
    /// - Factory: no pre-encode, no lock. Owner Write programs NDEF.
    /// - Face art is logo-print RedMed heart + wordmark (30×9 mm) on black `#232425` — not laser MED ID.
    /// - Contactless payment POS also uses 13.56 MHz but speaks EMV, not NDEF
    ///   medical URLs — protocol separation, not a distance knob.
    /// - Distances below describe HF NFC physics, not a tunable app setting.
    ///   Walk-by / hand nearby (~6–8″) does not fire. Deliberate antenna tap
    ///   is ~1–2″. Beyond ~4″ you are already outside reliable ISO 14443 coupling.
    enum BraceletRF {
        static let carrierMHz: Double = 13.56
        static let chipPart = "NXP NTAG216"
        static let family = "ISO 14443A Type 2 (NXP NTAG216)"
        static let laserFace = "RedMed" // logo-print face lock; display string for UI
        static let isPassive = true
        /// Blank / not permanently locked at factory — owner Write overwrites NDEF.
        static let isRewritable = true
        static let factoryPreEncode = false
        static let factoryLock = false
        static let usesBluetooth = false
        /// RedMed never starts NFC because a hand or band is merely nearby.
        static let requiresExplicitUserSession = true
        /// Walk-by / casual standoff (inches). Physics already drops off past ~4″;
        /// 6–8″ is enough product margin. Not a tunable read range.
        static let walkByStandoffInchesMin = 6
        static let walkByStandoffInchesMax = 8
        /// Intentional phone-antenna tap range (inches) — real HF NFC coupling.
        static let intentionalTapInchesMin = 1
        static let intentionalTapInchesMax = 2
        /// Beyond this, ISO 14443 coupling on a phone is unreliable.
        static let reliableCouplingInchesMax = 4
        /// Payment terminals speak EMV; they do not open RedMed NDEF URLs.
        static let ignoredByPaymentPOS = true

        // MARK: Product copy (single source — do not hardcode distances elsewhere)

        static var carrierLabel: String {
            String(format: "%.2f MHz HF NFC", carrierMHz)
        }

        static var walkByRangeLabel: String {
            "~\(walkByStandoffInchesMin)–\(walkByStandoffInchesMax)″"
        }

        static var intentionalTapRangeLabel: String {
            "~\(intentionalTapInchesMin)–\(intentionalTapInchesMax)″"
        }

        static var reliableCouplingLabel: String {
            "~\(reliableCouplingInchesMax)″"
        }

        /// NFC tab status line: walk-by vs deliberate tap.
        static var tapDistanceSummary: String {
            "Walk-by won't fire (\(walkByRangeLabel)). Only a deliberate \(intentionalTapRangeLabel) antenna tap opens the card."
        }

        static var carrierVsBluetoothSummary: String {
            "Passive \(chipPart) · \(carrierLabel) · ISO 14443A Type 2 — not Bluetooth 2.4 GHz."
        }

        static var chipSpecSummary: String {
            "\(chipPart), \(carrierLabel), ISO 14443A Type 2, NDEF blank unlocked. No pre-encode, no lock. Not NTAG213/215, MIFARE, LF, or UHF."
        }

        /// Hardware SKU: bracelet ships finished. Owner only programs NDEF.
        /// Just the chip — no battery, no extra electronics.
        static var completeBandSummary: String {
            "Band comes complete. Just the chip is needed. No battery."
        }

        static var laserFaceSummary: String {
            "Face: logo-print RedMed (30×9 mm) on black."
        }

        static var rewritableBandSummary: String {
            "NDEF blank unlocked — owner Write programs the band. Factory does not pre-encode or lock."
        }

        /// RedMed session behaviour — not Apple Background Tag Reading.
        static var powerOnTapSummary: String {
            "RedMed does not keep a background NFC pair. Chip is passive — no Bluetooth."
        }

        /// What can still open the URL later (Apple OS path; phone off / locked OK).
        /// Associated Domains: a phone with RedMed opens tapper.html instead of
        /// Safari. The band URL stays on the VPS. Passerby phones without the
        /// app still get Safari. Assist SOS never auto-arms on band tap.
        static var backgroundTagReadingSummary: String {
            let installPath = AppConfig.associatedDomainsEnabled
                ? "With RedMed installed, the tap opens tapper.html in the app instead of Safari."
                : "Until Associated Domains ships with band writing, a tap opens the card in Safari even with RedMed installed."
            return "iOS Background Tag Reading can still open the card later — phone can be off or locked; a deliberate tap (phone top \(intentionalTapRangeLabel) from the band) still works. \(installPath) Passerby phones without RedMed still get Safari Assist. Wrist + pocket is usually fine; phone pressed to the clasp can still couple. Writing the chip does not change that. Band stays passive — no battery, no Bluetooth to find nearby."
        }

        static var paymentPOSSummary: String {
            "POS ignore this chip (EMV ≠ NDEF) — not a distance setting."
        }

        static var passerbyTapSummary: String {
            "Any NFC phone held \(intentionalTapRangeLabel) from the band opens the card in that phone’s browser. No app, no login, no share link."
        }

        /// How It Works / setup prose for intentional tap vs walk-by.
        static var writeBandDistanceBlurb: String {
            "Walk-by distance will not fire the band; only a deliberate \(intentionalTapRangeLabel) antenna tap opens the card."
        }

        /// Alias for NFC / sourcing copy — band is never a BLE device.
        static var noBluetoothSummary: String { carrierVsBluetoothSummary }

        static var hardwareParkedSummary: String {
            // Max product note (2026-09-08): until Tag Reading is restored,
            // in-app Write is parked; Copy Band Link → NFC Tools writes
            // blank NTAG216 chips. No Developer-team jargon on this line.
            "Writing the band from RedMed is coming soon. For now, Copy Band Link, then write it with the free NFC Tools app to a blank factory-unlocked NXP NTAG216. RedMed can't check that write, so it will not mark Linked. After a band is written, helpers open it by holding any NFC phone \(intentionalTapRangeLabel) from the chip — the card loads in their browser."
        }

        /// NFC tab tip under the primary CTA — BraceletRF inches, not a hardcoded range.
        static var holdTopOfPhoneTip: String {
            "Hold your iPhone above the band, about \(intentionalTapInchesMin)–\(intentionalTapInchesMax) inches from the chip."
        }
    }

    /// NFC tab has one CTA only: Write The Band.
    /// Parked shows Write The Band as a quiet "coming soon" row, with
    /// `writeHelp` saying why in owner-facing words (no Developer-team
    /// jargon on primary chrome). An empty card shows Fill Medical ID instead.
    /// No Share — the card opens only on a close band tap, in the helper’s browser.
    enum NFCWriteCopy {
        static let writeTitle = "Write The Band"
        static var writeHelp: String {
            AppConfig.nfcHardwareEnabled
                ? "Hold phone above the band, then write"
                : "Coming soon to RedMed. Use NFC Tools for now."
        }
        static let writeBusyTitle = "Hold Above The Band…"
        static let successTitle = "Linked"
        /// Unlinked status on the RedMed header and the NFC chip. Parked:
        /// RedMed can't read back an NFC Tools write, so it says so in neutral
        /// grey instead of a red "Not Linked" the owner can never clear.
        /// Never "Linked" either way.
        static var unlinkedTitle: String {
            AppConfig.nfcHardwareEnabled ? "Not Linked" : "Band Not Checked"
        }
        /// Red only when in-app Write can actually fix it.
        static var unlinkedIsAlert: Bool { AppConfig.nfcHardwareEnabled }
        static var successDetail: String {
            "Any NFC phone held \(BraceletRF.intentionalTapRangeLabel) from this band opens your card in that phone’s browser."
        }
        /// Linked band, but RedMed was edited after the last verified write.
        static let staleTitle = "Band Out Of Date"
        static let staleDetail = "RedMed changed after the last write. Write The Band again so helpers see your current card."
        static let failTitle = "Couldn't write"
        static let failDetail = "Keep the phone still above the band, then try again."
        static var holdTopTip: String { BraceletRF.holdTopOfPhoneTip }

        /// NFC tab hero — one line under the hold diagram.
        static var pageIntro: String {
            AppConfig.nfcHardwareEnabled
                ? "Fill your card, put the band in front of you, then Write The Band while holding your phone above it."
                : "Copy your band link, then write it to the band with the free NFC Tools app. Helpers open a written band by tapping it — the card loads in their browser."
        }

        /// Hold-diagram caption (uses BraceletRF inches).
        static var holdDiagramCaption: String {
            "Phone above the band · \(BraceletRF.intentionalTapRangeLabel)"
        }

        /// Step-by-step tutorial on the NFC tab (owner-facing; not RF engineering).
        /// Step 2 uses `applewatch` — `wristwatch` paints blank on current Simulator SDKs.
        static var tutorialSteps: [(icon: String, title: String, detail: String)] {
            if AppConfig.nfcHardwareEnabled {
                return [
                    ("person.text.rectangle", "1 · Fill your card", "Name, birth date, blood type, and anything EMS should see on RedMed."),
                    ("applewatch", "2 · Band in front of you", "Lay the band where you can reach it with the top of your iPhone."),
                    ("wave.3.right", "3 · Write The Band", "Tap Write The Band and hold your phone \(BraceletRF.intentionalTapRangeLabel) above the chip until Linked.")
                ]
            }
            // Parked: same order as Do This Now — Copy Band Link, then NFC Tools.
            return [
                ("person.text.rectangle", "1 · Fill your card", "Name, birth date, blood type, and anything EMS should see on RedMed."),
                ("doc.on.doc", "2 · Copy Band Link", "Tap Copy Band Link above. It stays on this iPhone for 2 minutes."),
                ("wave.3.right", "3 · Write with NFC Tools", "Write → Add a record → URL, paste, Write. Hold your phone \(BraceletRF.intentionalTapRangeLabel) above the band."),
                ("safari", "4 · Helpers tap to open", "Any NFC phone held \(BraceletRF.intentionalTapRangeLabel) above the band opens your card in that phone’s browser.")
            ]
        }

        /// Parked only (hidden once `nfcHardwareEnabled`): owner copies the
        /// packed band URL and writes it with NFC Tools. Local-only pasteboard,
        /// short expiry. Not a Share — no share sheet, no other device.
        static let externalCopyTitle = "Copy Band Link"
        static let externalCopySubtitle = "For the free NFC Tools app"
        static let externalCopyLifetimeSeconds: TimeInterval = 120
        static let externalCopiedDetail =
            "Copied for 2 minutes, this iPhone only. In NFC Tools: Write → Add a record → URL, paste, Write, then hold the band. RedMed can't check that write, so it shows Band Not Checked."
        /// Replaces `externalCopiedDetail` once the pasteboard item expires,
        /// so the tab never claims a link that is no longer there.
        static let externalCopyExpiredDetail =
            "Link cleared. Copy again when you're in NFC Tools."
        static let externalCopyPrivacyTip =
            "The link is your card. Only paste it into NFC Tools."

        /// RedMed tab Get Started step 3 — the band step for the current flow.
        static var setupStepTitle: String {
            AppConfig.nfcHardwareEnabled ? writeTitle : externalCopyTitle
        }
        static var setupStepDetail: String {
            AppConfig.nfcHardwareEnabled
                ? "\(writeHelp) \(BraceletRF.completeBandSummary)"
                : "On the NFC tab, then write it to the band with NFC Tools. \(BraceletRF.completeBandSummary)"
        }

        static let aboutBandLabel = "Band details"
        static let doThisNowLabel = "Do this now"
        static let howItWorksLabel = "How it works"
        static let fillBeforeWrite =
            "Fill your card first. Your band link is made from it."
        /// Empty card: the NFC tab's one live action (same words as RedMed).
        static let fillCardTitle = "Fill Medical ID"
        /// Help → Bracelet row. Parked: RedMed can't write, so it says Set Up.
        static var helpBandRowTitle: String {
            AppConfig.nfcHardwareEnabled ? writeTitle : "Set Up Your Band"
        }
    }

    /// Owner Help → Common Questions. Answers reuse the NFC tab / band fact
    /// lines so Help never drifts from what the NFC tab says.
    enum HelpQuestions {
        static var all: [(question: String, answer: String)] {
            var items: [(question: String, answer: String)] = [
                ("How does someone open my card?", BraceletRF.passerbyTapSummary),
                ("Can people walking by read my band?", BraceletRF.tapDistanceSummary),
            ]
            if !AppConfig.nfcHardwareEnabled {
                items.append((
                    "Why does RedMed say \(NFCWriteCopy.unlinkedTitle)?",
                    "RedMed can't check a band written with NFC Tools, so it shows \(NFCWriteCopy.unlinkedTitle). A written band still opens your card when a helper taps it."
                ))
            }
            items.append(("What if my phone is off or erased?", OwnerBandURI.storesIndependenceSummary))
            return items
        }
    }

    /// Quiet prayer on owner Aid only (`AidView`, not scanner / tapper shells).
    enum QuietPrayer {
        static let fontSize: CGFloat = 11
        static let text =
            "Control your fear. Control the moment.\nYou have what it takes to save a life."
    }

    enum AidCopy {
        static let referenceDisclaimer =
            "First-aid reference only. Not medical advice and not a substitute for emergency dispatch. Call emergency services and follow their instructions."
    }

    /// Honesty for crash / SOS. Not Apple Crash Detection. No motion background mode.
    /// Owner CoreMotion: foreground + `.inactive` keep-listening only (no
    /// short-background grace — parked). Locking the phone backgrounds the app
    /// and stops new detection even if RedMed was open. Armed siren can keep
    /// going. Passerby tapper uses DeviceMotion only while the page is open.
    /// Keep `tapperNote` in lockstep with `tapper/index.html`.
    enum CrashAlarmCopy {
        static let findHelpNote =
            "SOS is full sound and full light so helpers can find you on a dark rainy night after a motorist ejects from a vehicle — only when you tap SOS · Locate Me, or when collision is detected (US Crash Detection delay). Crash detect (default thresholds) only for RedMed app users while RedMed is open. Locking the phone or leaving the app stops new detection — even if RedMed was open. Not Apple Crash Detection. For lock or kill, use iPhone Crash Detection if your device has it."
        static let tapperNote =
            "SOS is full sound and full light so helpers can find someone on a dark rainy night after a motorist ejects from a vehicle — only when you tap SOS · Locate Me, or when collision is detected (US Crash Detection delay). Not Apple Crash Detection. Crash detect only while this page is open. Band tap does not arm SOS."
    }

    /// Carrier notes + local-only rule for Aid footers.
    /// Call uses system `tel:` only — never attaches profile / PII / PHI / GPS.
    /// Keep `localOnlyLine` in lockstep with `tapper/index.html` Aid foot-note.
    enum Satellite {
        /// Permanent product rule — do not soften or time-box.
        static let localOnlyLine =
            "Local only once tap — no RedMed servers. No Bluetooth · passive HF NFC. Call uses system tel: only (no profile, no GPS on the call). Nearby hospitals is app-only and asks Apple Maps on this phone. A band tap in a browser shows first-aid tutorials built into the page and reaches no server."
    }
}
