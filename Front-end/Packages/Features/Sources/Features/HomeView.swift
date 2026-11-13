import AlarmEngine
import Core
import SwiftData
import SwiftUI

struct HomeView: View {
    let coordinator: AlarmCoordinator
    @Query private var logs: [DayLog]
    @State private var editing = false

    private var streak: Int {
        StreakCalculator.currentStreak(completedDays: logs.compactMap(\.missionCompletedAt), today: .now)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(format: "%02d:%02d", coordinator.plan.hour, coordinator.plan.minute))
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(coordinator.plan.isEnabled ? .primary : .secondary)
                        if let next = coordinator.nextFireDate {
                            Text("Rings \(next.formatted(.relative(presentation: .named)))")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Alarm off").foregroundStyle(.secondary)
                        }
                    }
                    Toggle("Alarm on", isOn: Binding(
                        get: { coordinator.plan.isEnabled },
                        set: { on in
                            var plan = coordinator.plan
                            plan.isEnabled = on
                            Task { await coordinator.apply(plan) }
                        }))
                    Button("Edit alarm") { editing = true }
                }

                Section("Mission") {
                    ForEach(coordinator.plan.missions) { mission in
                        LabeledContent(mission.kind.displayName, value: mission.summary)
                    }
                }

                Section("Streak") {
                    Label("\(streak) day\(streak == 1 ? "" : "s")", systemImage: "flame.fill")
                        .foregroundStyle(.orange)
                        .font(.title3.weight(.semibold))
                    if coordinator.session?.failSafeTriggered == true {
                        Text("Today's alarm hit the fail-safe after \(coordinator.plan.maxReArms) re-arms.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                if let error = coordinator.lastError {
                    Section { Text(error).foregroundStyle(.red) }
                }

                #if DEBUG
                DebugSection(coordinator: coordinator)
                #endif
            }
            .navigationTitle("Earn It")
            .sheet(isPresented: $editing) {
                AlarmSetupView(plan: coordinator.plan) { plan in
                    Task { await coordinator.apply(plan) }
                }
            }
        }
    }
}

#if DEBUG
struct DebugSection: View {
    let coordinator: AlarmCoordinator
    @State private var alarms: [ScheduledAlarm] = []

    var body: some View {
        Section("Debug") {
            Button("Ring in 1 minute") { Task { await coordinator.debugRing(inSeconds: 60); refresh() } }
            Button("Ring in 10 seconds") { Task { await coordinator.debugRing(inSeconds: 10); refresh() } }
            Button("Stop all alarms", role: .destructive) { coordinator.debugStopAll(); refresh() }
            Button("Reset today's session", role: .destructive) { coordinator.debugResetSession(); refresh() }
            if let s = coordinator.session {
                LabeledContent("Re-arms", value: "\(s.reArmCount)")
                LabeledContent("Follow-ups pending", value: "\(s.followUpIDs.count)")
                LabeledContent("Mission done", value: s.missionDone ? "yes" : "no")
            }
        }
        Section("AlarmKit alarms (\(alarms.count))") {
            ForEach(alarms) { alarm in
                LabeledContent(alarm.id == coordinator.plan.id ? "Main" : String(alarm.id.uuidString.prefix(8)),
                               value: alarm.state)
            }
            Button("Refresh", action: refresh)
        }
        .onAppear(perform: refresh)
    }

    private func refresh() { alarms = coordinator.debugScheduledAlarms() }
}
#endif
