import AlarmEngine
import Core
import Missions
import Permissions
import Purchases
import SwiftUI

struct AlarmSetupView: View {
    @State var plan: AlarmPlan
    let isNew: Bool
    let onSave: (AlarmPlan) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var showPaywall = false
    @State private var showMissionPicker = false
    @State private var editingMission: EditingMission?

    private struct EditingMission: Identifiable { let id: UUID }
    @Environment(\.paywall) private var paywall

    /// Without an injected context (previews) everything is unlocked.
    private var gate: FeatureGate { paywall?.gate ?? FeatureGate(isPro: true) }

    private var time: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: plan.hour, minute: plan.minute, second: 0, of: .now) ?? .now },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                plan.hour = c.hour ?? 7
                plan.minute = c.minute ?? 0
            })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Wake time", selection: time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                }

                Section {
                    TextField("Label (e.g. Work days)", text: $plan.label)
                        .textInputAutocapitalization(.sentences)
                }

                Section("Repeat") {
                    WeekdayPicker(selection: $plan.weekdays)
                }

                Section {
                    NavigationLink {
                        SoundPickerView(selection: $plan.sound, gate: gate)
                    } label: {
                        LabeledContent {
                            Text(plan.sound.displayName).lineLimit(1)
                        } label: {
                            Label("Sound", systemImage: plan.sound.symbol)
                        }
                    }
                } footer: {
                    Text("The same sound keeps playing in the app until your mission is done.")
                }

                if PermissionCenter.shared.status(.liveActivities) == .denied {
                    Section {
                        PermissionBanner(kind: .liveActivities,
                                         message: "Live Activities are off, so the re-ring countdown won't show on your Lock Screen.")
                    }
                }

                Section {
                    ForEach(plan.missions) { mission in
                        Button { editingMission = EditingMission(id: mission.id) } label: { MissionRow(config: mission) }
                            .buttonStyle(.plain)
                    }
                    .onDelete { plan.missions.remove(atOffsets: $0) }
                    .onMove { plan.missions.move(fromOffsets: $0, toOffset: $1) }
                    Button {
                        showMissionPicker = true
                    } label: {
                        Label("Add mission", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Missions")
                } footer: {
                    if plan.missions.count > 1 {
                        Text("Done in this order when the alarm rings. Swipe to remove, long-press to reorder.")
                    }
                }

                Section {
                    Stepper("Re-ring after \(plan.reArmMinutes) min", value: $plan.reArmMinutes, in: 1...10)
                    Stepper("Give up after \(plan.maxReArms) re-rings", value: $plan.maxReArms, in: 1...30)
                } header: {
                    Text("If you stop it without the mission")
                } footer: {
                    Text("Fail-safe so you never get stuck: after the limit, the alarm stops for good and the day doesn't count toward your streak.")
                }

                if !isNew {
                    Section {
                        Button("Delete alarm", role: .destructive) { confirmDelete = true }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(isNew ? "New alarm" : "Edit alarm")
            .paywallSheet(isPresented: $showPaywall)
            .sheet(isPresented: $showMissionPicker) {
                MissionPickerView(gate: gate) { plan.missions.append($0) }
            }
            .sheet(item: $editingMission) { editing in
                if let index = plan.missions.firstIndex(where: { $0.id == editing.id }) {
                    MissionEditSheet(config: $plan.missions[index]) {
                        plan.missions.removeAll { $0.id == editing.id }
                    }
                }
            }
            .confirmationDialog("Delete this alarm?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        plan.isEnabled = true
                        onSave(plan)
                        Task { _ = await PermissionCenter.shared.ensure(.alarms) }  // ask / explain if off
                        dismiss()
                    }
                    .disabled(!plan.isReady)
                }
            }
        }
    }
}

struct WeekdayPicker: View {
    @Binding var selection: Set<Int>
    private let symbols = Calendar.current.veryShortWeekdaySymbols

    var body: some View {
        HStack {
            ForEach(1...7, id: \.self) { day in
                let on = selection.contains(day)
                Button {
                    if on { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(symbols[day - 1])
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(on ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), in: .circle)
                        .foregroundStyle(on ? .white : .primary)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

