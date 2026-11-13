import Purchases
import StoreKit
import SwiftUI

/// The Earn It Pro paywall. Used as onboarding's last step, as a sheet from locked features,
/// and from Settings. Plans + order + badges come from Pricing.json; prices from StoreKit.
struct PaywallView: View {
    enum Mode {
        /// Last onboarding step: secondary action is "Continue with free version".
        case onboarding
        /// Presented as a sheet: shows a close button.
        case sheet
    }

    let store: StoreService
    let mode: Mode
    let accountToken: UUID?
    let termsURL: URL
    let privacyURL: URL
    /// Called after a successful purchase/restore, or when the user continues/closes.
    let onFinish: () -> Void

    @State private var selectedID: String?
    @State private var purchasing = false
    @State private var restoring = false
    @State private var showManage = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            if store.entitlement.isPro {
                alreadyPro
            } else {
                OnboardingPage {
                    VStack(alignment: .leading, spacing: 22) {
                        hero
                        features
                        plansSection
                    }
                } footer: {
                    footer
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if mode == .sheet {
                Button(action: onFinish) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(.thinMaterial, in: .circle)
                }
                .padding(16)
                .accessibilityLabel("Close")
            }
        }
        .task {
            if store.products.isEmpty { await store.loadProducts() }
            if selectedID == nil { selectedID = store.catalog.defaultPlan?.id }
        }
        .sensoryFeedback(.success, trigger: store.entitlement.isPro) { _, isPro in isPro }
        .manageSubscriptionsSheet(isPresented: $showManage)
    }

    // MARK: Sections

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                Text("PRO")
                    .font(.caption.weight(.heavy))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.orange, in: .capsule)
                    .foregroundStyle(.white)
            }
            .padding(.top, mode == .sheet ? 24 : 8)
            Text(headline)
                .font(.largeTitle.bold())
            Text("Get up on time, every time — with every mission and alarm you need.")
                .foregroundStyle(.secondary)
        }
    }

    private var headline: String {
        if store.isEligibleForTrial, let trial = trialText(for: anySubscription) {
            return "Try Earn It Pro — \(trial)"
        }
        return "Unlock Earn It Pro"
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow("alarm.fill", "Unlimited alarms", "Weekdays, weekends, gym days — each with its own setup.")
            featureRow("qrcode.viewfinder", "Every mission", "Scan a code in another room, shake it awake, and more to come.")
            featureRow("speaker.wave.3.fill", "All alarm sounds", "Chime, siren, digital, deep pulse.")
            featureRow("lock.open.fill", "Everything new", "App locking and stats as they arrive.")
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 18))
    }

    private func featureRow(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.orange)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var plansSection: some View {
        if store.products.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if store.isLoading {
                    ProgressView("Loading plans…")
                } else {
                    Text(store.errorMessage ?? "Plans are unavailable right now.")
                        .foregroundStyle(.secondary)
                    Button("Try again") { Task { await store.loadProducts() } }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 10) {
                ForEach(store.catalog.plans) { plan in
                    if let product = store.product(for: plan) {
                        PlanCard(plan: plan, product: product,
                                 trial: store.isEligibleForTrial ? trialText(for: product) : nil,
                                 isSelected: selectedID == plan.id) {
                            selectedID = plan.id
                        }
                    }
                }
            }
        }
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        if let error = store.errorMessage, !store.products.isEmpty {
            Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
        }
        PrimaryButton(title: ctaTitle, disabled: selectedProduct == nil || purchasing || restoring) {
            buy()
        }
        .overlay { if purchasing { ProgressView().tint(.white) } }

        if let disclosure {
            Text(disclosure)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }

        if mode == .onboarding {
            Button("Continue with free version", action: onFinish)
                .foregroundStyle(.secondary)
        }

        HStack(spacing: 16) {
            Button(restoring ? "Restoring…" : "Restore") { restore() }
                .disabled(restoring || purchasing)
            Text("·").foregroundStyle(.tertiary)
            Button("Terms") { openURL(termsURL) }
            Text("·").foregroundStyle(.tertiary)
            Button("Privacy") { openURL(privacyURL) }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private var selectedProduct: Product? {
        selectedID.flatMap { id in store.products.first { $0.id == id } }
    }

    private var selectedPlan: PricedProduct? {
        selectedID.flatMap(store.catalog.plan(id:))
    }

    private var ctaTitle: String {
        guard let product = selectedProduct, let plan = selectedPlan else { return "Continue" }
        if plan.isSubscription {
            if store.isEligibleForTrial, trialText(for: product) != nil { return "Start free trial" }
            return "Subscribe — \(product.displayPrice)\(PlanPeriod(iso: plan.period)?.perLabel ?? "")"
        }
        return "Unlock forever — \(product.displayPrice)"
    }

    /// Auto-renewal disclosure (App Review Guideline 3.1.2).
    private var disclosure: String? {
        guard let product = selectedProduct, let plan = selectedPlan else { return nil }
        guard plan.isSubscription, let period = PlanPeriod(iso: plan.period) else {
            return "One-time purchase. No subscription, no renewals."
        }
        let renewal = "\(product.displayPrice) \(period.everyLabel)"
        let start = store.isEligibleForTrial ? trialText(for: product).map { "\($0.capitalizedFirst), then " } ?? "" : ""
        return "\(start)\(renewal). Payment is charged to your Apple ID. The subscription renews automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in Settings › Apple ID › Subscriptions."
    }

    // MARK: Actions

    private func buy() {
        guard let product = selectedProduct else { return }
        purchasing = true
        Task {
            let done = await store.purchase(product, accountToken: accountToken)
            purchasing = false
            if done { onFinish() }
        }
    }

    private func restore() {
        restoring = true
        Task {
            await store.restore()
            restoring = false
            if store.entitlement.isPro { onFinish() }
        }
    }

    // MARK: Already Pro

    private var alreadyPro: some View {
        OnboardingPage {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.orange)
                    .padding(.top, 32)
                Text("You're Pro").font(.largeTitle.bold())
                Text(proStatusText).foregroundStyle(.secondary)
            }
        } footer: {
            PrimaryButton(title: mode == .onboarding ? "Continue" : "Done", action: onFinish)
            if !store.entitlement.isLifetime {
                Button("Manage subscription") { showManage = true }
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var proStatusText: String {
        switch store.entitlement {
        case .trial(let renewsAt):
            renewsAt.map { "Your free trial runs until \($0.formatted(date: .abbreviated, time: .shortened))." }
                ?? "Your free trial is active."
        case .pro(let expiresAt):
            expiresAt.map { "Renews on \($0.formatted(date: .abbreviated, time: .omitted))." }
                ?? "Lifetime access — thank you!"
        case .free:
            ""
        }
    }

    // MARK: Helpers

    private var anySubscription: Product? {
        store.products.first { $0.subscription?.introductoryOffer != nil }
    }

    /// "3 days free" from the product's introductory offer (falls back to Pricing.json).
    private func trialText(for product: Product?) -> String? {
        guard let subscription = product?.subscription else { return nil }
        if let offer = subscription.introductoryOffer, offer.paymentMode == .freeTrial {
            return freeTrialText(value: offer.period.value, unit: offer.period.unit.planUnit)
        }
        return nil
    }
}

private struct PlanCard: View {
    let plan: PricedProduct
    let product: Product
    let trial: String?
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        let period = PlanPeriod(iso: plan.period)
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .orange : .secondary)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(plan.title).font(.headline)
                        if let badge = plan.badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(.orange, in: .capsule)
                                .foregroundStyle(.white)
                        }
                    }
                    if let trial {
                        Text(trial.capitalizedFirst).font(.caption).foregroundStyle(.orange)
                    } else if !plan.isSubscription {
                        Text("One payment, yours forever").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice + (period?.perLabel ?? ""))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    if let monthly = period?.monthlyEquivalent(of: product.price) {
                        Text("≈ \(monthly.formatted(product.priceFormatStyle))/month")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .padding(14)
            .background(isSelected ? Color.orange.opacity(0.12) : Color(.secondarySystemBackground),
                        in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Color.orange : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Paywall presented as a sheet (locked features, Settings).
struct PaywallSheet: View {
    let store: StoreService
    let accountToken: UUID?
    let termsURL: URL
    let privacyURL: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PaywallView(store: store, mode: .sheet, accountToken: accountToken,
                    termsURL: termsURL, privacyURL: privacyURL) { dismiss() }
    }
}

extension Product.SubscriptionPeriod.Unit {
    var planUnit: PlanPeriod.Unit {
        switch self {
        case .day: .day
        case .week: .week
        case .month: .month
        case .year: .year
        @unknown default: .day
        }
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
