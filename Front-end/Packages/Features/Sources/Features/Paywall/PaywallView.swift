import Core
import Localization
import Purchases
import StoreKit
import SwiftUI
import Telemetry

/// The Gloop Pro paywall. Used as onboarding's last step, as a sheet from locked features,
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
    /// Where it was opened from (analytics: conversion per source).
    var source: PaywallSource = .other
    let accountToken: UUID?
    /// Opened for this locked mission or sound (onboarding): specific headline and a
    /// "Not now, use Math / Classic Beep" way out.
    var unlocking: PaywallUnlock? = nil
    /// "Not now" tapped (falls back to `onFinish`), so callers can tell it apart from closing.
    var onDecline: (() -> Void)? = nil
    /// Called after a successful purchase/restore, or when the user continues/closes.
    let onFinish: () -> Void

    @State private var selectedID: String?
    @State private var purchasing = false
    @State private var restoring = false
    @State private var showManage = false
    @State private var shownAt = Date.now
    @State private var legal: LegalDocumentKind?
    @State private var reportedUnavailable = false
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
            shownAt = .now
            Telemetry.shared.send(.paywallShown(source: source))
            if store.products.isEmpty { await store.loadProducts() }
            if selectedID == nil { selectedID = store.catalog.defaultPlan?.id }
            if store.products.isEmpty, !reportedUnavailable {
                reportedUnavailable = true
                Telemetry.shared.send(.paywallPlansUnavailable(source: source))
            }
        }
        .trackScreen("Paywall")
        .onDisappear {
            Telemetry.shared.send(.paywallDismissed(source: source, secondsShown: Int(Date.now.timeIntervalSince(shownAt)),
                                                    purchased: store.entitlement.isPro))
        }
        .sensoryFeedback(.success, trigger: store.entitlement.isPro) { _, isPro in isPro }
        .manageSubscriptionsSheet(isPresented: $showManage)
    }

    // MARK: Sections

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: unlocking?.symbol ?? "sun.max.fill")
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
            Text(subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var headline: String {
        if let unlocking { return unlocking.headline }
        if store.isEligibleForTrial, let trial = trialText(for: anySubscription) {
            return L10n.tr("Try Gloop Pro — \(trial)")
        }
        return L10n.tr("Unlock Gloop Pro")
    }

    private var subheadline: String {
        guard unlocking != nil else { return L10n.tr("Get up on time, every time — with every mission and alarm you need.") }
        if store.isEligibleForTrial, let trial = trialText(for: anySubscription) {
            return L10n.tr("Try it free: \(trial), with every other mission and sound. Cancel anytime.")
        }
        return L10n.tr("Unlock it with Gloop Pro, together with every other mission and sound.")
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow("alarm.fill", L10n.tr("Unlimited alarms"), L10n.tr("Weekdays, weekends, gym days — each with its own setup."))
            featureRow("qrcode.viewfinder", L10n.tr("Every mission"), L10n.tr("Scan a code in another room, shake it awake, and more to come."))
            featureRow("speaker.wave.3.fill", L10n.tr("All alarm sounds"), L10n.tr("Chime, siren, digital, deep pulse."))
            featureRow("lock.open.fill", L10n.tr("Everything new"), L10n.tr("App locking and stats as they arrive."))
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
                    Text(store.errorMessage ?? L10n.tr("Plans are unavailable right now."))
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
                            Telemetry.shared.send(.paywallPlanSelected(plan: plan.key, source: source))
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
        } else if let unlocking {
            Button(unlocking.declineTitle, action: onDecline ?? onFinish)
                .foregroundStyle(.secondary)
        }

        HStack(spacing: 16) {
            Button(restoring ? L10n.tr("Restoring…") : L10n.tr("Restore")) { restore() }
                .disabled(restoring || purchasing)
            Text("·").foregroundStyle(.tertiary)
            Button("Terms") { legal = .terms }
            Text("·").foregroundStyle(.tertiary)
            Button("Privacy") { legal = .privacy }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .sheet(item: $legal) { LegalSheet(kind: $0) }
    }

    private var selectedProduct: Product? {
        selectedID.flatMap { id in store.products.first { $0.id == id } }
    }

    private var selectedPlan: PricedProduct? {
        selectedID.flatMap(store.catalog.plan(id:))
    }

    private var ctaTitle: String {
        guard let product = selectedProduct, let plan = selectedPlan else { return L10n.tr("Continue") }
        if plan.isSubscription {
            if store.isEligibleForTrial, trialText(for: product) != nil { return L10n.tr("Start free trial") }
            let per = PlanPeriod(iso: plan.period)?.perLabel ?? ""
            return L10n.tr("Subscribe — \(product.displayPrice)\(per)")
        }
        return L10n.tr("Unlock forever — \(product.displayPrice)")
    }

    /// Auto-renewal disclosure (App Review Guideline 3.1.2).
    private var disclosure: String? {
        guard let product = selectedProduct, let plan = selectedPlan else { return nil }
        guard plan.isSubscription, let period = PlanPeriod(iso: plan.period) else {
            return L10n.tr("One-time purchase. No subscription, no renewals.")
        }
        let price = product.displayPrice, every = period.everyLabel
        let rules = L10n.tr("Payment is charged to your Apple ID. The subscription renews automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in Settings › Apple ID › Subscriptions.")
        if store.isEligibleForTrial, let trial = trialText(for: product) {
            return L10n.tr("\(trial.capitalizedFirst), then \(price) \(every).") + " " + rules
        }
        return L10n.tr("\(price) \(every).") + " " + rules
    }

    // MARK: Actions

    private func buy() {
        guard let product = selectedProduct else { return }
        let plan = selectedPlan?.key ?? product.id
        purchasing = true
        Telemetry.shared.send(.purchaseStarted(plan: plan, source: source))
        Task {
            let done = await store.purchase(product, accountToken: accountToken)
            purchasing = false
            if done {
                Telemetry.shared.send(.purchaseCompleted(plan: plan, source: source,
                                                         trial: { if case .trial = store.entitlement { true } else { false } }()))
                onFinish()
            } else if store.errorMessage != nil {
                Telemetry.shared.send(.purchaseFailed(plan: plan, source: source))
            } else {
                Telemetry.shared.send(.purchaseCancelled(plan: plan, source: source))
            }
        }
    }

    private func restore() {
        restoring = true
        Task {
            await store.restore()
            restoring = false
            Telemetry.shared.send(.purchaseRestored(found: store.entitlement.isPro))
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
            PrimaryButton(title: mode == .onboarding ? L10n.tr("Continue") : L10n.tr("Done"), action: onFinish)
            if !store.entitlement.isLifetime {
                Button("Manage subscription") { showManage = true }
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var proStatusText: String {
        switch store.entitlement {
        case .trial(let renewsAt):
            renewsAt.map { L10n.tr("Your free trial runs until \($0.localized(date: .abbreviated, time: .shortened)).") }
                ?? L10n.tr("Your free trial is active.")
        case .pro(let expiresAt):
            expiresAt.map { L10n.tr("Renews on \($0.localized(date: .abbreviated, time: .omitted)).") }
                ?? L10n.tr("Lifetime access — thank you!")
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

/// What a paywall was opened to unlock, from onboarding's mission and sound steps.
enum PaywallUnlock: Hashable, Identifiable {
    case mission(MissionKind)
    case sound(AlarmSound)

    var id: Self { self }

    var symbol: String {
        switch self {
        case .mission(let kind): kind.symbol
        case .sound: "speaker.wave.3.fill"
        }
    }

    var headline: String {
        switch self {
        case .mission(let kind): L10n.tr("\(kind.displayName) is a Pro mission")
        case .sound(let sound): L10n.tr("\(sound.displayName) is a Pro sound")
        }
    }

    /// The free fallback the user gets when they say no.
    var declineTitle: String {
        switch self {
        case .mission: L10n.tr("Not now, use Math")
        case .sound: L10n.tr("Not now, use Classic Beep")
        }
    }
}

/// Paywall presented as a sheet (locked features, Settings).
struct PaywallSheet: View {
    let store: StoreService
    var source: PaywallSource = .other
    let accountToken: UUID?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PaywallView(store: store, mode: .sheet, source: source, accountToken: accountToken) { dismiss() }
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
