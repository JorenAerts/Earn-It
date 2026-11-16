import AlarmEngine
import Core
import Foundation
import Purchases
import SwiftUI
import Telemetry

/// Everything a screen needs to show the paywall. Injected once in `RootView`
/// (`.environment(\.paywall, …)`) so any screen can present it.
struct PaywallContext {
    let store: StoreService
    let accountToken: UUID?

    @MainActor var gate: FeatureGate { store.gate }
}

extension EnvironmentValues {
    @Entry var paywall: PaywallContext?
}

extension View {
    /// Presents the paywall as a sheet using the injected `PaywallContext`.
    func paywallSheet(isPresented: Binding<Bool>, source: PaywallSource = .other) -> some View {
        modifier(PaywallSheetModifier(isPresented: isPresented, source: source))
    }
}

private struct PaywallSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let source: PaywallSource
    @Environment(\.paywall) private var paywall

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            if let paywall {
                PaywallSheet(store: paywall.store, source: source, accountToken: paywall.accountToken)
            }
        }
    }
}

/// One-time messages shown on Home after a downgrade ("Alarm 07:30 was switched off…").
public final class DowngradeNotices: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "gloop.downgradeNotices"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var messages: [String] { defaults.stringArray(forKey: key) ?? [] }

    public func add(_ new: [String]) {
        guard !new.isEmpty else { return }
        defaults.set(messages + new.filter { !messages.contains($0) }, forKey: key)
    }

    public func clear() { defaults.removeObject(forKey: key) }
}

/// Brings alarms within the free tier once StoreKit confirms there is no Pro.
public enum TierEnforcement {
    /// Applies `DowngradePolicy`, reschedules every changed alarm and returns what changed.
    /// Does nothing while a mission is due (an alarm is ringing) — it runs again later.
    @MainActor
    @discardableResult
    public static func enforce(on coordinator: AlarmCoordinator, gate: FeatureGate) async -> [DowngradePolicy.Change] {
        guard !gate.isPro, !coordinator.needsMission else { return [] }
        let before = coordinator.plans
        let (after, changes) = DowngradePolicy.apply(to: before, gate: gate)
        guard !changes.isEmpty else { return [] }
        for (old, new) in zip(before, after) where old != new {
            await coordinator.save(new)
        }
        return changes
    }
}
