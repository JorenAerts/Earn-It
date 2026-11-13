import Foundation
import Observation
import os
import StoreKit

private let log = Logger(subsystem: "be.earnit.app", category: "store")

/// StoreKit 2 wrapper: products, purchases, restore and the live entitlement.
/// Prices shown come from StoreKit (localized); which plans exist comes from `PricingCatalog`.
@MainActor
@Observable
public final class StoreService {
    public let catalog: PricingCatalog
    public private(set) var products: [Product] = []
    public private(set) var entitlement: EntitlementState
    /// The user can still get the free trial (once per Apple ID per subscription group).
    public private(set) var isEligibleForTrial = true
    public private(set) var isLoading = false
    /// True once StoreKit has been asked at least once this launch. Until then `entitlement`
    /// is only the cached value — never take features away based on the cache alone.
    public private(set) var hasLoadedEntitlement = false
    public private(set) var errorMessage: String?

    @ObservationIgnored private let cache: EntitlementCache
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    public init(catalog: PricingCatalog, cache: EntitlementCache = EntitlementCache()) {
        self.catalog = catalog
        self.cache = cache
        self.entitlement = cache.load()
    }

    public var gate: FeatureGate { FeatureGate(entitlement) }

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
            errorMessage = products.isEmpty ? "Plans are unavailable right now." : nil
        } catch {
            errorMessage = "Couldn't load plans: \(error.localizedDescription)"
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
                    errorMessage = "The purchase couldn't be verified."
                    return false
                }
                await transaction.finish()
                await refreshEntitlement()
                log.notice("purchased \(product.id, privacy: .public)")
                return true
            case .pending:
                errorMessage = "Purchase pending approval."
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }

    public func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
        await refreshEntitlement()
    }

    public func refreshEntitlement() async {
        var infos: [TransactionInfo] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, catalog.productIDs.contains(t.productID) else { continue }
            infos.append(TransactionInfo(productID: t.productID,
                                         expiresAt: t.expirationDate,
                                         isTrial: t.offer?.paymentMode == .freeTrial,
                                         isRevoked: t.revocationDate != nil))
        }
        let state = EntitlementResolver.resolve(infos, now: Date())
        if state != entitlement { log.notice("entitlement \(String(describing: state), privacy: .public)") }
        entitlement = state
        cache.save(state)
        hasLoadedEntitlement = true
    }

    #if DEBUG
    /// Debug: forget the cached entitlement (StoreKit stays the source of truth).
    public func debugResetCache() {
        cache.save(.free)
        entitlement = .free
    }
    #endif
}
