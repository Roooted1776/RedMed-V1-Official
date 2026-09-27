import Foundation
import SwiftUI

/// Keychain stays the offline copy. When sync is available (see `isAvailable`)
/// a signed-in save also upserts `redmed_owner.profiles`.
/// A failed network call leaves the Keychain edit in place; launch, foreground,
/// and Sync Now retry. The band is not cleared and is not rewritten from the cloud.
///
/// Ordering: every save bumps a local revision and hands its fields to one
/// serial push queue that keeps only the newest pending save, so an older
/// save can never land after a newer one. `updated_at` is server-owned; the
/// app only compares server stamps with server stamps.
enum ProfileCloudSync {
    private static let revisionKey = "redmed.profile.localRevision"
    private static let ackedKey = "redmed.profile.ackedRevision"
    private static let remoteStampKey = "redmed.profile.remoteUpdatedAt"
    private static let bandStampKey = "redmed.profile.lastVerifiedWriteAt"
    private static let pendingEraseKey = "redmed.profile.pendingRemoteErase"
    private static let lastSyncedKey = "redmed.profile.lastSyncedAt"

    /// Product flag (git: false) or the local xcconfig opt-in, plus a real key.
    static var isAvailable: Bool {
        (AppConfig.profileSyncEnabled || SupabaseConfig.buildOptIn) && SupabaseConfig.isConfigured
    }

    static var isSignedIn: Bool {
        OwnerSupabaseClient.shared.currentSession() != nil
    }

    static var lastSyncedAt: Date? {
        UserDefaults.standard.object(forKey: lastSyncedKey) as? Date
    }

    static var lastVerifiedBandWriteAt: Date? {
        SyncStamp.date(UserDefaults.standard.string(forKey: bandStampKey))
    }

    // MARK: - Push

    static func enqueuePush(fields: OwnerProfileRecord) {
        guard isAvailable, isSignedIn, !hasPendingErase else { return }
        let revision = UserDefaults.standard.integer(forKey: revisionKey) + 1
        UserDefaults.standard.set(revision, forKey: revisionKey)
        Task { await PushQueue.shared.submit(fields, revision: revision) }
    }

    static func keepLocal(_ profile: ProfileData) {
        profile.cloudConflict = nil
        // Adopt the remote stamp we just saw so the next pull doesn't re-prompt
        // on the same row, then push this iPhone's copy over it.
        if let stamp = pendingConflictStamp {
            UserDefaults.standard.set(stamp, forKey: remoteStampKey)
            pendingConflictStamp = nil
        }
        enqueuePush(fields: profile.cloudFields())
    }

    // MARK: - Pull

    /// Launch / foreground / Sync Now. Order: finish a pending erase, then
    /// pull, then push if this iPhone is ahead.
    @MainActor
    static func pullIfNeeded(into profile: ProfileData) async {
        let status = CloudSyncStatus.shared
        guard isAvailable else { status.phase = .off; return }
        guard isSignedIn else { status.phase = .signedOut; return }
        lastAttempt = Date()

        if hasPendingErase {
            await performPendingErase()
            return
        }
        // Edit holds draft PHI; applying a remote row under it would clobber
        // the draft or be clobbered by Save. Retry on the next foreground.
        guard !profile.holdsEditingSession else { return }

        status.phase = .syncing
        do {
            guard let remote = try await OwnerSupabaseClient.shared.pull() else {
                // Signed in, no row yet: seed it from this iPhone.
                if profile.hasSensitiveProfileData {
                    await PushQueue.shared.submit(profile.cloudFields(), revision: currentRevision)
                } else {
                    markSynced()
                }
                profile.accountNewerThanBand = false
                return
            }
            let known = UserDefaults.standard.string(forKey: remoteStampKey)
            let remoteIsNewer = SyncStamp.isNewer(remote.updatedAt, than: known)
            let localHas = profile.hasSensitiveProfileData
            // First sign-in on a phone that already has an ID (`known` empty)
            // or unsynced local edits: ask, never silently overwrite.
            if remoteIsNewer && localHas && (isDirty || known == nil) {
                pendingConflictStamp = remote.updatedAt
                profile.cloudConflict = remote
                status.phase = .idle
            } else if remoteIsNewer {
                profile.applyCloudRecord(remote)
                markSynced()
            } else if localHas && isDirty {
                await PushQueue.shared.submit(profile.cloudFields(), revision: currentRevision)
            } else {
                markSynced()
            }
            profile.accountNewerThanBand = bandIsBehind(remoteStamp: remote.updatedAt)
        } catch {
            profile.accountNewerThanBand = false
            status.record(error)
        }
    }

