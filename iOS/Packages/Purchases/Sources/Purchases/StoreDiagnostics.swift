import Foundation

/// What StoreKit reports right now (Developer tools › Store diagnostics). Prices and currency come
/// from App Store Connect for the App Store country of the Apple Account on this device.
public struct StoreDiagnostics: Sendable, Equatable {
    public struct ProductLine: Sendable, Equatable {
        public let id: String
        public let displayPrice: String
        public let price: Decimal
        public let currency: String
        /// "P1Y"-style description, nil for lifetime.
        public let period: String?
        public let introOffer: String?

        public init(id: String, displayPrice: String, price: Decimal, currency: String, period: String?, introOffer: String?) {
            self.id = id
            self.displayPrice = displayPrice
            self.price = price
            self.currency = currency
            self.period = period
            self.introOffer = introOffer
        }
    }

    public let storefront: String
    public let products: [ProductLine]
    public let purchases: [ActivePurchase]
    public let trialEligible: Bool

    public init(storefront: String, products: [ProductLine], purchases: [ActivePurchase], trialEligible: Bool) {
        self.storefront = storefront
        self.products = products
        self.purchases = purchases
        self.trialEligible = trialEligible
    }

    /// Lifetime should cost more than a year; equal or less is almost always a pricing mistake.
    public var pricingWarning: String? {
        guard let lifetime = products.first(where: { $0.id.hasSuffix(".lifetime") }),
              let yearly = products.first(where: { $0.id.hasSuffix(".yearly") }),
              lifetime.price <= yearly.price else { return nil }
        return "Lifetime (\(lifetime.displayPrice)) is not more expensive than Yearly (\(yearly.displayPrice)). Check the prices in App Store Connect."
    }

    /// Plain text to copy and share.
    public var text: String {
        var lines = ["Storefront: \(storefront)", "Trial eligible: \(trialEligible ? "yes" : "no")", "", "Products:"]
        lines += products.isEmpty ? ["  (none loaded)"] : products.map {
            "  \($0.id): \($0.displayPrice) [\($0.price) \($0.currency)]" + ($0.period.map { " / \($0)" } ?? "") + ($0.introOffer.map { ", intro: \($0)" } ?? "")
        }
        lines += ["", "Active purchases:"]
        let iso = ISO8601DateFormatter()
        lines += purchases.isEmpty ? ["  (none)"] : purchases.map {
            "  \($0.productID): bought \(iso.string(from: $0.purchasedAt)), " + ($0.expiresAt.map { "expires \(iso.string(from: $0))" } ?? "lifetime")
                + ($0.isTrial ? ", trial" : "") + ($0.isSandbox ? ", sandbox/TestFlight" : "")
        }
        if let pricingWarning { lines += ["", "⚠️ \(pricingWarning)"] }
        return lines.joined(separator: "\n")
    }
}
