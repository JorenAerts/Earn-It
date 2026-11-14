import Coach
import SwiftUI
import WidgetKit
import WidgetShared

/// One timeline entry: the snapshot the app last wrote, shown at `date`.
struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

/// Reads the shared snapshot. Entries for now and the next midnight, so a streak that
/// ends (or "today pending") updates on its own even if the app isn't opened.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        let stored = SnapshotStore.shared.load()
        completion(SnapshotEntry(date: .now, snapshot: stored ?? (context.isPreview ? .placeholder : nil)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let now = Date.now
        let calendar = Calendar.current
        let snapshot = SnapshotStore.shared.load()
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86_400)
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: midnight) ?? midnight.addingTimeInterval(86_400)
        let entries = [SnapshotEntry(date: now, snapshot: snapshot),
                       SnapshotEntry(date: midnight.addingTimeInterval(1), snapshot: snapshot)]
        completion(Timeline(entries: entries, policy: .after(nextMidnight)))
    }
}

/// Soft background shared by the home-screen widgets.
private struct WidgetBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(.systemBackground), Color.orange.opacity(0.10)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Free for everyone.
struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetIDs.streak, provider: SnapshotProvider()) { entry in
            StreakWidgetView(snapshot: entry.snapshot, date: entry.date)
                .containerBackground(for: .widget) { WidgetBackground() }
                .widgetURL(WidgetIDs.progressURL)
        }
        .configurationDisplayName("Streak")
        .description("Your wake-up streak and whether today is earned.")
        .supportedFamilies([.systemSmall])
    }
}

/// Pro.
struct StreakRankWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetIDs.streakRank, provider: SnapshotProvider()) { entry in
            StreakRankWidgetView(snapshot: entry.snapshot, date: entry.date)
                .containerBackground(for: .widget) { WidgetBackground() }
                .widgetURL(entry.snapshot?.isPro == false ? WidgetIDs.paywallURL : WidgetIDs.progressURL)
        }
        .configurationDisplayName("Streak & Rank")
        .description("Your streak, rank and progress to the next promotion. Earn It Pro.")
        .supportedFamilies([.systemMedium])
    }
}

/// Pro.
struct ServiceRecordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetIDs.serviceRecord, provider: SnapshotProvider()) { entry in
            ServiceRecordWidgetView(snapshot: entry.snapshot, date: entry.date)
                .containerBackground(for: .widget) { WidgetBackground() }
                .widgetURL(entry.snapshot?.isPro == false ? WidgetIDs.paywallURL : WidgetIDs.progressURL)
        }
        .configurationDisplayName("Service Record")
        .description("Sergeant Rise, your rank, streaks, last 14 days and medals. Earn It Pro.")
        .supportedFamilies([.systemLarge])
    }
}

/// Lock Screen, free.
struct LockStreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetIDs.lockStreak, provider: SnapshotProvider()) { entry in
            LockStreakView(snapshot: entry.snapshot, date: entry.date)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(WidgetIDs.progressURL)
        }
        .configurationDisplayName("Streak")
        .description("Your wake-up streak on the Lock Screen.")
        .supportedFamilies([.accessoryCircular])
    }
}

/// Lock Screen, free.
struct LockStreakRankWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetIDs.lockStreakRank, provider: SnapshotProvider()) { entry in
            LockStreakRankView(snapshot: entry.snapshot, date: entry.date)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(WidgetIDs.progressURL)
        }
        .configurationDisplayName("Streak & Rank")
        .description("Streak and rank on the Lock Screen.")
        .supportedFamilies([.accessoryRectangular])
    }
}

#Preview("Streak", as: .systemSmall) { StreakWidget() } timeline: { SnapshotEntry(date: .now, snapshot: .placeholder) }
#Preview("Streak & Rank", as: .systemMedium) { StreakRankWidget() } timeline: { SnapshotEntry(date: .now, snapshot: .placeholder) }
#Preview("Service Record", as: .systemLarge) { ServiceRecordWidget() } timeline: { SnapshotEntry(date: .now, snapshot: .placeholder) }
