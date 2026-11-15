import Foundation

/// Login providers the app can show. Which ones appear (and in what order) comes from
/// `Config/Auth.json`; each must also be enabled in the Supabase dashboard.
public enum AuthProvider: String, Codable, CaseIterable, Sendable, Identifiable {
    case apple, google, facebook, microsoft

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .apple: "Apple"
        case .google: "Google"
        case .facebook: "Facebook"
        case .microsoft: "Microsoft"
        }
    }

    /// SF Symbol fallback icon (brand logos would need their own assets).
    public var symbolName: String {
        switch self {
        case .apple: "apple.logo"
        case .google: "g.circle.fill"
        case .facebook: "f.circle.fill"
        case .microsoft: "square.grid.2x2.fill"
        }
    }
}

/// `Config/Auth.json`.
public struct AuthConfig: Codable, Sendable, Equatable {
    public let emailPassword: Bool
    public let providers: [AuthProvider]
    public let redirectURL: URL
    public let termsURL: URL
    public let privacyURL: URL
    /// Help & feedback › Contact support. Optional: hidden when missing.
    public let supportEmail: String?
    /// Help & feedback › Share Earn It (website / App Store page).
    public let shareURL: URL?

    public static func load(from bundle: Bundle = .main) -> AuthConfig {
        guard let url = bundle.url(forResource: "Auth", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(AuthConfig.self, from: data)
        else { return .fallback }
        return config
    }

    public static let fallback = AuthConfig(
        emailPassword: true, providers: [.apple, .google],
        redirectURL: URL(string: "earnit://auth-callback")!,
        termsURL: URL(string: "https://example.com/terms")!,
        privacyURL: URL(string: "https://example.com/privacy")!
    )

    public init(emailPassword: Bool, providers: [AuthProvider], redirectURL: URL, termsURL: URL, privacyURL: URL,
                supportEmail: String? = nil, shareURL: URL? = nil) {
        self.emailPassword = emailPassword
        self.providers = providers
        self.redirectURL = redirectURL
        self.termsURL = termsURL
        self.privacyURL = privacyURL
        self.supportEmail = supportEmail
        self.shareURL = shareURL
    }

    private enum CodingKeys: String, CodingKey {
        case emailPassword, providers, redirectURL, termsURL, privacyURL, supportEmail, shareURL
    }

    /// Unknown provider names in the JSON are ignored instead of breaking login.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        emailPassword = try c.decodeIfPresent(Bool.self, forKey: .emailPassword) ?? true
        let names = try c.decodeIfPresent([String].self, forKey: .providers) ?? []
        providers = names.compactMap(AuthProvider.init(rawValue:))
        redirectURL = try c.decode(URL.self, forKey: .redirectURL)
        termsURL = try c.decode(URL.self, forKey: .termsURL)
        privacyURL = try c.decode(URL.self, forKey: .privacyURL)
        let email = try c.decodeIfPresent(String.self, forKey: .supportEmail)?.trimmingCharacters(in: .whitespaces)
        supportEmail = (email?.isEmpty ?? true) ? nil : email
        shareURL = try c.decodeIfPresent(URL.self, forKey: .shareURL)
    }
}

public struct AccountUser: Equatable, Sendable {
    public let id: UUID
    public let email: String?
    /// How the account signs in: "email", "apple", "google", "azure", … (Supabase app metadata).
    public let provider: String?

    public init(id: UUID, email: String?, provider: String? = nil) {
        self.id = id
        self.email = email
        self.provider = provider
    }

    /// "Email", "Apple", "Microsoft", …
    public var providerName: String? {
        guard let provider else { return nil }
        if provider == "email" { return "Email & password" }
        if provider == "azure" { return AuthProvider.microsoft.displayName }
        return AuthProvider(rawValue: provider)?.displayName ?? provider.capitalized
    }

    public var usesPassword: Bool { provider == "email" }
}

/// Profile fields synced to the `profiles` table when signed in.
public struct ProfileUpdate: Codable, Equatable, Sendable {
    public var displayName: String?
    public var wakeGoal: WakeGoal?
    /// Onboarding answers for insight (age range, where they heard of us, …). Stored as jsonb.
    public var onboarding: [String: String]?

    public struct WakeGoal: Codable, Equatable, Sendable {
        public var hour: Int
        public var minute: Int
        public var weekdays: [Int]
        public var struggles: [String]

        public init(hour: Int, minute: Int, weekdays: [Int], struggles: [String]) {
            self.hour = hour
            self.minute = minute
            self.weekdays = weekdays
            self.struggles = struggles
        }
    }

    public init(displayName: String? = nil, wakeGoal: WakeGoal? = nil, onboarding: [String: String]? = nil) {
        self.displayName = displayName
        self.wakeGoal = wakeGoal
        self.onboarding = onboarding
    }
}

public enum AuthError: LocalizedError, Equatable {
    case notConfigured
    case confirmEmail
    case message(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured: "Accounts aren't available in this build."
        case .confirmEmail: "Check your inbox to confirm your email, then sign in."
        case .message(let text): text
        }
    }
}

/// Optional account. The app works fully without one.
@MainActor
public protocol AuthService: AnyObject {
    /// False when no Supabase config is present: sign-in UI is hidden.
    var isAvailable: Bool { get }
    var user: AccountUser? { get }
    var config: AuthConfig { get }
    /// Providers from Auth.json that are actually enabled on the server (others are hidden).
    var availableProviders: [AuthProvider] { get }

    func signUp(email: String, password: String) async throws
    func signIn(email: String, password: String) async throws
    func resetPassword(email: String) async throws
    func signIn(with provider: AuthProvider) async throws
    func signOut() async
    /// Permanently deletes the account (App Review 5.1.1(v)).
    func deleteAccount() async throws
    func updateProfile(_ update: ProfileUpdate) async
    /// The signed-in user's profile row (nil when signed out or offline).
    func loadProfile() async -> ProfileUpdate?
    /// Email confirmation / OAuth callback deep links (`earnit://auth-callback…`).
    func handle(url: URL) async
}
