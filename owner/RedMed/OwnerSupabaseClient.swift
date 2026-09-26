import CryptoKit
import Foundation

/// Publishable Supabase client for the signed-in wearer copy.
/// The key is read from Info.plist (`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`).
/// Neither value is committed. `service_role` is never used.
/// The public tap page does not use this client.
enum SupabaseConfig {
    static var projectURL: URL? {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard raw.hasPrefix("https://"), let url = URL(string: raw) else { return nil }
        return url
    }

    static var publishableKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var isConfigured: Bool {
        projectURL != nil && !publishableKey.isEmpty
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
}

struct OwnerSession: Codable, Equatable, Sendable {
    var accessToken: String
    var refreshToken: String
    var userId: String
    var expiresAt: Date
}

/// Auth + PostgREST for `redmed_owner`. Network only. No `#d=` string is sent.
final class OwnerSupabaseClient {
    static let shared = OwnerSupabaseClient()

    private let sessionAccount = "supabase.session.v1"
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private init() {}

    func currentSession() -> OwnerSession? {
        guard let data = KeychainStore.load(account: sessionAccount),
              let session = try? decoder.decode(OwnerSession.self, from: data) else {
            return nil
        }
        return session
    }

    func signOut() {
        _ = KeychainStore.deleteIncludingStaging(account: sessionAccount)
    }

    func sendEmailCode(to email: String) async throws {
        struct OTPBody: Encodable {
            let email: String
            let createUser: Bool
            enum CodingKeys: String, CodingKey {
                case email
                case createUser = "create_user"
            }
        }
        let body = try encoder.encode(OTPBody(email: email, createUser: true))
        let (_, response) = try await request(
            path: "/auth/v1/otp",
            method: "POST",
            body: body,
            session: nil,
            profile: nil
        )
        guard (200..<300).contains(response.statusCode) else {
            throw OwnerSyncError.http(response.statusCode)
        }
    }

    func verifyEmailCode(email: String, token: String) async throws {
        let payload: [String: String] = ["email": email, "token": token, "type": "email"]
        let body = try encoder.encode(payload)
        let (data, response) = try await request(
            path: "/auth/v1/verify",
            method: "POST",
            body: body,
            session: nil,
            profile: nil
        )
        guard (200..<300).contains(response.statusCode) else {
            throw OwnerSyncError.http(response.statusCode)
        }
        let auth = try decoder.decode(AuthTokenResponse.self, from: data)
        let session = OwnerSession(
            accessToken: auth.accessToken,
            refreshToken: auth.refreshToken,
            userId: auth.user.id,
            expiresAt: Date().addingTimeInterval(TimeInterval(auth.expiresIn))
        )
        guard let stored = try? encoder.encode(session),
              KeychainStore.save(stored, account: sessionAccount) else {
            throw OwnerSyncError.keychain
        }
    }

    func push(_ record: OwnerProfileRecord) async throws {
        let session = try await validSession()
        var row = record
        row.id = session.userId
        let body = try encoder.encode(row)
        let (_, response) = try await request(
            path: "/rest/v1/profiles?on_conflict=id",
            method: "POST",
            body: body,
            session: session,
            profile: "redmed_owner",
            extra: ["Prefer": "resolution=merge-duplicates,return=representation"]
        )
        guard (200..<300).contains(response.statusCode) else {
            throw OwnerSyncError.http(response.statusCode)
        }
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
        guard (200..<300).contains(response.statusCode) else {
            throw OwnerSyncError.http(response.statusCode)
        }
        let rows = try decoder.decode([OwnerProfileRecord].self, from: data)
        return rows.first
    }

    func deleteAccountCopy() async throws {
        let session = try await validSession()
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
            guard (200..<300).contains(response.statusCode) else {
                throw OwnerSyncError.http(response.statusCode)
            }
        }
    }

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
        let body = try encoder.encode(BandWriteBody(
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
        guard (200..<300).contains(response.statusCode) else {
            throw OwnerSyncError.http(response.statusCode)
        }
    }

    // MARK: - Private

    private func validSession() async throws -> OwnerSession {
        guard var session = currentSession() else { throw OwnerSyncError.signedOut }
        if session.expiresAt.timeIntervalSinceNow > 60 { return session }
        let body = try encoder.encode(["refresh_token": session.refreshToken])
        let (data, response) = try await request(
            path: "/auth/v1/token?grant_type=refresh_token",
            method: "POST",
            body: body,
            session: nil,
            profile: nil
        )
        guard (200..<300).contains(response.statusCode) else {
            signOut()
            throw OwnerSyncError.signedOut
        }
        let auth = try decoder.decode(AuthTokenResponse.self, from: data)
        session = OwnerSession(
            accessToken: auth.accessToken,
            refreshToken: auth.refreshToken,
            userId: auth.user.id,
            expiresAt: Date().addingTimeInterval(TimeInterval(auth.expiresIn))
        )
        guard let stored = try? encoder.encode(session),
              KeychainStore.save(stored, account: sessionAccount) else {
            throw OwnerSyncError.keychain
        }
        return session
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
        if let session {
            req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        if let profile {
            let header = method == "GET" || method == "HEAD" ? "Accept-Profile" : "Content-Profile"
            req.setValue(profile, forHTTPHeaderField: header)
            if method == "GET" {
                req.setValue(profile, forHTTPHeaderField: "Accept-Profile")
            }
        }
        for (name, value) in extra {
            req.setValue(value, forHTTPHeaderField: name)
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw OwnerSyncError.http(-1) }
        return (data, http)
    }
}

enum OwnerSyncError: Error {
    case notConfigured
    case signedOut
    case keychain
    case http(Int)
}

private struct AuthTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: AuthUser

    struct AuthUser: Decodable {
        let id: String
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }
}
