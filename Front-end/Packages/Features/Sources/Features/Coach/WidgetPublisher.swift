import AlarmEngine
import Coach
import Core
import Foundation
import os
import WidgetKit
import WidgetShared

private let log = Logger(subsystem: "be.gloop.app", category: "widgets")

/// Writes the widget snapshot into the App Group and asks iOS to redraw the widgets —
/// only when something visible changed, so we don't burn the widget reload budget.
@MainActor
final class WidgetPublisher {
    static let shared = WidgetPublisher()
    private var last: WidgetSnapshot?

    func makeSnapshot(coordinator: AlarmCoordinator, logs: [DayLog], isPro: Bool, now: Date = .now) -> WidgetSnapshot {
        let coach = CoachModel.shared
        let state = coach.state(coordinator: coordinator, logs: logs, now: now)
        return WidgetSnapshot.make(history: logs.map(DaySummary.init(log:)), now: now, state: state,
                                   line: coach.line(for: state, coordinator: coordinator, logs: logs, now: now),
                                   isPro: isPro, nextAlarm: coordinator.nextAlarm?.date,
                                   vitality: (coach.vitality * 100).rounded() / 100,
                                   slimeColor: AppearanceSettings.shared.slimeColor.rawValue)
    }

    func publish(coordinator: AlarmCoordinator, logs: [DayLog], isPro: Bool) {
        let store = SnapshotStore.shared
        guard store.isAvailable else { return }  // no App Group on this build (free team on device)
        let snapshot = makeSnapshot(coordinator: coordinator, logs: logs, isPro: isPro)
        if let last, Self.sameContent(last, snapshot) { return }
        guard store.save(snapshot) else {
            log.error("could not write widget snapshot")
            return
        }
        last = snapshot
        WidgetCenter.shared.reloadAllTimelines()
        log.info("widgets updated: streak \(snapshot.streak), xp \(snapshot.xp)")
    }

    /// Equal apart from the timestamp, on the same day.
    static func sameContent(_ a: WidgetSnapshot, _ b: WidgetSnapshot) -> Bool {
        var a2 = a
        a2.generatedAt = b.generatedAt
        return a2 == b && Calendar.current.isDate(a.generatedAt, inSameDayAs: b.generatedAt)
    }
}
