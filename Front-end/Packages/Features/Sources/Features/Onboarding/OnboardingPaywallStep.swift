import Purchases
import StoreKit
import SwiftUI

/// Onboarding step 7: start the free trial or continue on the free plan.
/// Functional first version — phase 5 replaces the plan list with the full PaywallView.
struct OnboardingPaywallStep: View {
    let store: StoreService
    let accountToken: UUID?
    let onNext: () -> Void

    @State private var selectedID: String?
    @State private var purchasing = false

    private var plans: [PricedProduct] { store.catalog.plans }

    var body: some View {
        OnboardingPage {
            VStack(alignment: .leading, spacing: 18) {
                Text("Try Pro free for \(store.catalog.trialDays) days")
                    .font(.largeTitle.bold())
                VStack(alignment: .leading, spacing: 8) {
                    Label("Unlimited alarms", systemImage: "alarm.fill")
                    Label("Shake & scan-a-code missions", systemImage: "qrcode.viewfinder")
                    Label("All alarm sounds", systemImage: "speaker.wave.3.fill")
                }
                .foregroundStyle(.secondary)

                if store.products.isEmpty {
                    Text(store.isLoading ? "Loading plans…" : (store.errorMessage ?? "Plans are unavailable right now."))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(plans) { plan in
                        if let product = store.product(for: plan) {
                            planRow(plan, product)
                        }
                    }
                }
                if let error = store.errorMessage, !store.products.isEmpty {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            }
        } footer: {
            PrimaryButton(title: ctaTitle, disabled: selectedProduct == nil || purchasing) {
                guard let product = selectedProduct else { return }
                purchasing = true
                Task {
                    if await store.purchase(product, accountToken: accountToken) { onNext() }
                    purchasing = false
                }
            }
            Button("Continue with free version", action: onNext)
                .foregroundStyle(.secondary)
        }
        .task {
            if store.products.isEmpty { await store.loadProducts() }
            if selectedID == nil { selectedID = store.catalog.defaultPlan?.id }
        }
    }

    private var selectedProduct: Product? {
        selectedID.flatMap { id in store.products.first { $0.id == id } }
    }

    private var ctaTitle: String {
        guard let product = selectedProduct else { return "Start free trial" }
        if product.subscription != nil, store.isEligibleForTrial { return "Start free trial" }
        return "Continue — \(product.displayPrice)"
    }

    private func planRow(_ plan: PricedProduct, _ product: Product) -> some View {
        let selected = selectedID == plan.id
        return Button {
            selectedID = plan.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(plan.title).font(.headline)
                        if let badge = plan.badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.orange, in: .capsule)
                                .foregroundStyle(.white)
                        }
                    }
                    if plan.isSubscription, store.isEligibleForTrial {
                        Text("\(store.catalog.trialDays) days free, then \(product.displayPrice)")
                            .font(.caption).foregroundStyle(.secondary)
                    } else if !plan.isSubscription {
                        Text("One payment, yours forever").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(product.displayPrice).font(.headline).monospacedDigit()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? .orange : .secondary)
            }
            .padding(14)
            .background(selected ? Color.orange.opacity(0.12) : Color(.secondarySystemBackground),
                        in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
