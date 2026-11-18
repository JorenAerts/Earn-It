import AlarmEngine
import Core
import Features
import Foundation
import Telemetry
import Testing

@MainActor struct TelemetryTests {
    final class Clock: @unchecked Sendable { var now = Date(timeIntervalSince1970: 1_800_000_000) }

    private func make(enabled: Bool? = nil, appID: String? = "APP-ID") -> (Telemetry, RecordingSink, UserDefaults, Clock) {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        if let enabled { defaults.set(enabled, forKey: "gloop.telemetry.enabled") }
        let clock = Clock()
        let telemetry = Telemetry(defaults: defaults, now: { clock.now })
        let sink = RecordingSink()
        telemetry.configure(appID: appID, sink: sink, testMode: true)
        return (telemetry, sink, defaults, clock)
    }

    @Test func onByDefaultAndSends() {
        let (t, sink, _, _) = make()
        #expect(t.isEnabled && t.isConfigured && sink.started)
        t.send(.alarmRang)
        #expect(sink.names == ["Alarm.rang"])
        #expect(sink.signals[0].parameters["daysSinceInstall"] == "day 0")
    }

    @Test func noAppIDMeansNothingIsSent() {
        let (t, sink, _, _) = make(appID: "  ")
        t.send(.alarmRang)
        #expect(t.isConfigured == false)
        #expect(sink.signals.isEmpty)
        #expect(sink.started == false)
    }

    @Test func optOutStopsAndForgetsTheID() {
        let (t, sink, defaults, _) = make()
        let id = t.installationID
        t.setEnabled(false)
        t.send(.alarmRang)
        #expect(sink.signals.isEmpty)
        #expect(sink.started == false)
        #expect(defaults.string(forKey: "gloop.telemetry.id") == nil)
        t.setEnabled(true)
        #expect(t.installationID != id, "a new random ID: old and new data can't be linked")
        #expect(sink.started)
    }

    @Test func optOutIsRemembered() {
        let (t, sink, _, _) = make(enabled: false)
        #expect(t.isEnabled == false)
        #expect(sink.started == false)
        t.send(.alarmRang)
        #expect(sink.signals.isEmpty)
    }

    @Test func backgroundReportsTheLastScreen() throws {
        let (t, sink, _, clock) = make()
        t.sessionStarted(source: .cold)
        t.screen("Onboarding.goal")
        clock.now += 42
        t.sessionEnded()
        let last = try #require(sink.signals.last)
        #expect(last.name == "App.backgrounded")
        #expect(last.parameters["screen"] == "Onboarding.goal")
        #expect(last.parameters["secondsOnScreen"] == "42")
        #expect(last.parameters["sessionLength"] == "30-60s")
        #expect(sink.names.first == "App.launched")
    }

    @Test func commonParametersAreAdded() {
        let (t, sink, _, _) = make()
        t.commonParameters = { ["plan": "trial", "onboarded": "true"] }
        t.send(.paywallShown(source: .lockedMission))
        #expect(sink.signals[0].parameters["plan"] == "trial")
        #expect(sink.signals[0].parameters["source"] == "lockedMission")
    }

    @Test func personalLookingValuesAreDropped() {
        let (t, sink, _, _) = make()
        t.send(.onboardingStepCompleted(step: "name", seconds: 3,
                                        answers: ["oops": "joren@example.com", "id": UUID().uuidString,
                                                  "long": String(repeating: "x", count: 200)]))
        let parameters = sink.signals[0].parameters
        #expect(parameters["oops"] == nil && parameters["id"] == nil)
        #expect(parameters["long"]?.count == 64)
    }

    @Test func purchaseEventsCarryPlanAndSource() {
        let event = TelemetryEvent.purchaseCompleted(plan: "yearly", source: .onboarding, trial: true)
        #expect(event.name == "Purchase.completed")
        #expect(event.parameters == ["plan": "yearly", "source": "onboarding", "trial": "true"])
    }

    @Test func eventNamesAreUnique() {
        let samples: [TelemetryEvent] = [
            .appLaunched(source: .cold), .appForegrounded, .appBackgrounded(screen: "a", secondsOnScreen: 1, sessionSeconds: 1),
            .screenViewed(screen: "a"), .onboardingStepViewed(step: "a", index: 0),
            .onboardingStepCompleted(step: "a", seconds: 0, answers: [:]), .onboardingBack(from: "a"),
            .onboardingPermission(kind: "a", granted: true), .onboardingInviteShared(completed: true),
            .onboardingSignIn(method: "a"), .onboardingCompleted(totalSeconds: 0, outcome: "free"),
            .paywallShown(source: .other), .paywallPlanSelected(plan: "a", source: .other),
            .paywallPlansUnavailable(source: .other), .purchaseStarted(plan: "a", source: .other),
            .purchaseCompleted(plan: "a", source: .other, trial: false), .purchaseCancelled(plan: "a", source: .other),
            .purchaseFailed(plan: "a", source: .other), .purchaseRestored(found: true),
            .paywallDismissed(source: .other, secondsShown: 0, purchased: false), .entitlementChanged(from: "a", to: "b"),
            .alarmToggled(on: true), .alarmDeleted, .alarmRang, .alarmStopped(attempt: 1),
            .missionStarted(kinds: "math", attempt: 1), .missionCompleted(kinds: "math", rings: 1, secondsFromFirstRing: 1, firstTry: true),
            .missionBackupUsed(kind: "object"), .morningFailSafe(rings: 3), .streakMilestone(days: 7),
            .gloopEvolved(stage: "Blob"), .stickerEarned(sticker: "firstTry"), .pauseSet(option: "days1"), .pauseResumed,
            .errorShown(area: "a", code: "b"),
        ]
        #expect(Set(samples.map(\.name)).count == samples.count)
    }

    @Test func buckets() {
        #expect(TelemetryBuckets.duration(5) == "<10s" && TelemetryBuckets.duration(4000) == "30m+")
        #expect(TelemetryBuckets.hour(6) == "6-7" && TelemetryBuckets.hour(3) == "before 5")
        #expect(TelemetryBuckets.days(10) == "week 2")
    }

    @Test func alarmSummaryHasNoLabel() {
        let plan = AlarmPlan(label: "Joren's secret gym", sound: .builtIn(.reveille), hour: 6, weekdays: [2, 4],
                             missions: [MissionConfig(kind: .math), MissionConfig(kind: .shake)])
        let parameters = TelemetryEvent.alarmCreated(plan.telemetrySummary(alarmCount: 2)).parameters
        #expect(parameters.values.contains { $0.contains("Joren") || $0.contains("gym") } == false)
        #expect(parameters["missions"] == "math+shake" && parameters["soundKind"] == "builtIn.reveille")
        #expect(parameters["wakeHour"] == "6-7" && parameters["weekdaysCount"] == "2")
    }
}

@MainActor struct AlarmLoopEventTests {
    @Test func coordinatorReportsStopAndFailSafe() async {
        let store = KeyValueStore(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        store.savePlans([AlarmPlan(reArmMinutes: 2, maxReArms: 1, isEnabled: true)])
        let coordinator = AlarmCoordinator(store: store, scheduler: FakeScheduler(), sound: FakeAlarmSound())
        var events: [AlarmLoopEvent] = []
        coordinator.onEvent = { events.append($0) }
        await coordinator.alarmEnded(id: UUID())
        await coordinator.alarmEnded(id: UUID())
        #expect(events.first == .stopped(attempt: 1))
        #expect(events.contains { if case .failSafe = $0 { true } else { false } })
    }
}
