import AlarmEngine
import Coach
import Core
import Permissions
import Purchases
import SwiftData
import SwiftUI
import Telemetry

struct HomeView: View {
    let coordinator: AlarmCoordinator
    let store: StoreService
    /// One-time messages after a downgrade to the free plan.
    var notices: [String] = []
    var onDismissNotices: () -> Void = {}
    @Query private var logs: [DayLog]
    @State private var editing: EditTarget?
    @State private var showPaywall = false
    @State private var developer = DeveloperMode.shared
    @State private var paywallSource: PaywallSource = .homeBanner

    private func openPaywall(_ source: PaywallSource) {
        paywallSource = source
        showPaywall = true
    }

    private var gate: FeatureGate { store.gate }

    private func addAlarm() {
        if gate.canAddAlarm(currentCount: coordinator.plans.count) {
            editing = EditTarget(plan: AlarmPlan(), isNew: true)
        } else {
            openPaywall(.addAlarm)
        }
    }

    private func setEnabled(_ on: Bool, _ plan: AlarmPlan) {
        let enabledOthers = coordinator.plans.filter { $0.isEnabled && $0.id != plan.id }.count
        if on, !gate.canEnableAlarm(enabledCount: enabledOthers) {
            openPaywall(.enableAlarm)
            return
        }
        Telemetry.shared.send(.alarmToggled(on: on))
        Task {
            if on { _ = await PermissionCenter.shared.ensure(.alarms) }  // explains + Settings if off
            await coordinator.setEnabled(on, for: plan.id)
        }
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
                if PermissionCenter.shared.status(.alarms) == .denied ||
                    (PermissionCenter.shared.status(.alarms) == .notDetermined && !coordinator.plans.isEmpty) {
                    Section {
                        PermissionBanner(kind: .alarms, message: "Your alarms can't ring until Gloop may use alarms.")
                    }
                }
                if coordinator.activePause != nil {
                    Section { PauseBanner(coordinator: coordinator) }
                }
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
                        Text(coordinator.plans.isEmpty ? "No alarms yet — tap + to add one."
                             : coordinator.activePause != nil ? "Alarms are paused." : "All alarms are off.")
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
                            .contextMenu {
                                if developer.isOn {
                                    Button("Test: ring in 10 seconds") {
                                        Task { await coordinator.debugRing(inSeconds: 10, planID: plan.id) }
                                    }
                                }
                            }
                    }
                    .onDelete { offsets in
                        offsets.map { coordinator.plans[$0].id }.forEach(coordinator.delete(id:))
                        Telemetry.shared.send(.alarmDeleted)
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
                        Button("Get Pro back") { openPaywall(.downgradeNotice) }
                        Button("OK", action: onDismissNotices).foregroundStyle(.secondary)
                    }
                }

                if !gate.isPro {
                    Section {
                        Button { openPaywall(.homeBanner) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "sun.max.fill").font(.title2).foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Unlock Gloop Pro").font(.headline).foregroundStyle(.primary)
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
            .paywallSheet(isPresented: $showPaywall, source: paywallSource)
            .sheet(item: $editing) { target in
                AlarmSetupView(plan: target.plan, isNew: target.isNew,
                               onSave: { plan in
                                   Task {
                                       await coordinator.save(plan)
                                       let summary = plan.telemetrySummary(alarmCount: coordinator.plans.count)
                                       Telemetry.shared.send(target.isNew ? .alarmCreated(summary) : .alarmEdited(summary))
                                   }
                               },
                               onDelete: {
                                   coordinator.delete(id: target.plan.id)
                                   Telemetry.shared.send(.alarmDeleted)
                               })
            }
            .trackScreen("Home")
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
                Text(plan.missions.map(\.alarmTitle).joined(separator: " + ") + " · " + plan.sound.displayName)
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
