import AlarmEngine
import Coach
import Core
import Purchases
import SwiftData
import SwiftUI
import WidgetShared

/// Settings › Developer › Widget previews: every widget at its real size, with live data.
struct WidgetPreviewsView: View {
    let coordinator: AlarmCoordinator
    let store: StoreService
    @Query private var logs: [DayLog]
    @State private var asFreeUser = CommandLine.arguments.contains("-free")
    @State private var useSample = CommandLine.arguments.contains("-sample")

    private var snapshot: WidgetSnapshot {
        var s = useSample ? WidgetSnapshot.placeholder
            : WidgetPublisher.shared.makeSnapshot(coordinator: coordinator, logs: logs, isPro: store.entitlement.isPro)
        if asFreeUser { s.isPro = false }
        return s
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Toggle("Show as free user", isOn: $asFreeUser)
                Toggle("Use sample data", isOn: $useSample)
                LabeledContent("App Group", value: SnapshotStore.shared.isAvailable ? "Available" : "Not available on this build")
                    .font(.footnote)

                frame("Small · Streak", width: 170, height: 170) { StreakWidgetView(snapshot: snapshot, date: .now) }
                frame("Medium · Streak & Rank", width: 364, height: 170) { StreakRankWidgetView(snapshot: snapshot, date: .now) }
                frame("Large · Service Record", width: 364, height: 382) { ServiceRecordWidgetView(snapshot: snapshot, date: .now) }
                HStack(alignment: .top, spacing: 24) {
                    frame("Lock · Streak", width: 76, height: 76, padding: 0, round: true) {
                        LockStreakView(snapshot: snapshot, date: .now)
                    }
                    frame("Lock · Streak & Rank", width: 172, height: 76, padding: 4) {
                        LockStreakRankView(snapshot: snapshot, date: .now)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Widget previews")
    }

    private func frame<Content: View>(_ title: String, width: CGFloat, height: CGFloat, padding: CGFloat = 16,
                                      round: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 8) {
            content()
                .padding(padding)
                .frame(width: width, height: height)
                .background(LinearGradient(colors: [Color(.systemBackground), Color.orange.opacity(0.10)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(round ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 22)))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