    /// Foreground retry. Throttled so app-switcher flicks don't hammer the API.
    @MainActor
    static func syncOnForeground(_ profile: ProfileData) async {
        if let lastAttempt, Date().timeIntervalSince(lastAttempt) < 30 { return }
        await pullIfNeeded(into: profile)
    }

    /// Called by `applyCloudRecord` after a pulled row lands in Keychain.
    static func markClean(stamp: String?) {
        UserDefaults.standard.set(currentRevision, forKey: ackedKey)
        if let stamp, !stamp.isEmpty {
            UserDefaults.standard.set(stamp, forKey: remoteStampKey)
        }
    }

    // MARK: - Sign in / out

    @MainActor
    static func didSignIn(into profile: ProfileData) async {
        // A different account on this iPhone must not inherit the old stamps.
        resetBookkeeping()
        CloudSyncStatus.shared.refresh()
        await pullIfNeeded(into: profile)
    }

    @MainActor
    static func signOut() async {
        await OwnerSupabaseClient.shared.signOutEverywhere()
        resetBookkeeping()
        CloudSyncStatus.shared.refresh()
    }

    /// Lost-phone path: revoke every session on the account, including this one.
    @MainActor
    static func signOutAllDevices() async throws {
        try await OwnerSupabaseClient.shared.signOutAllDevices()
        resetBookkeeping()
        CloudSyncStatus.shared.refresh()
    }

    /// Deletes the sign-in and its account copy on the server. RedMed on this
    /// iPhone (Keychain) and the band are untouched. Online only: throws
    /// rather than queueing, so the owner sees whether it happened.
    @MainActor
    static func deleteAccount() async throws {
        try await OwnerSupabaseClient.shared.deleteAccount()
        UserDefaults.standard.set(false, forKey: pendingEraseKey)
        resetBookkeeping()
        CloudSyncStatus.shared.refresh()
    }

    // MARK: - Erase

    /// Owner Erase All. Durable: if the delete fails (offline), the flag
    /// survives relaunch and blocks every pull until the account copy is gone,
    /// so an erased iPhone can't pull the old profile back in.
    static func eraseRemote() {
        guard isAvailable, isSignedIn else {
            resetBookkeeping()
            return
        }
        UserDefaults.standard.set(true, forKey: pendingEraseKey)
        Task { @MainActor in await performPendingErase() }
    }

    static var hasPendingErase: Bool {
        UserDefaults.standard.bool(forKey: pendingEraseKey)
    }

    @MainActor
    private static func performPendingErase() async {
        let status = CloudSyncStatus.shared
        status.phase = .syncing
        do {
            try await OwnerSupabaseClient.shared.deleteAccountCopy()
            UserDefaults.standard.set(false, forKey: pendingEraseKey)
            await signOut()
        } catch OwnerSyncError.signedOut {
            // Session is gone; nothing this iPhone can delete any more.
            UserDefaults.standard.set(false, forKey: pendingEraseKey)
            resetBookkeeping()
            status.refresh()
        } catch {
            status.record(error)
        }
    }

    // MARK: - Band

    static func recordVerifiedWrite(url: String) {
        guard AppConfig.OwnerBandURI.isValidWriteURL(url) else { return }
        UserDefaults.standard.set(SyncStamp.string(Date()), forKey: bandStampKey)
        guard isAvailable, isSignedIn else { return }
        let bytes = url.utf8.count
        Task {
            try? await OwnerSupabaseClient.shared.recordVerifiedWrite(url: url, byteLength: bytes)
        }
    }

    // MARK: - Private

    @MainActor private static var lastAttempt: Date?
    /// `updated_at` of the row behind the open conflict prompt.
    private static var pendingConflictStamp: String?

    private static var currentRevision: Int {
        UserDefaults.standard.integer(forKey: revisionKey)
    }

    private static var isDirty: Bool {
        currentRevision != UserDefaults.standard.integer(forKey: ackedKey)
    }

