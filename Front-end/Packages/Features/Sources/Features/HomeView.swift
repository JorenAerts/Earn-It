import AlarmEngine
import Coach
import Core
import Purchases
import SwiftData
import SwiftUI

struct HomeView: View {
    let coordinator: AlarmCoordinator
    let store: StoreService
    /// One-time messages after a downgrade to the free plan.
    var notices: [String] = []
    var onDismissNotices: () -> Void = {}
    @Query private var logs: [DayLog]
    @State private var editing: EditTarget?
    @State private var showPaywall = false

    private var gate: FeatureGate { store.gate }

    private func addAlarm() {
        if gate.canAddAlarm(currentCount: coordinator.plans.count) {
            editing = EditTarget(plan: AlarmPlan(), isNew: true)
        } else {
            showPaywall = true
        }
    }

    private func setEnabled(_ on: Bool, _ plan: AlarmPlan) {
        let enabledOthers = coordinator.plans.filter { $0.isEnabled && $0.id != plan.id }.count
        if on, !gate.canEnableAlarm(enabledCount: enabledOthers) {
            showPaywall = true
            return
        }
        Task { await coordinator.setEnabled(on, for: plan.id) }
    }

    /// Sheet target: an existing alarm or a fresh one.
    struct EditTarget: Identifiable {
        let plan: AlarmPlan
        let isNew: Bool
        var id: UUID { plan.id }
    }

    private var streak: Int {
        StreakCalculator.currentStreak(completedDays: logs.compactMap(\.missionCompletedAt), today: .now)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    let coach = CoachModel.shared
                    let state = coach.state(coordinator: coordinator, logs: logs)
                    CoachCard(state: state, line: coach.line(for: state, coordinator: coordinator, logs: logs))
                        .padding(.vertical, 4)
                }

                Section {
                    if let next = coordinator.nextAlarm {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Next alarm").font(.caption.weight(.semibold)).textCase(.uppercase)
                                .foregroundStyle(.secondary)
                            Text(next.date.formatted(.relative(presentation: .named)))
                                .font(.title2.weight(.semibold))
                        }
                    } else {
                        Text(coordinator.plans.isEmpty ? "No alarms yet — tap + to add one." : "All alarms are off.")
                            .foregroundStyle(.secondary)
                    }
                    Label("\(streak) day streak", systemImage: "flame.fill")
                        .foregroundStyle(.orange)
                        .font(.headline)
                }

                Section("Alarms") {
                    ForEach(coordinator.plans) { plan in
                        AlarmRow(plan: plan,
                                 isOn: Binding(get: { plan.isEnabled },
                                               set: { on in setEnabled(on, plan) }))
                            .contentShape(.rect)
                            .onTapGesture { editing = EditTarget(plan: plan, isNew: false) }
                            #if DEBUG
                            .contextMenu {
                                Button("Test: ring in 10 seconds") {
                                    Task { await coordinator.debugRing(inSeconds: 10, planID: plan.id) }
                                }
                            }
                            #endif
                    }
                    .onDelete { offsets in
                        offsets.map { coordinator.plans[$0].id }.forEach(coordinator.delete(id:))
                    }
                    Button(action: addAlarm) {
                        HStack {
                            Label("Add alarm", systemImage: "plus.circle.fill")
                            if !gate.canAddAlarm(currentCount: coordinator.plans.count) {
                                Spacer()
                                ProBadge()
                            }
                        }
                    }
                }

                if !notices.isEmpty {
                    Section("Your plan changed") {
                        ForEach(notices, id: \.self) { Text($0).font(.subheadline) }
                        Button("Get Pro back") { showPaywall = true }
                        Button("OK", action: onDismissNotices).foregroundStyle(.secondary)
                    }
                }

                if !gate.isPro {
                    Section {
                        Button { showPaywall = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "sun.max.fill").font(.title2).foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Unlock Earn It Pro").font(.headline).foregroundStyle(.primary)
                                    Text("Unlimited alarms, every mission, all sounds")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                if coordinator.session?.failSafeTriggered == true {
                    Section {
                        Text("Today's alarm hit the fail-safe limit and stopped.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                if let error = coordinator.lastError {
                    Section { Text(error).foregroundStyle(.red) }
                }

            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addAlarm) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add alarm")
                }
            }
            .paywallSheet(isPresented: $showPaywall)
            .sheet(item: $editing) { target in
                AlarmSetupView(plan: target.plan, isNew: target.isNew,
                               onSave: { plan in Task { await coordinator.save(plan) } },
                               onDelete: { coordinator.delete(id: target.plan.id) })
            }
        }
    }
}

/// Small "PRO" capsule next to locked features.
struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.caption2.weight(.heavy))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(.orange, in: .capsule)
            .foregroundStyle(.white)
            .accessibilityLabel("Requires Pro")
    }
}

private struct AlarmRow: View {
    let plan: AlarmPlan
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.timeText)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text([plan.label.isEmpty ? nil : plan.label, plan.repeatText]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                Text(plan.missions.map(\.kind.alarmTitle).joined(separator: " + ") + " · " + plan.sound.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .foregroundStyle(plan.isEnabled ? .primary : .secondary)
            Spacer()
            Toggle("Alarm on", isOn: $isOn).labelsHidden()
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
struct DebugSection: View {
    let coordinator: AlarmCoordinator
    @State private var alarms: [ScheduledAlarm] = []

    var body: some View {
        Section("Debug") {
            Button("Ring in 1 minute (first alarm)") { Task { await coordinator.debugRing(inSeconds: 60); refresh() } }
            Button("Ring in 10 seconds (first alarm)") { Task { await coordinator.debugRing(inSeconds: 10); refresh() } }
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
                LabeledContent(coordinator.plan(id: alarm.id).map { "Main " + $0.timeText } ?? String(alarm.id.uuidString.prefix(8)),
                               value: alarm.state)
            }
            Button("Refresh", action: refresh)
        }
        .onAppear(perform: refresh)
    }

    private func refresh() { alarms = coordinator.debugScheduledAlarms() }
}
#endif
