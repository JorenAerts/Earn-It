import Foundation
import Localization
import Purchases

/// What "Restore purchases" tells the user: which purchase was found, and — for TestFlight test
/// purchases — how to get back to the free plan (restoring finds the test purchase again).
enum RestoreMessage {
    static func text(purchases: [ActivePurchase], catalog: PricingCatalog) -> String {
        guard let best = ActivePurchase.best(purchases) else {
            return L10n.tr("No purchases found for this Apple ID.")
        }
        let plan = catalog.plan(id: best.productID)?.title ?? best.productID
        var text: String
        if let expires = best.expiresAt {
            text = L10n.tr("Purchases restored: \(plan), renews \(expires.localized(.dateTime.day().month(.abbreviated))).")
        } else {
            text = L10n.tr("Purchases restored: \(plan), yours for good.")
        }
        if best.isSandbox {
            text += " " + L10n.tr("This is a TestFlight test purchase. To try the free plan, turn on “Test as Free plan” above.")
        }
        return text
    }
}
