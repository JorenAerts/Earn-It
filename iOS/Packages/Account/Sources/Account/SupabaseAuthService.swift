import Foundation
import Localization
import Observation
import Supabase
import os

private let log = Logger(subsystem: "be.gloop.app", category: "account")

/// Supabase Auth: email + password and OAuth providers (Apple, Google, Facebook, Microsoft)
/// through one SDK. OAuth runs in an ASWebAuthenticationSession and returns via
/// `gloop://auth-callback`. Sessions are persisted in the Keychain by the SDK.
@MainActor
@Observable
public final class SupabaseAuthService: AuthService {
    public let config: AuthConfig
    public private(set) var user: AccountUser?
    public private(set) var availableProviders: [AuthProvider] = []
    public var isAvailable: Bool { true }

    /// Shared with other Supabase features (Buddies) so they use the signed-in session.
    @ObservationIgnored public let client: SupabaseClient
    @ObservationIgnored private var listener: Task<Void, Never>?

    public init(url: URL, publishableKey: String, config: AuthConfig) {
        self.config = config
        self.client = SupabaseClient(supabaseURL: url, supabaseKey: publishableKey)
        listener = Task { [weak self] in
            guard let changes = self?.client.auth.authStateChanges else { return }
            for await change in changes {
                self?.user = change.session.map { Self.map($0.user) }
            }
        }
        Task { [weak self] in
            await self?.loadEnabledProviders(url: url, key: publishableKey)
        }
    }

    /// `client.auth.session` refreshes an expired session before returning it.
    public func currentAccessToken() async -> String? {
        guard user != nil else { return nil }
        return try? await client.auth.session.accessToken
    }

    /// GET /auth/v1/settings → which OAuth providers are switched on in the dashboard.
    private func loadEnabledProviders(url: URL, key: String) async {
        struct Settings: Decodable { let external: [String: Bool] }
        var request = URLRequest(url: url.appending(path: "auth/v1/settings"))
        request.setValue(key, forHTTPHeaderField: "apikey")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let settings = try? JSONDecoder().decode(Settings.self, from: data)
        else { return }
        availableProviders = Self.filter(config.providers, enabled: settings.external)
    }

    /// Keeps Auth.json order; Microsoft is called "azure" by Supabase.
    public nonisolated static func filter(_ providers: [AuthProvider], enabled: [String: Bool]) -> [AuthProvider] {
        providers.filter { enabled[$0 == .microsoft ? "azure" : $0.rawValue] == true }
    }

    public func signUp(email: String, password: String) async throws {
        do {
            let response = try await client.auth.signUp(email: email, password: password,
                                                        redirectTo: config.redirectURL)
            if response.session == nil { throw AuthError.confirmEmail }
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.message(error.localizedDescription)
        }
    }

    public func signIn(email: String, password: String) async throws {
        do {
            _ = try await client.auth.signIn(email: email, password: password)
        } catch {
            throw AuthError.message(error.localizedDescription)
        }
    }

    public func resetPassword(email: String) async throws {
        do {
            try await client.auth.resetPasswordForEmail(email, redirectTo: config.redirectURL)
        } catch {
            throw AuthError.message(error.localizedDescription)
        }
    }

    public func signIn(with provider: AuthProvider) async throws {
        do {
            _ = try await client.auth.signInWithOAuth(provider: Self.map(provider), redirectTo: config.redirectURL)
        } catch {
            throw AuthError.message(error.localizedDescription)
        }
    }

    public func signOut() async {
        try? await client.auth.signOut()
        user = nil
    }

    public func deleteAccount() async throws {
        do {
            // Postgres RPC; deletes only the caller's own user (see Backend migrations).
            try await client.rpc("delete_own_account").execute()
            await signOut()
        } catch {
            throw AuthError.message(L10n.tr("Couldn't delete the account: \(error.localizedDescription)"))
        }
    }

