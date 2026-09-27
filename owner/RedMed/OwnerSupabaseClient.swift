import CryptoKit
import Foundation

/// Publishable Supabase client for the signed-in wearer copy.
/// Values come from Info.plist, filled by `owner/Config/Supabase.xcconfig`
/// (gitignored): `SUPABASE_URL` = `https://$(SUPABASE_HOST)`,
/// `SUPABASE_PUBLISHABLE_KEY`, `REDMED_PROFILE_SYNC`. Neither host nor key is
/// committed. `service_role` is never used. The public tap page does not use
/// this client. Server schema: `supabase/migrations/*_redmed_owner.sql`.
enum SupabaseConfig {
    static var projectURL: URL? {
        let raw = plistString("SUPABASE_URL")
        // An unset SUPABASE_HOST leaves a bare "https://" behind. Require a host.
        guard raw.hasPrefix("https://"),
              let url = URL(string: raw),
              let host = url.host, host.contains(".") else { return nil }
        return url
    }

    static var publishableKey: String {
        plistString("SUPABASE_PUBLISHABLE_KEY")
    }

    static var isConfigured: Bool {
        projectURL != nil && !publishableKey.isEmpty
    }

    /// `REDMED_PROFILE_SYNC = YES` in the local xcconfig that also holds the key.
    /// Git keeps `AppConfig.profileSyncEnabled = false` and this `NO`, so a
    /// clone without a key never tries the network.
    static var buildOptIn: Bool {
        plistString("REDMED_PROFILE_SYNC").uppercased() == "YES"
    }

    private static func plistString(_ key: String) -> String {
        let raw = (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // An unexpanded build setting means the xcconfig was not applied.
        return raw.contains("$(") ? "" : raw
    }
}

struct OwnerContactRecord: Codable, Equatable, Sendable {
    var name: String
    var relationship: String
    var phone: String
}

/// PostgREST row. Column names match `redmed_owner.profiles`.
struct OwnerProfileRecord: Codable, Equatable, Sendable {
    var id: String
    var name: String
    var birthDate: String
    var bloodType: String
    var allergies: [String]
    var medications: [String]
    var conditions: [String]
    var contacts: [OwnerContactRecord]
    var braceletLinked: Bool
    var isOrganDonor: Bool
    var isPregnant: Bool
    var isDeafOrVisionImpaired: Bool
    var lastUpdated: String
    var notes: String
    /// Server-owned (trigger). Never trusted from the phone clock.
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, notes
        case birthDate = "birth_date"
        case bloodType = "blood_type"
        case allergies, medications, conditions, contacts
        case braceletLinked = "bracelet_linked"
        case isOrganDonor = "is_organ_donor"
        case isPregnant = "is_pregnant"
        case isDeafOrVisionImpaired = "is_deaf_or_vision_impaired"
        case lastUpdated = "last_updated"
        case updatedAt = "updated_at"
    }

    /// Upsert body. `updated_at` is left to the server trigger.
    func forUpsert(userId: String) -> OwnerProfileRecord {
        var row = self
        row.id = userId
        row.updatedAt = nil
        return row
    }
}

struct OwnerSession: Codable, Equatable, Sendable {
    var accessToken: String
    var refreshToken: String
    var userId: String
    var expiresAt: Date
    /// Shown on Account sync. Optional so sessions stored before this field decode.
    var email: String?
}

