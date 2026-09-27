import Combine
import CryptoKit
import Foundation
import SwiftUI

/// Drop-in SwiftUI manager for the silicone NFC band pipeline:
///
/// ```
/// [Silicone NFC Band] ──(Tap)──> [iPhone Antenna]
///        ──> [CoreNFC] ──> strip NDEF URI ──> [CryptoKit AES-GCM]
///        ──> [tap card HTML shell]
/// ```
///
/// Owns hardware write/read sessions (`NFCWriter` / `NFCReader`), NDEF URI
/// envelope handling (`NFCURICodec`), and CryptoKit pack/unpack
/// (`ProfileNFCCodec`). Chip bytes stay on device. A verified write may store a
/// sha256 of the packed URL on the signed-in account — never the raw `#d=`. Owner NFC tab
/// only; scanners never mount this manager for setup.
/// Band writes use live `AppConfig.medicalCardBaseURL#d=` only (owner data
/// independence: no vendor cloud, no social/short URL, no BLE).
final class NFCBandManager: ObservableObject {
    @Published var statusMessage: String = ""
    @Published var isWriting = false
    @Published var isReading = false
    @Published var writeSucceeded = false
    @Published var writeVerified = false
    @Published var lastPackedURL: String?
    /// Scan / simulate → full passerby shell (item present; payload never empty).
    /// This path is for hardware verifyBand, not owner-facing NFC tab UI.
    @Published var scannedCard: ScannedCardSession?
    @Published var alertMessage: String?
    /// Band still carries what RedMed shows now. `nil` = no verified write on
    /// this iPhone to compare against. `false` = edited since the last write.
    @Published private(set) var bandMatchesProfile: Bool?
    /// Digest of the chip being written; committed only after read-back matches.
    private var pendingChipDigest: Data?
    /// Swaps the "Copied for 2 minutes" line once the pasteboard item expires.
    private var copiedLinkExpiry: Task<Void, Never>?

    /// One-shot Scan open.
    struct ScannedCardSession: Identifiable {
        let id = UUID()
        let payload: String
        let embedJSON: String?
    }

    /// CoreNFC sessions stay cold until first write/read — YOU-card open
    /// must not pay for NFCWriter / NFCReader construction.
    private var writerStorage: NFCWriter?
    private var readerStorage: NFCReader?
    private var didBindSessions = false
    private var cancellables = Set<AnyCancellable>()
    var isBusy: Bool { isWriting || isReading }

    private var writer: NFCWriter {
        ensureSessions()
        return writerStorage!
    }

    private var reader: NFCReader {
        ensureSessions()
        return readerStorage!
    }

    init() {}

    private func ensureSessions() {
        if writerStorage == nil { writerStorage = NFCWriter() }
        if readerStorage == nil { readerStorage = NFCReader() }
        guard !didBindSessions else { return }
        didBindSessions = true
        bindSessions()
    }

    // MARK: - Write (owner band setup)

    /// Snapshot live RedMed → AES-GCM `#d=` → CoreNFC write (or pack-only when parked).
    /// Pack + `session.begin()` stay on this tap's stack (NFC tab open / Write).
    /// Once the sheet is up, hold the band ~1–2″ to finish. CoreNFC drops the
    /// sheet if Write hops through `Task` / `Task.detached` first.
    /// No Face ID here — post-Agree / Edit / Save / Erase only
    /// (not viewing the YOU card).
    /// Linked / Not linked flips only after a real verified CoreNFC write —
    /// never simulate or share.
    func writeBand(from profile: ProfileData, isScannerSession: Bool) {
        guard !isScannerSession else { return }
        guard !isBusy else { return }
        guard profile.hasSensitiveProfileData else { return }

        guard let packed = packAndValidate(profile: profile) else { return }
        lastPackedURL = packed.urlString
        if AppConfig.nfcHardwareEnabled {
            statusMessage = ""
            writeSucceeded = false
            writeVerified = false
            pendingChipDigest = BandFreshness.digest(packed.chip)
            writer.writeURL(packed.urlString)
        } else {
            // Parked: pack only — never a Write, never Linked.
            writeSucceeded = false
            writeVerified = false
            isWriting = false
            statusMessage = ""
        }
    }

