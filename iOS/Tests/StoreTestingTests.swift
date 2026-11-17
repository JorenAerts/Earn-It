import Foundation
@testable import Features
import Localization
import Purchases
import Testing

/// TestFlight testing help: free-plan switch, restore message, store diagnostics.
@Suite struct StoreTestingTests {
    private let catalog = try! PricingCatalog.load()

    @Test func forceFreeOverridesOnlyWhenOn() {
        let pro = EntitlementState.pro(expiresAt: nil)
        #expect(EntitlementOverride.apply(pro, forceFree: true) == .free)
        #expect(EntitlementOverride.apply(pro, forceFree: false) == pro)
        #expect(EntitlementOverride.apply(.trial(renewsAt: nil), forceFree: true) == .free)
        #expect(EntitlementOverride.apply(pro, forceFree: true, onlyTestPurchases: false) == pro, "a real purchase is never hidden")
    }

    @Test func bestPurchasePrefersLifetimeThenLatestExpiry() {
        let now = Date()
        let weekly = ActivePurchase(productID: "be.gloop.app.pro.weekly", purchasedAt: now, expiresAt: now.addingTimeInterval(600))
        let yearly = ActivePurchase(productID: "be.gloop.app.pro.yearly", purchasedAt: now, expiresAt: now.addingTimeInterval(3600))
        let lifetime = ActivePurchase(productID: "be.gloop.app.pro.lifetime", purchasedAt: now, expiresAt: nil)
        #expect(ActivePurchase.best([weekly, yearly]) == yearly)
        #expect(ActivePurchase.best([weekly, lifetime, yearly]) == lifetime)
        #expect(ActivePurchase.best([]) == nil)
    }

    @Test func restoreMessageNamesThePurchaseAndExplainsTestFlight() {
        L10n.$override.withValue("en") {
            #expect(RestoreMessage.text(purchases: [], catalog: catalog) == "No purchases found for this Apple ID.")
            let lifetime = ActivePurchase(productID: "be.gloop.app.pro.lifetime", purchasedAt: .now, expiresAt: nil)
            #expect(RestoreMessage.text(purchases: [lifetime], catalog: catalog) == "Purchases restored: Lifetime, yours for good.")
            let sandbox = ActivePurchase(productID: "be.gloop.app.pro.yearly", purchasedAt: .now,
                                         expiresAt: .now.addingTimeInterval(86_400), isSandbox: true)
            let text = RestoreMessage.text(purchases: [sandbox], catalog: catalog)
            #expect(text.hasPrefix("Purchases restored: Yearly, renews "))
            #expect(text.contains("TestFlight test purchase") && text.contains("Test as Free plan"))
        }
    }

    @Test func diagnosticsFlagLifetimeNotAboveYearly() {
        func line(_ id: String, _ price: Decimal) -> StoreDiagnostics.ProductLine {
            .init(id: "be.gloop.app.pro.\(id)", displayPrice: "$\(price)", price: price, currency: "USD", period: nil, introOffer: nil)
        }
        let same = StoreDiagnostics(storefront: "USA", products: [line("yearly", 49.99), line("lifetime", 49.99)], purchases: [], trialEligible: true)
        #expect(same.pricingWarning != nil)
        #expect(same.text.contains("Storefront: USA") && same.text.contains("⚠️"))
        let fine = StoreDiagnostics(storefront: "BEL", products: [line("yearly", 29.99), line("lifetime", 59.99)], purchases: [], trialEligible: true)
        #expect(fine.pricingWarning == nil)
    }
}
