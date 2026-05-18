import Foundation

// Supabase anonymous-auth client. Provides each install with a stable
// authenticated user JWT (issued by Supabase GoTrue) so server-side functions
// can identify the user without trusting client-supplied identifiers.
//
// Tokens persist in Keychain; refresh happens transparently on access. First
// call performs an anonymous /signup; subsequent calls reuse and refresh.
//
// Project-side requirement: anonymous sign-in must be enabled in the Supabase
// dashboard (Authentication → Providers → Anonymous, or
// `[auth] enable_anonymous_sign_ins = true` in supabase/config.toml).

@MainActor
final class SupabaseAuth {
    static let shared = SupabaseAuth()

    // Public anon key — embedded by design (it's a public JWT for the anon role).
    private let supabaseURL = "https://rvdzakkvggqxqrrvtfiq.supabase.co"
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ2ZHpha2t2Z2dxeHFycnZ0ZmlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc4MTk2NzYsImV4cCI6MjA5MzM5NTY3Nn0.eZlJis8p-o4LtD9i7-GGjuV9AE86ZzWseGmjWaOCZlY"

    private static let keychainKey = "supabase_session_v1"
    private let refreshLeeway: TimeInterval = 300 // refresh when <5 min remaining

    private var session: Session?
    private var inflight: Task<Session, Error>?

    private init() {
        if let data = Keychain.getData(Self.keychainKey),
           let s = try? JSONDecoder().decode(Session.self, from: data) {
            session = s
        }
    }

    var currentUserID: String? { session?.userID }

    func ensureUserID() async throws -> String {
        try await ensureSession().userID
    }

    func currentAccessToken() async throws -> String {
        try await ensureSession().accessToken
    }

    private func ensureSession() async throws -> Session {
        if let s = session, !Self.needsRefresh(s, leeway: refreshLeeway) {
            return s
        }
        if let task = inflight { return try await task.value }
        let url = supabaseURL
        let key = anonKey
        let existing = session
        let task = Task<Session, Error> { [weak self] in
            if let existing {
                if let refreshed = try? await Self.refresh(url: url, anonKey: key, refreshToken: existing.refreshToken) {
                    self?.persist(refreshed)
                    return refreshed
                }
            }
            let fresh = try await Self.signUpAnonymously(url: url, anonKey: key)
            self?.persist(fresh)
            return fresh
        }
        inflight = task
        defer { inflight = nil }
        return try await task.value
    }

    private func persist(_ s: Session) {
        session = s
        if let data = try? JSONEncoder().encode(s) {
            Keychain.setData(data, key: Self.keychainKey)
        }
    }

    private static func needsRefresh(_ s: Session, leeway: TimeInterval) -> Bool {
        s.expiresAt <= Date().timeIntervalSince1970 + leeway
    }

    // MARK: - Network

    // MARK: - Sign out / Delete account

    /// Clears the in-memory session and removes the persisted token from
    /// Keychain. Next call to `ensureSession()` will create a fresh anonymous
    /// account.
    func signOut() {
        session = nil
        inflight?.cancel()
        inflight = nil
        Keychain.delete(Self.keychainKey)
    }

    /// Deletes the calling user's Supabase auth account server-side via the
    /// `delete-account` Edge Function (which holds the service role key).
    /// On success, also signs out locally. Throws on network or server error;
    /// callers are responsible for surfacing failure to the user.
    func deleteAccount() async throws {
        let token = try await currentAccessToken()
        guard let endpoint = URL(string: "\(supabaseURL)/functions/v1/delete-account") else {
            throw SupabaseAuthError.invalidURL
        }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [String: String]())

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseAuthError.requestFailed(body)
        }
        signOut()
    }

    /// Mirrors the user's StoreKit-derived subscription tier into the server
    /// `subscriptions` table so the rate-limit helper in cyrano/eleven/
    /// livekit-token applies the right per-tier limits. Called from
    /// `StoreManager.checkEntitlements()` after every entitlement change
    /// (purchase, restore, transaction-listener update, app launch).
    /// `tier` must be one of "free" or "pro".
    func setTier(_ tier: String) async throws {
        let token = try await currentAccessToken()
        guard let endpoint = URL(string: "\(supabaseURL)/functions/v1/set-tier") else {
            throw SupabaseAuthError.invalidURL
        }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["tier": tier])
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw SupabaseAuthError.requestFailed("setTier failed")
        }
    }

    private static func signUpAnonymously(url: String, anonKey: String) async throws -> Session {
        guard let endpoint = URL(string: "\(url)/auth/v1/signup") else { throw SupabaseAuthError.invalidURL }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["data": [String: String]()])
        return try await execute(req: req)
    }

    private static func refresh(url: String, anonKey: String, refreshToken: String) async throws -> Session {
        guard let endpoint = URL(string: "\(url)/auth/v1/token?grant_type=refresh_token") else { throw SupabaseAuthError.invalidURL }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])
        return try await execute(req: req)
    }

    private static func execute(req: URLRequest) async throws -> Session {
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseAuthError.requestFailed(body)
        }
        let parsed = try JSONDecoder().decode(AuthResponse.self, from: data)
        let exp: TimeInterval
        if let at = parsed.expires_at { exp = at }
        else if let inSec = parsed.expires_in { exp = Date().timeIntervalSince1970 + inSec }
        else { exp = Date().timeIntervalSince1970 + 3600 }
        return Session(
            accessToken: parsed.access_token,
            refreshToken: parsed.refresh_token,
            expiresAt: exp,
            userID: parsed.user.id
        )
    }

    // MARK: - Wire types

    private struct Session: Codable {
        let accessToken: String
        let refreshToken: String
        let expiresAt: TimeInterval
        let userID: String
    }

    private struct AuthResponse: Decodable {
        let access_token: String
        let refresh_token: String
        let expires_at: TimeInterval?
        let expires_in: TimeInterval?
        let user: AuthUser
    }

    private struct AuthUser: Decodable {
        let id: String
    }
}

enum SupabaseAuthError: LocalizedError {
    case invalidURL
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid auth URL"
        case .requestFailed(let body): return "Auth request failed: \(body)"
        }
    }
}