    /// Parked only: put the packed band URL on this iPhone's pasteboard so the
    /// owner can write it with an outside NDEF writer (NFC Tools). Same pack,
    /// same `isValidWriteURL`, same 850-byte cap as `writeBand`. Local-only
    /// pasteboard (no Universal Clipboard), gone after
    /// `AppConfig.NFCWriteCopy.externalCopyLifetimeSeconds`. Never Linked —
    /// RedMed did not write or read back the chip.
    func copyBandLinkForExternalWriter(from profile: ProfileData, isScannerSession: Bool) {
        guard !AppConfig.nfcHardwareEnabled else { return }
        guard !isScannerSession else { return }
        guard !isBusy else { return }
        guard profile.hasSensitiveProfileData else { return }

        guard let packed = packAndValidate(profile: profile) else { return }
        SecurePasteboard.copyEphemeral(
            packed.urlString,
            lifetimeSeconds: AppConfig.NFCWriteCopy.externalCopyLifetimeSeconds
        )
        writeSucceeded = false
        writeVerified = false
        statusMessage = AppConfig.NFCWriteCopy.externalCopiedDetail
        scheduleCopiedLinkExpiry()
    }

    /// Shared pack/validate/size-check for both the hardware write path and
    /// the external-writer copy path. Sets `alertMessage` and returns `nil`
    /// on any validation failure.
    private struct PackedBand {
        let chip: NFCChipProfile
        let urlString: String
    }

    private func packAndValidate(profile: ProfileData) -> PackedBand? {
        let chip = ProfileNFCCodec.chipProfile(from: profile)
        guard let urlString = ProfileNFCCodec.buildURLString(chip: chip),
              AppConfig.OwnerBandURI.isValidWriteURL(urlString) else {
            alertMessage = "Couldn't build a RedMed #d= tag payload (vendor/social URLs are blocked)."
            return nil
        }
        guard urlString.utf8.count <= 850 else {
            alertMessage = "\(urlString.utf8.count) bytes — too large for NXP NTAG216. Shorten RedMed."
            return nil
        }
        return PackedBand(chip: chip, urlString: urlString)
    }

