import Foundation

/// Keychain stays the offline copy. When `profileSyncEnabled` is on and a
/// publishable key is present, a signed-in save also upserts `redmed_owner`.
/// A failed network call leaves the Keychain edit in place and retries later.
/// The band is not cleared and is not rewritten from the cloud.
enum ProfileCloudSync {
    private static let revisionKey = "redmed.profile.localRevision"
    private static let ackedKey = "redmed.profile.ackedRevision"
    private static let remoteStampKey = "redmed.profile.remoteUpdatedAt"
    private static let bandStampKey = "redmed.profile.lastVerifiedWriteAt"

    static func enqueuePush(fields: OwnerProfileRecord) {
        guard AppConfig.profileSyncEnabled, SupabaseConfig.isConfigured else { return }
        let revision = UserDefaults.standard.integer(forKey: revisionKey) + 1
        UserDefaults.standard.set(revision, forKey: revisionKey)
        Task {
            await push(fields: fields, revision: revision)
        }
    }

    @MainActor
    static func pullIfNeeded(into profile: ProfileData) async {
        guard AppConfig.profileSyncEnabled, SupabaseConfig.isConfigured else { return }
        guard OwnerSupabaseClient.shared.currentSession() != nil else { return }
        do {
            guard let remote = try await OwnerSupabaseClient.shared.pull() else {
                if isDirty {
                    await push(fields: profile.cloudFields(), revision: UserDefaults.standard.integer(forKey: revisionKey))
                }
                profile.accountNewerThanBand = false
                return
            }
            let known = UserDefaults.standard.string(forKey: remoteStampKey) ?? ""
            let remoteStamp = remote.updatedAt ?? ""
            let remoteIsNewer = !remoteStamp.isEmpty && remoteStamp > known
            let localHas = profile.hasSensitiveProfileData
            if remoteIsNewer && localHas && (isDirty || known.isEmpty) {
                profile.cloudConflict = remote
            } else if remoteIsNewer {
                profile.applyCloudRecord(remote)
            } else if localHas && (isDirty || known.isEmpty) {
                await push(fields: profile.cloudFields(), revision: UserDefaults.standard.integer(forKey: revisionKey))
            }
            profile.accountNewerThanBand = bandIsBehind(remoteStamp: remote.updatedAt)
        } catch {
            profile.accountNewerThanBand = false
        }
    }

    static func keepLocal(_ profile: ProfileData) {
        profile.cloudConflict = nil
        enqueuePush(fields: profile.cloudFields())
    }

    static func markClean(stamp: String?) {
        let revision = UserDefaults.standard.integer(forKey: revisionKey)
        UserDefaults.standard.set(revision, forKey: ackedKey)
        if let stamp, !stamp.isEmpty {
            UserDefaults.standard.set(stamp, forKey: remoteStampKey)
        }
    }

    static func eraseRemote() {
        guard AppConfig.profileSyncEnabled, SupabaseConfig.isConfigured else { return }
        UserDefaults.standard.set(0, forKey: revisionKey)
        UserDefaults.standard.set(0, forKey: ackedKey)
        UserDefaults.standard.removeObject(forKey: remoteStampKey)
        Task {
            try? await OwnerSupabaseClient.shared.deleteAccountCopy()
            OwnerSupabaseClient.shared.signOut()
        }
    }

    static func recordVerifiedWrite(url: String) {
        guard AppConfig.profileSyncEnabled, SupabaseConfig.isConfigured else { return }
        guard AppConfig.OwnerBandURI.isValidWriteURL(url) else { return }
        let bytes = url.utf8.count
        UserDefaults.standard.set(ISO8601DateFormatter().string(from: Date()), forKey: bandStampKey)
        Task {
            try? await OwnerSupabaseClient.shared.recordVerifiedWrite(url: url, byteLength: bytes)
        }
    }

    private static var isDirty: Bool {
        UserDefaults.standard.integer(forKey: revisionKey) != UserDefaults.standard.integer(forKey: ackedKey)
    }

    private static func bandIsBehind(remoteStamp: String?) -> Bool {
        guard let remoteStamp, !remoteStamp.isEmpty,
              let band = UserDefaults.standard.string(forKey: bandStampKey), !band.isEmpty else {
            return false
        }
        return remoteStamp > band
    }

    private static func push(fields: OwnerProfileRecord, revision: Int) async {
        do {
            try await OwnerSupabaseClient.shared.push(fields)
            let pulled = try await OwnerSupabaseClient.shared.pull()
            await MainActor.run {
                guard UserDefaults.standard.integer(forKey: revisionKey) == revision else { return }
                UserDefaults.standard.set(revision, forKey: ackedKey)
                if let stamp = pulled?.updatedAt {
                    UserDefaults.standard.set(stamp, forKey: remoteStampKey)
                }
            }
        } catch {
            // Keychain already has the edit. The next launch retries.
        }
    }
}
