import Core
import Foundation
import Purchases
import StoreKit
import StoreKitTest
import Testing

@Suite struct PricingCatalogTests {
    @Test func bundledPricingLoadsAllFivePlansInOrder() throws {
        let catalog = try PricingCatalog.load()
        #expect(catalog.plans.map(\.key) == ["weekly", "monthly", "quarterly", "yearly", "lifetime"])
        #expect(catalog.trialDays == 3)
        #expect(catalog.defaultPlan?.key == "yearly")
    }

    @Test func disabledPlansAreHiddenAndDefaultFallsBack() throws {
        let json = #"""
        {"currency":"EUR","trialDays":3,"subscriptionGroup":"G","defaultSelection":"yearly","products":[
          {"key":"monthly","id":"m","type":"subscription","period":"P1M","price":3.99,"enabled":true,"badge":null,"title":"Monthly"},
          {"key":"yearly","id":"y","type":"subscription","period":"P1Y","price":29.99,"enabled":false,"badge":"Best","title":"Yearly"}]}
        """#
        let catalog = try PricingCatalog.decode(Data(json.utf8))
        #expect(catalog.productIDs == ["m"])
        #expect(catalog.defaultPlan?.key == "monthly")
    }

    @Test func storekitFileMatchesPricingJSON() throws {
        let catalog = try PricingCatalog.load()
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "EarnIt", withExtension: "storekit"))
        let storekit = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let subs = ((storekit["subscriptionGroups"] as? [[String: Any]])?.first?["subscriptions"] as? [[String: Any]]) ?? []
        let oneTime = (storekit["products"] as? [[String: Any]]) ?? []
        let ids = Set((subs + oneTime).compactMap { $0["productID"] as? String })
        #expect(ids == Set(catalog.productIDs), "re-run scripts/generate_storekit.py after editing Pricing.json")
    }
}

private final class BundleToken {}

@Suite struct EntitlementTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func resolvesTiers() {
        #expect(EntitlementResolver.resolve([], now: now) == .free)
        let trialEnd = now.addingTimeInterval(86_400)
        #expect(EntitlementResolver.resolve([TransactionInfo(productID: "y", expiresAt: trialEnd, isTrial: true)], now: now)
                == .trial(renewsAt: trialEnd))
        let paidEnd = now.addingTimeInterval(30 * 86_400)
        #expect(EntitlementResolver.resolve([TransactionInfo(productID: "m", expiresAt: paidEnd)], now: now)
                == .pro(expiresAt: paidEnd))
        #expect(EntitlementResolver.resolve([TransactionInfo(productID: "m", expiresAt: paidEnd),
                                             TransactionInfo(productID: "l", expiresAt: nil)], now: now)
                == .pro(expiresAt: nil))
    }

    @Test func expiredAndRevokedDontCount() {
        let past = now.addingTimeInterval(-60)
        #expect(EntitlementResolver.resolve([TransactionInfo(productID: "m", expiresAt: past)], now: now) == .free)
        #expect(EntitlementResolver.resolve([TransactionInfo(productID: "l", expiresAt: nil, isRevoked: true)], now: now) == .free)
    }

    @Test func cacheRoundTrips() {
        let cache = EntitlementCache(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        #expect(cache.load() == .free)
        cache.save(.pro(expiresAt: nil))
        #expect(cache.load() == .pro(expiresAt: nil))
    }
}

@Suite struct FeatureGateTests {
    @Test func freeTierLimits() {
        let gate = FeatureGate(isPro: false)
        #expect(gate.canAddAlarm(currentCount: 0))
        #expect(!gate.canAddAlarm(currentCount: 1))
        #expect(!gate.isLocked(MissionKind.math) && gate.isLocked(MissionKind.qr) && gate.isLocked(MissionKind.shake))
        #expect(!gate.isLocked(AlarmSound.classic) && gate.isLocked(AlarmSound.siren))
        #expect(!gate.isAllowed(AlarmPlan(sound: .chime)))
    }

    @Test func proUnlocksEverything() {
        let gate = FeatureGate(.trial(renewsAt: nil))
        #expect(gate.maxAlarms == nil && gate.canAddAlarm(currentCount: 50))
        #expect(MissionKind.allCases.allSatisfy { !gate.isLocked($0) })
        #expect(AlarmSound.allCases.allSatisfy { !gate.isLocked($0) })
    }

    @Test func downgradeKeepsFirstEnabledAlarmWorking() {
        let off = AlarmPlan(hour: 5, isEnabled: false)
        let keeper = AlarmPlan(sound: .siren, hour: 6,
                               missions: [MissionConfig(kind: .qr, payload: "x"), MissionConfig(kind: .math)],
                               isEnabled: true)
        let extra = AlarmPlan(hour: 7, isEnabled: true)
        let (plans, changes) = DowngradePolicy.apply(to: [off, keeper, extra], gate: FeatureGate(isPro: false))
        #expect(plans.count == 3, "nothing is deleted")
        #expect(plans[1].isEnabled && plans[1].missions.map(\.kind) == [.math] && plans[1].sound == .classic)
        #expect(!plans[2].isEnabled)
        #expect(changes.count == 3)
        #expect(DowngradePolicy.apply(to: plans, gate: FeatureGate(isPro: false)).changes.isEmpty, "idempotent")
    }

    @Test func downgradeReplacesOnlyLockedMissionWithMath() {
        let plan = AlarmPlan(missions: [MissionConfig(kind: .shake)], isEnabled: true)
        let (plans, _) = DowngradePolicy.apply(to: [plan], gate: FeatureGate(isPro: false))
        #expect(plans[0].missions.map(\.kind) == [.math])
    }

    @Test func proIsNeverDowngraded() {
        let plans = [AlarmPlan(sound: .siren, isEnabled: true), AlarmPlan(isEnabled: true)]
        #expect(DowngradePolicy.apply(to: plans, gate: FeatureGate(isPro: true)).changes.isEmpty)
    }
}

/// Real StoreKit flow against Config/EarnIt.storekit (local, no App Store Connect).
@Suite(.serialized) @MainActor struct StoreKitFlowTests {
    @Test func subscriptionPurchaseStartsTrial() async throws {
        let session = try SKTestSession(configurationFileNamed: "EarnIt")
        session.disableDialogs = true
        session.clearTransactions()
        session.resetToDefaultState()

        let cache = EntitlementCache(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        let store = StoreService(catalog: try PricingCatalog.load(), cache: cache)
        await store.loadProducts()
        #expect(store.products.count == 5)
        #expect(store.isEligibleForTrial)

        let yearly = try #require(store.products.first { $0.id == "be.earnit.app.pro.yearly" })
        // Subscription purchases via Product.purchase() time out inside the unit-test host;
        // buy through the test session instead (real signed transaction, same refresh path).
        _ = try await session.buyProduct(identifier: yearly.id)
        await store.refreshEntitlement()
        guard case .trial = store.entitlement else {
            Issue.record("expected trial, got \(store.entitlement)")
            return
        }
        #expect(store.gate.isPro)

        // Expiry: SKTestSession.expireSubscription doesn't update currentEntitlements' expiry in
        // the unit-test host; expiry logic is covered by EntitlementTests and checked manually via
        // Xcode › Debug › StoreKit › Manage Transactions.
        session.clearTransactions()
    }

    @Test func lifetimePurchase() async throws {
        let session = try SKTestSession(configurationFileNamed: "EarnIt")
        session.disableDialogs = true
        session.clearTransactions()

        let store = StoreService(catalog: try PricingCatalog.load(),
                                 cache: EntitlementCache(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!))
        await store.loadProducts()
        let lifetime = try #require(store.products.first { $0.id == "be.earnit.app.pro.lifetime" })
        #expect(await store.purchase(lifetime))
        #expect(store.entitlement == .pro(expiresAt: nil))
        session.clearTransactions()
    }
}