    /// Same lifetime as the pasteboard expiry. Continuous clock so time spent
    /// in NFC Tools (RedMed suspended) or with the screen locked still counts.
    /// Leaves any newer status alone.
    private func scheduleCopiedLinkExpiry() {
        copiedLinkExpiry?.cancel()
        let lifetime = AppConfig.NFCWriteCopy.externalCopyLifetimeSeconds
        copiedLinkExpiry = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(lifetime), clock: .continuous)
            guard !Task.isCancelled, let self,
                  self.statusMessage == AppConfig.NFCWriteCopy.externalCopiedDetail else { return }
            self.statusMessage = AppConfig.NFCWriteCopy.externalCopyExpiredDetail
        }
    }

    /// Compare live RedMed with the last verified write. Cheap: one SHA-256
    /// over the chip JSON plus a non-interactive Keychain read.
    func refreshFreshness(from profile: ProfileData) {
        guard profile.hasSensitiveProfileData else {
            bandMatchesProfile = nil
            return
        }
        bandMatchesProfile = BandFreshness.matches(ProfileNFCCodec.chipProfile(from: profile))
    }

    /// Drop a live write/read sheet when leaving the NFC tab.
    func cancelSessions() {
        guard didBindSessions else { return }
        writer.cancel()
        reader.cancel()
    }

    // MARK: - Verify / scan (same HTML shell a stranger gets on band tap)

    /// Hardware path: CoreNFC → strip NDEF → open bundled tap card (?src=app, no SOS arm).
    /// Simulate path: pack live RedMed → same one-page HTML cover (tap card).
    /// Hardware sessions gated by `AppConfig.nfcHardwareEnabled`.
    func verifyBand(from profile: ProfileData) {
        guard !isBusy else { return }
        if AppConfig.nfcHardwareEnabled {
            statusMessage = ""
            reader.readTag(alertMessage: "Hold your iPhone near the bracelet to verify the card.") { [weak self] _, urlString in
                self?.presentHTMLCard(payloadOrURL: urlString)
            }
            return
        }

        let chip = ProfileNFCCodec.chipProfile(from: profile)
        isReading = true
        statusMessage = "Opening tap card…"
        Task { @MainActor [weak self] in
            let packed = await Task.detached(priority: .userInitiated) {
                (
                    ProfileNFCCodec.buildURLString(chip: chip),
                    ProfileNFCCodec.embedProfileJSON(from: chip)
                )
            }.value
            guard let self else { return }
            self.isReading = false
            self.statusMessage = ""
            guard let url = packed.0 else {
                self.alertMessage = "Couldn't pack or decode the tap card from RedMed."
                return
            }
            self.presentHTMLCard(payloadOrURL: url, embedJSON: packed.1)
        }
    }

    func dismissScannedCard() {
        scannedCard = nil
    }

    /// Universal Link / notification path: open the hosted `#d=` as an in-app
    /// tap card (`?src=app`, no SOS). Does not touch owner Keychain.
    func presentBandURLFromUniversalLink(_ urlString: String) {
        presentHTMLCard(payloadOrURL: urlString)
    }

    /// Mark owner bracelet paired after a real CoreNFC write **and** matching read-back.
    func linkBracelet(on profile: ProfileData, detail: String) {
        guard AppConfig.nfcHardwareEnabled, writeVerified else { return }
        guard profile.setBraceletPaired(true) else {
            alertMessage = "Bracelet write succeeded, but RedMed couldn't save the paired status. Try again."
            return
        }
    }

    // MARK: - Private

    private func bindSessions() {
        writer.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        reader.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        writer.$statusMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in
                guard let self else { return }
                self.isWriting = self.writer.isWriting
                self.writeSucceeded = self.writer.success
                self.writeVerified = self.writer.verified
                if self.writer.isWriting || self.statusMessage.isEmpty || msg != "Cancelled." {
                    self.statusMessage = msg
                }
                if !self.writer.isWriting, !self.writer.success, !msg.isEmpty, msg != "Cancelled." {
                    self.alertMessage = msg
                }
            }
            .store(in: &cancellables)

        writer.$isWriting
            .receive(on: DispatchQueue.main)
            .assign(to: &$isWriting)

        writer.$success
            .combineLatest(writer.$verified)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] success, verified in
                guard let self else { return }
                // Settle bandMatchesProfile before publishing writeSucceeded/
                // writeVerified — NFCView reacts to those via onChange and
                // must never observe a "verified" state before this is set.
                let url = self.writer.lastVerifiedURL
                if success, verified, !url.isEmpty {
                    ProfileCloudSync.recordVerifiedWrite(url: url)
                    if let digest = self.pendingChipDigest {
                        BandFreshness.recordVerifiedWrite(digest)
                        self.bandMatchesProfile = true
                    }
                    self.pendingChipDigest = nil
                }
                self.writeSucceeded = success
                self.writeVerified = verified
            }
            .store(in: &cancellables)

        reader.$statusMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in
                guard let self else { return }
                self.isReading = self.reader.isReading
                if self.reader.isReading {
                    self.statusMessage = msg
                } else if !msg.isEmpty, msg != "Cancelled." {
                    self.alertMessage = msg
                }
            }
            .store(in: &cancellables)

        reader.$isReading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isReading)
    }

    private func presentHTMLCard(payloadOrURL: String, embedJSON: String? = nil) {
        guard PasserbyHTMLCardView.extractPayload(payloadOrURL) != nil else {
            alertMessage = "Couldn't read a RedMed tap card from this tag."
            return
        }
        scannedCard = ScannedCardSession(payload: payloadOrURL, embedJSON: embedJSON)
    }
}

/// Remembers what the band holds without keeping the band's `#d=` string.
/// Stores SHA-256 of the chip profile (sorted-key JSON, `updated` stamp
/// excluded so a same-content re-save on a new day isn't "stale") in
/// Keychain, this-device-only. Written only after a verified read-back.
enum BandFreshness {
    private static let account = "band.chipDigest.v1"

    static func digest(_ chip: NFCChipProfile) -> Data? {
        var canonical = chip
        canonical.updated = ""
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let json = try? encoder.encode(canonical) else { return nil }
        return Data(SHA256.hash(data: json))
    }

    static func recordVerifiedWrite(_ digest: Data) {
        _ = KeychainStore.save(digest, account: account)
    }

    /// `nil` when no verified write was recorded on this iPhone.
    static func matches(_ chip: NFCChipProfile) -> Bool? {
        guard let stored = KeychainStore.load(account: account, allowLegacy: false),
              let current = digest(chip) else { return nil }
        return stored == current
    }

    static func clear() {
        _ = KeychainStore.deleteIncludingStaging(account: account)
    }
}
