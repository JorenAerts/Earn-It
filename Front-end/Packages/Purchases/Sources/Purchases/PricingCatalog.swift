import Foundation

/// One purchasable plan from `Config/Pricing.json`.
public struct PricedProduct: Codable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case subscription, lifetime
    }

    public let key: String
    /// App Store product identifier (must match App Store Connect / EarnIt.storekit).
    public let id: String
    public let type: Kind
    /// ISO 8601 period for subscriptions ("P1W", "P1M", "P3M", "P1Y"); nil for lifetime.
    public let period: String?
    /// Reference price. The app shows StoreKit's localized price; this one feeds the
    /// local StoreKit test file and fallbacks.
    public let price: Decimal
    public let enabled: Bool
    public let badge: String?
    public let title: String

    public var isSubscription: Bool { type == .subscription }
}

/// `Config/Pricing.json` — the single place to change plans and prices.
/// After editing prices, run `python3 scripts/generate_storekit.py`.
public struct PricingCatalog: Codable, Sendable {
    public let currency: String
    public let trialDays: Int
    public let subscriptionGroup: String
    public let defaultSelection: String
    private let products: [PricedProduct]

    /// Enabled plans, in file order (the order shown on the paywall).
    public var plans: [PricedProduct] { products.filter(\.enabled) }

    public var productIDs: [String] { plans.map(\.id) }

    public func plan(id: String) -> PricedProduct? { plans.first { $0.id == id } }

    /// The preselected plan: `defaultSelection` if enabled, else the first plan.
    public var defaultPlan: PricedProduct? {
        plans.first { $0.key == defaultSelection } ?? plans.first
    }

    public static func load(from bundle: Bundle = .main) throws -> PricingCatalog {
        guard let url = bundle.url(forResource: "Pricing", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try decode(Data(contentsOf: url))
    }

    public static func decode(_ data: Data) throws -> PricingCatalog {
        try JSONDecoder().decode(PricingCatalog.self, from: data)
    }
}
