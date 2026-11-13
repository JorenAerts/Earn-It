import Foundation

/// What the user currently has access to.
public enum EntitlementState: Codable, Hashable, Sendable {
    /// No active purchase: freemium limits.
    case free
    /// In the App Store free-trial period of a subscription (renews into a paid period).
    case trial(renewsAt: Date?)
    /// Paid. `expiresAt == nil` means lifetime.
    case pro(expiresAt: Date?)

    public var isPro: Bool {
        switch self {
        case .free: false
        case .trial, .pro: true
        }
    }

    public var isLifetime: Bool { self == .pro(expiresAt: nil) }
}

/// The parts of a StoreKit transaction the entitlement logic needs (testable without StoreKit).
public struct TransactionInfo: Hashable, Sendable {
    public let productID: String
    public let expiresAt: Date?
    public let isTrial: Bool
    public let isRevoked: Bool

    public init(productID: String, expiresAt: Date?, isTrial: Bool = false, isRevoked: Bool = false) {
        self.productID = productID
        self.expiresAt = expiresAt
        self.isTrial = isTrial
        self.isRevoked = isRevoked
    }
}

public enum EntitlementResolver {
    /// Best entitlement among the user's current transactions:
    /// lifetime > paid subscription (latest expiry) > trial > free.
    public static func resolve(_ transactions: [TransactionInfo], now: Date) -> EntitlementState {
        let active = transactions.filter { !$0.isRevoked && ($0.expiresAt.map { $0 > now } ?? true) }
        if active.contains(where: { $0.expiresAt == nil }) { return .pro(expiresAt: nil) }
        if let paid = active.filter({ !$0.isTrial }).compactMap(\.expiresAt).max() {
            return .pro(expiresAt: paid)
        }
        if let trial = active.filter(\.isTrial).compactMap(\.expiresAt).max() {
            return .trial(renewsAt: trial)
        }
        return .free
    }
}

/// Last known entitlement, so the right tier shows instantly at launch / offline.
public final class EntitlementCache: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "earnit.entitlement"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> EntitlementState {
        guard let data = defaults.data(forKey: key),
              let state = try? JSONDecoder().decode(EntitlementState.self, from: data)
        else { return .free }
        return state
    }

    public func save(_ state: EntitlementState) {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: key) }
    }
}