    private static func resetBookkeeping() {
        for key in [revisionKey, ackedKey, remoteStampKey, lastSyncedKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        pendingConflictStamp = nil
    }

    @MainActor
    private static func markSynced() {
        let now = Date()
        UserDefaults.standard.set(now, forKey: lastSyncedKey)
        CloudSyncStatus.shared.phase = .idle
        CloudSyncStatus.shared.lastSyncedAt = now
    }

    private static func bandIsBehind(remoteStamp: String?) -> Bool {
        guard let remote = SyncStamp.date(remoteStamp),
              let band = lastVerifiedBandWriteAt else { return false }
        return remote > band
    }

    /// One network push. Serialized by `PushQueue`.
    fileprivate static func pushNow(fields: OwnerProfileRecord, revision: Int) async {
        await MainActor.run { CloudSyncStatus.shared.phase = .syncing }
        do {
            let stored = try await OwnerSupabaseClient.shared.push(fields)
            await MainActor.run {
                // Our own write: always adopt its stamp so it never reads as
                // a foreign newer row. Ack only if no newer save queued since.
                if let stamp = stored?.updatedAt, !stamp.isEmpty {
                    UserDefaults.standard.set(stamp, forKey: remoteStampKey)
                }
                if currentRevision == revision {
                    UserDefaults.standard.set(revision, forKey: ackedKey)
                }
                markSynced()
            }
        } catch {
            // Keychain already has the edit. Foreground / next launch retries.
            await MainActor.run { CloudSyncStatus.shared.record(error) }
        }
    }
}

/// Serial, coalescing push. Only the newest queued save is sent after the
/// in-flight one finishes.
private actor PushQueue {
    static let shared = PushQueue()
    private var pending: (fields: OwnerProfileRecord, revision: Int)?
    private var running = false

    func submit(_ fields: OwnerProfileRecord, revision: Int) async {
        pending = (fields, revision)
        guard !running else { return }
        running = true
        while let job = pending {
            pending = nil
            await ProfileCloudSync.pushNow(fields: job.fields, revision: job.revision)
        }
        running = false
    }
}

/// Owner-visible sync state for Account sync. No PHI.
@MainActor
final class CloudSyncStatus: ObservableObject {
    static let shared = CloudSyncStatus()

    enum Phase: Equatable {
        /// Build has no key or sync is not opted in.
        case off
        case signedOut
        case idle
        case syncing
        case failed(String)
    }

    @Published var phase: Phase = .off
    @Published var lastSyncedAt: Date?
    @Published private(set) var email: String?

    private init() {
        refresh()
    }

    func refresh() {
        let session = OwnerSupabaseClient.shared.currentSession()
        email = session?.email
        lastSyncedAt = ProfileCloudSync.lastSyncedAt
        if !ProfileCloudSync.isAvailable {
            phase = .off
        } else if session == nil {
            phase = .signedOut
        } else if case .failed = phase {
            // Keep the last error visible until the next attempt.
        } else if phase != .syncing {
            phase = .idle
        }
    }

    func record(_ error: Error) {
        // A push still in flight when the owner signed out or deleted the
        // account fails against a dead session. That is not a retry state.
        if OwnerSupabaseClient.shared.currentSession() == nil {
            email = nil
            phase = ProfileCloudSync.isAvailable ? .signedOut : .off
            return
        }
        if let sync = error as? OwnerSyncError {
            if sync == .signedOut {
                email = nil
                phase = .signedOut
            } else {
                phase = .failed(sync.ownerMessage)
            }
        } else {
            phase = .failed("Sync failed. RedMed will retry.")
        }
    }
}

/// Postgres `timestamptz` strings (`2026-09-26T12:34:56.123456+00:00`) and
/// the app's own ISO 8601 stamps, compared as dates rather than strings.
enum SyncStamp {
    static func date(_ raw: String?) -> Date? {
        guard var s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        // Normalize fractional seconds to 3 digits for ISO8601DateFormatter.
        if let dot = s.firstIndex(of: "."), let end = s[dot...].firstIndex(where: { !$0.isNumber && $0 != "." }) {
            let digits = s[s.index(after: dot)..<end]
            let ms = String((digits + "000").prefix(3))
            s.replaceSubrange(dot..<end, with: "." + ms)
        }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: s) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: s)
    }

    static func string(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }

    /// `a` strictly newer than `b`. A missing `b` means anything is newer.
    static func isNewer(_ a: String?, than b: String?) -> Bool {
        guard let a, !a.isEmpty else { return false }
        guard let b, !b.isEmpty else { return true }
        if let da = date(a), let db = date(b) { return da > db }
        return a > b
    }
}