/// Auth + PostgREST for `redmed_owner`. Network only. No `#d=` string is sent.
/// An actor so two callers can't race the same refresh token.
actor OwnerSupabaseClient {
    static let shared = OwnerSupabaseClient()

    private static let sessionAccount = "supabase.session.v1"

    /// Ephemeral: no disk URLCache, no cookies. Profile responses are PHI.
    private let http: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 40
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    private var refreshTask: Task<OwnerSession, Error>?

    private init() {}

    // MARK: - Session (Keychain)

    nonisolated func currentSession() -> OwnerSession? {
        guard let data = KeychainStore.load(account: Self.sessionAccount) else { return nil }
        return try? Self.makeDecoder().decode(OwnerSession.self, from: data)
    }

    /// Local only. Use `signOutEverywhere()` to also revoke the refresh token.
    nonisolated func signOut() {
        _ = KeychainStore.deleteIncludingStaging(account: Self.sessionAccount)
    }

    /// Best-effort server revoke, then drop the Keychain session either way.
    func signOutEverywhere() async {
        if let session = currentSession() {
            _ = try? await request(
                path: "/auth/v1/logout?scope=local",
                method: "POST",
                body: nil,
                session: session,
                profile: nil
            )
        }
        dropSession()
    }

    /// Lost-phone path: revokes every refresh token on the account, then drops
    /// this iPhone's session. Throws (and keeps the session so the owner can
    /// retry) unless the server confirms. Access tokens already issued
    /// elsewhere lapse on their own expiry.
    func signOutAllDevices() async throws {
        let session = try await validSession()
        let (_, response) = try await request(
            path: "/auth/v1/logout?scope=global",
            method: "POST",
            body: nil,
            session: session,
            profile: nil
        )
        try Self.requireOK(response)
        dropSession()
    }

    private func dropSession() {
        refreshTask?.cancel()
        refreshTask = nil
        signOut()
    }

    // MARK: - Email one-time code

    func sendEmailCode(to email: String) async throws {
        struct OTPBody: Encodable {
            let email: String
            let createUser: Bool
            enum CodingKeys: String, CodingKey {
                case email
                case createUser = "create_user"
            }
        }
        let body = try Self.makeEncoder().encode(OTPBody(email: email, createUser: true))
        let (_, response) = try await request(
            path: "/auth/v1/otp",
            method: "POST",
            body: body,
            session: nil,
            profile: nil
        )
        try Self.requireOK(response)
    }

    func verifyEmailCode(email: String, token: String) async throws {
        let payload: [String: String] = ["email": email, "token": token, "type": "email"]
        let body = try Self.makeEncoder().encode(payload)
        let (data, response) = try await request(
            path: "/auth/v1/verify",
            method: "POST",
            body: body,
            session: nil,
            profile: nil
        )
        try Self.requireOK(response)
        let auth = try Self.makeDecoder().decode(AuthTokenResponse.self, from: data)
        try store(auth.session(fallbackEmail: email))
    }

    // MARK: - profiles

    /// Upsert and return the row the server stored (with its `updated_at`).
    @discardableResult
    func push(_ record: OwnerProfileRecord) async throws -> OwnerProfileRecord? {
        let session = try await validSession()
        let body = try Self.makeEncoder().encode(record.forUpsert(userId: session.userId))
        let (data, response) = try await request(
            path: "/rest/v1/profiles?on_conflict=id",
            method: "POST",
            body: body,
            session: session,
            profile: "redmed_owner",
            extra: ["Prefer": "resolution=merge-duplicates,return=representation"]
        )
        try Self.requireOK(response)
        return try? Self.makeDecoder().decode([OwnerProfileRecord].self, from: data).first
    }

    func pull() async throws -> OwnerProfileRecord? {
        let session = try await validSession()
        let (data, response) = try await request(
            path: "/rest/v1/profiles?select=*&id=eq.\(session.userId)",
            method: "GET",
            body: nil,
            session: session,
            profile: "redmed_owner"
        )
        try Self.requireOK(response)
        return try Self.makeDecoder().decode([OwnerProfileRecord].self, from: data).first
    }

    func deleteAccountCopy() async throws {
        let session = try await validSession()
        // Sequential on purpose: a failed band_writes delete stops before the
        // profile row, never leaving a cancelled-in-flight half erase.
        for path in [
            "/rest/v1/band_writes?user_id=eq.\(session.userId)",
            "/rest/v1/profiles?id=eq.\(session.userId)",
        ] {
            let (_, response) = try await request(
                path: path,
                method: "DELETE",
                body: nil,
                session: session,
                profile: "redmed_owner"
            )
            try Self.requireOK(response)
        }
    }

    /// Deletes the sign-in itself (`redmed_owner.delete_my_account`). The
    /// account copy and band-write log cascade on the server. Drops the local
    /// session only after the server confirms.
    func deleteAccount() async throws {
        let session = try await validSession()
        let (_, response) = try await request(
            path: "/rest/v1/rpc/delete_my_account",
            method: "POST",
            body: Data("{}".utf8),
            session: session,
            profile: "redmed_owner"
        )
        try Self.requireOK(response)
        dropSession()
    }

    // MARK: - band_writes

    /// Records a verified band write. `url` is hashed here and not uploaded.
    func recordVerifiedWrite(url: String, byteLength: Int) async throws {
        guard AppConfig.OwnerBandURI.isValidWriteURL(url) else { return }
        guard byteLength >= 1, byteLength <= 850 else { return }
        let session = try await validSession()
        let digest = SHA256.hash(data: Data(url.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        struct BandWriteBody: Encodable {
            let userId: String
            let codecVersion: Int
            let packedUrlSha256: String
            let byteLength: Int
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case codecVersion = "codec_version"
                case packedUrlSha256 = "packed_url_sha256"
                case byteLength = "byte_length"
            }
        }
        let body = try Self.makeEncoder().encode(BandWriteBody(
            userId: session.userId,
            codecVersion: 2,
            packedUrlSha256: hex,
            byteLength: byteLength
        ))
        let (_, response) = try await request(
            path: "/rest/v1/band_writes",
            method: "POST",
            body: body,
            session: session,
            profile: "redmed_owner",
            extra: ["Prefer": "return=minimal"]
        )
        try Self.requireOK(response)
    }

    // MARK: - Private

    private func validSession() async throws -> OwnerSession {
        guard let session = currentSession() else { throw OwnerSyncError.signedOut }
        if session.expiresAt.timeIntervalSinceNow > 60 { return session }
        // Single-flight: Supabase rotates refresh tokens, so a second refresh
        // with the same token can revoke the session family.
        if let inFlight = refreshTask {
            return try await inFlight.value
        }
        let task = Task { try await self.refresh(session) }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func refresh(_ session: OwnerSession) async throws -> OwnerSession {
        let body = try Self.makeEncoder().encode(["refresh_token": session.refreshToken])
        let (data, response) = try await request(
            path: "/auth/v1/token?grant_type=refresh_token",
            method: "POST",
            body: body,
            session: nil,
            profile: nil
        )
        if (400...499).contains(response.statusCode), !Self.refreshRetryableStatuses.contains(response.statusCode) {
            // Any client error other than a rate limit means the refresh
            // token itself is rejected (400 invalid_grant / 401 / 403 / and
            // any other 4xx GoTrue may return for a dead token).
            // 408 / 429 rate limits, 5xx and network drops keep the session
            // for the next try — they say nothing about the token.
            signOut()
            throw OwnerSyncError.signedOut
        }
        try Self.requireOK(response)
        let auth = try Self.makeDecoder().decode(AuthTokenResponse.self, from: data)
        let next = auth.session(fallbackEmail: session.email)
        try store(next)
        return next
    }

    /// Auth answers that say nothing about the token itself — keep the session and retry later.
    private static let refreshRetryableStatuses: Set<Int> = [408, 429]

    private func store(_ session: OwnerSession) throws {
        guard let stored = try? Self.makeEncoder().encode(session),
              KeychainStore.save(stored, account: Self.sessionAccount) else {
            throw OwnerSyncError.keychain
        }
    }

    private func request(
        path: String,
        method: String,
        body: Data?,
        session: OwnerSession?,
        profile: String?,
        extra: [String: String] = [:]
    ) async throws -> (Data, HTTPURLResponse) {
        guard let base = SupabaseConfig.projectURL else { throw OwnerSyncError.notConfigured }
        guard let url = URL(string: path, relativeTo: base) else { throw OwnerSyncError.notConfigured }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpBody = body
        let key = SupabaseConfig.publishableKey
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        if let session {
            req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        if let profile {
            // PostgREST: Accept-Profile for reads, Content-Profile for writes.
            let header = method == "GET" || method == "HEAD" ? "Accept-Profile" : "Content-Profile"
            req.setValue(profile, forHTTPHeaderField: header)
        }
        for (name, value) in extra {
            req.setValue(value, forHTTPHeaderField: name)
        }
        do {
            let (data, response) = try await http.data(for: req)
            guard let httpResponse = response as? HTTPURLResponse else { throw OwnerSyncError.http(-1) }
            return (data, httpResponse)
        } catch let error as URLError {
            throw OwnerSyncError.offline(error.code)
        }
    }

    private static func requireOK(_ response: HTTPURLResponse) throws {
        guard (200..<300).contains(response.statusCode) else {
            throw OwnerSyncError.http(response.statusCode)
        }
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

enum OwnerSyncError: Error, Equatable {
    case notConfigured
    case signedOut
    case keychain
    case offline(URLError.Code)
    case http(Int)

    /// Short owner-facing line. No server body, no PHI.
    var ownerMessage: String {
        switch self {
        case .notConfigured: return "Sync isn't set up in this build."
        case .signedOut: return "Signed out. Sign in again to sync."
        case .keychain: return "Couldn't save the sign-in to Keychain."
        case .offline: return "Offline. RedMed will retry."
        case .http(let code) where code == 401 || code == 403: return "The account refused this request (\(code))."
        case .http(let code) where code == 429: return "Too many tries. Wait a minute."
        case .http(let code) where code >= 500: return "The account server had a problem (\(code)). RedMed will retry."
        case .http(let code): return "Sync failed (\(code))."
        }
    }
}

private struct AuthTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: AuthUser

    struct AuthUser: Decodable {
        let id: String
        let email: String?
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }

    func session(fallbackEmail: String?) -> OwnerSession {
        OwnerSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userId: user.id,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn)),
            email: user.email ?? fallbackEmail
        )
    }
}
