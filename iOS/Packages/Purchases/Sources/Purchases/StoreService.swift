import Core
import Foundation
import Localization
import Observation
import StoreKit
import os

private let log = Logger(subsystem: "be.gloop.app", category: "store")

/// StoreKit 2 wrapper: products, purchases, restore and the live entitlement.
/// Prices shown come from StoreKit (localized); which plans exist comes from `PricingCatalog`.
@MainActor
@Observable
public final class StoreService {
    public let catalog: PricingCatalog
    public private(set) var products: [Product] = []
    /// What StoreKit says the user has.
    public private(set) var storeEntitlement: EntitlementState
    /// Developer tools › "Test as Free plan" (see `EntitlementOverride`).
    public private(set) var forceFree: Bool
    /// What the app uses: the StoreKit entitlement, unless the free-plan test switch is on.
    public var entitlement: EntitlementState {
        EntitlementOverride.apply(storeEntitlement, forceFree: forceFree, onlyTestPurchases: !activePurchases.contains { !$0.isSandbox })
    }

    /// The Pro the user has comes from TestFlight / sandbox test purchases only: they may switch to
    /// the free plan to test it (Settings › Gloop Pro). Never true for App Store customers.
    public var canTestAsFree: Bool {
        !activePurchases.isEmpty && activePurchases.allSatisfy(\.isSandbox)
    }
    /// Purchases StoreKit currently grants (restore message, diagnostics).
    public private(set) var activePurchases: [ActivePurchase] = []
    /// The user can still get the free trial (once per Apple ID per subscription group).
    public private(set) var isEligibleForTrial = true
    public private(set) var isLoading = false
    /// True once StoreKit has been asked at least once this launch. Until then `entitlement`
    /// is only the cached value — never take features away based on the cache alone.
    public private(set) var hasLoadedEntitlement = false
    public private(set) var errorMessage: String?
    /// Bonus sounds unlocked without Pro (see `BonusUnlocks`).
    public private(set) var bonusSounds: Set<AlarmSound>

    @ObservationIgnored private let cache: EntitlementCache
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    public init(catalog: PricingCatalog, cache: EntitlementCache = EntitlementCache(), defaults: UserDefaults = .standard) {
        self.catalog = catalog
        self.cache = cache
        self.defaults = defaults
        self.storeEntitlement = cache.load()
        self.forceFree = defaults.bool(forKey: EntitlementOverride.defaultsKey)
        self.bonusSounds = BonusUnlocks.sounds()
    }

    /// Developer tools: test the free plan while a purchase is active (off again when developer mode locks).
    public func setForceFree(_ on: Bool) {
        forceFree = on
        defaults.set(on, forKey: EntitlementOverride.defaultsKey)
        log.notice("test as free plan: \(on)")
    }

    public var gate: FeatureGate { FeatureGate(entitlement, bonusSounds: bonusSounds) }

    /// Onboarding › invite a friend: the bonus sound becomes free forever.
    public func unlockInviteSound() {
        BonusUnlocks.unlock()
        bonusSounds = BonusUnlocks.sounds()
    }

    /// Call once at launch: listens for renewals, refunds and purchases made elsewhere.
    public func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
                await self?.refreshEntitlement()
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlement()
        }
    }

    public func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: catalog.productIDs)
            let order = catalog.productIDs
            products = loaded.sorted { (order.firstIndex(of: $0.id) ?? .max) < (order.firstIndex(of: $1.id) ?? .max) }
            if let subscription = products.compactMap(\.subscription).first {
                isEligibleForTrial = await subscription.isEligibleForIntroOffer
            }
            errorMessage = products.isEmpty ? L10n.tr("Plans are unavailable right now.") : nil
            if let warning = await diagnostics().pricingWarning { log.error("\(warning, privacy: .public)") }
        } catch {
            errorMessage = L10n.tr("Couldn't load plans: \(error.localizedDescription)")
        }
    }

    public func product(for plan: PricedProduct) -> Product? {
        products.first { $0.id == plan.id }
    }

    /// Returns true when the purchase completed (not cancelled / pending).
    /// `accountToken` links the purchase to the signed-in account (Supabase user id).
    @discardableResult
    public func purchase(_ product: Product, accountToken: UUID? = nil) async -> Bool {
        errorMessage = nil
        do {
            var options: Set<Product.PurchaseOption> = []
            if let accountToken { options.insert(.appAccountToken(accountToken)) }
            switch try await product.purchase(options: options) {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    errorMessage = L10n.tr("The purchase couldn't be verified.")
                    return false
                }
                await transaction.finish()
                await refreshEntitlement()
                log.notice("purchased \(product.id, privacy: .public)")
                return true
            case .pending:
                errorMessage = L10n.tr("Purchase pending approval.")
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = L10n.tr("Purchase failed: \(error.localizedDescription)")
            return false
        }
    }

    public func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = L10n.tr("Restore failed: \(error.localizedDescription)")
        }
        await refreshEntitlement()
    }

    public func refreshEntitlement() async {
        var infos: [TransactionInfo] = []
        var purchases: [ActivePurchase] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, catalog.productIDs.contains(t.productID) else { continue }
            let isTrial = t.offer?.paymentMode == .freeTrial
            infos.append(TransactionInfo(productID: t.productID,
                                         expiresAt: t.expirationDate,
                                         isTrial: isTrial,
                                         isRevoked: t.revocationDate != nil))
            if t.revocationDate == nil {
                purchases.append(ActivePurchase(productID: t.productID, purchasedAt: t.purchaseDate, expiresAt: t.expirationDate,
                                                isTrial: isTrial, isSandbox: t.environment != .production))
            }
        }
        let state = EntitlementResolver.resolve(infos, now: Date())
        if state != storeEntitlement { log.notice("entitlement \(String(describing: state), privacy: .public)") }
        storeEntitlement = state
        activePurchases = purchases
        cache.save(state)
        hasLoadedEntitlement = true
    }

    /// Developer tools › Store diagnostics: storefront, products with App Store Connect prices, purchases.
    public func diagnostics() async -> StoreDiagnostics {
        let storefront = await Storefront.current
        let lines = products.map { p in
            StoreDiagnostics.ProductLine(
                id: p.id, displayPrice: p.displayPrice, price: p.price, currency: p.priceFormatStyle.currencyCode,
                period: p.subscription.map { "\($0.subscriptionPeriod.value) \($0.subscriptionPeriod.unit)" },
                introOffer: p.subscription?.introductoryOffer.map { "\($0.paymentMode.rawValue) \($0.period.value) \($0.period.unit)" })
        }
        let place = storefront.map { "\($0.countryCode) (\($0.id))" } ?? "unknown"
        return StoreDiagnostics(storefront: place, products: lines, purchases: activePurchases, trialEligible: isEligibleForTrial)
    }

    /// Developer tools: forget the cached entitlement (StoreKit stays the source of truth).
    public func debugResetCache() {
        cache.save(.free)
        storeEntitlement = .free
    }
}