    public func updateProfile(_ update: ProfileUpdate) async {
        guard let user else { return }
        struct Row: Encodable {
            let id: UUID
            let display_name: String?
            let wake_goal: ProfileUpdate.WakeGoal?
        }
        struct OnboardingRow: Encodable {
            let id: UUID
            let onboarding: [String: String]
        }
        do {
            try await client.from("profiles")
                .upsert(Row(id: user.id, display_name: update.displayName, wake_goal: update.wakeGoal))
                .execute()
        } catch {
            log.error("profile update failed: \(error.localizedDescription, privacy: .public)")
        }
        // Separate call: works even before the `onboarding` column migration is applied.
        if let onboarding = update.onboarding, !onboarding.isEmpty {
            do {
                try await client.from("profiles").upsert(OnboardingRow(id: user.id, onboarding: onboarding)).execute()
            } catch {
                log.notice("onboarding answers not saved (column missing?): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    public func loadProfile() async -> ProfileUpdate? {
        guard let user else { return nil }
        struct Row: Decodable {
            let display_name: String?
            let wake_goal: ProfileUpdate.WakeGoal?
        }
        do {
            let rows: [Row] = try await client.from("profiles")
                .select("display_name, wake_goal")
                .eq("id", value: user.id)
                .limit(1)
                .execute()
                .value
            return rows.first.map { ProfileUpdate(displayName: $0.display_name, wakeGoal: $0.wake_goal) }
        } catch {
            log.error("profile load failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    public func handle(url: URL) async {
        do {
            _ = try await client.auth.session(from: url)
        } catch {
            log.error("auth callback failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func map(_ user: User) -> AccountUser {
        let provider: String? = if case .string(let name)? = user.appMetadata["provider"] { name } else { nil }
        return AccountUser(id: user.id, email: user.email, provider: provider)
    }

    private static func map(_ provider: AuthProvider) -> Provider {
        switch provider {
        case .apple: .apple
        case .google: .google
        case .facebook: .facebook
        case .microsoft: .azure
        }
    }
}

/// Used when no Supabase config is present (e.g. a fresh clone): accounts are hidden.
@MainActor
@Observable
public final class UnavailableAuthService: AuthService {
    public let config: AuthConfig
    public var isAvailable: Bool { false }
    public var user: AccountUser? { nil }
    public var availableProviders: [AuthProvider] { [] }

    public init(config: AuthConfig = .fallback) { self.config = config }

    public func signUp(email: String, password: String) async throws { throw AuthError.notConfigured }
    public func signIn(email: String, password: String) async throws { throw AuthError.notConfigured }
    public func resetPassword(email: String) async throws { throw AuthError.notConfigured }
    public func signIn(with provider: AuthProvider) async throws { throw AuthError.notConfigured }
    public func signOut() async {}
    public func deleteAccount() async throws { throw AuthError.notConfigured }
    public func updateProfile(_ update: ProfileUpdate) async {}
    public func loadProfile() async -> ProfileUpdate? { nil }
    public func handle(url: URL) async {}
}

/// In-memory auth for tests and previews.
@MainActor
@Observable
public final class FakeAuthService: AuthService {
    public let config: AuthConfig
    public var isAvailable: Bool { true }
    public private(set) var user: AccountUser?
    public private(set) var profile: ProfileUpdate?
    public var failNext: AuthError?
    public var availableProviders: [AuthProvider] { config.providers }

    public init(config: AuthConfig = .fallback) { self.config = config }

    public func signUp(email: String, password: String) async throws { try sign(email) }
    public func signIn(email: String, password: String) async throws { try sign(email) }
    public func resetPassword(email: String) async throws { try check() }
    public func signIn(with provider: AuthProvider) async throws { try sign("\(provider.rawValue)@example.com") }
    public func signOut() async { user = nil }
    public func deleteAccount() async throws {
        try check()
        user = nil
        profile = nil
    }
    public func updateProfile(_ update: ProfileUpdate) async { profile = update }
    public func loadProfile() async -> ProfileUpdate? { user == nil ? nil : profile }
    public func handle(url: URL) async {}

    private func sign(_ email: String) throws {
        try check()
        user = AccountUser(id: UUID(), email: email, provider: email.hasSuffix("@example.com") ? email.components(separatedBy: "@")[0] : "email")
    }

    private func check() throws {
        if let error = failNext {
            failNext = nil
            throw error
        }
    }
}

public enum AuthServiceFactory {
    /// Reads SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY from Info.plist (filled from the
    /// git-ignored Config/Supabase.xcconfig). Refuses secret keys outright.
    @MainActor
    public static func make(bundle: Bundle = .main) -> any AuthService {
        let config = AuthConfig.load(from: bundle)
        guard let urlString = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: urlString), url.host() != nil,
              let key = bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
              isUsableClientKey(key)
        else {
            log.notice("Supabase not configured: accounts disabled")
            return UnavailableAuthService(config: config)
        }
        return SupabaseAuthService(url: url, publishableKey: key, config: config)
    }

    /// Only publishable (or legacy anon) keys may ship in the app.
    public static func isUsableClientKey(_ key: String) -> Bool {
        let key = key.trimmingCharacters(in: .whitespaces)
        return !key.isEmpty && !key.hasPrefix("sb_secret_") && !key.contains("service_role")
    }
}
