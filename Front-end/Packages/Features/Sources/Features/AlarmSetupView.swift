import Core
import Missions
import SwiftUI

struct AlarmSetupView: View {
    @State var plan: AlarmPlan
    let onSave: (AlarmPlan) -> Void
    @Environment(\.dismiss) private var dismiss

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

                Section("Repeat") {
                    WeekdayPicker(selection: $plan.weekdays)
                }

                Section("Missions") {
                    ForEach($plan.missions) { $mission in
                        MissionConfigRow(mission: $mission)
                    }
                    .onDelete { plan.missions.remove(atOffsets: $0) }
                    Menu("Add mission") {
                        ForEach(MissionKind.allCases) { kind in
                            Button(kind.displayName) { plan.missions.append(MissionConfig(kind: kind)) }
                        }
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
            }
            .navigationTitle("Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        plan.isEnabled = true
                        onSave(plan)
                        dismiss()
                    }
                    .disabled(!plan.isReady)
                }
            }
        }
    }
}

private struct MissionConfigRow: View {
    @Binding var mission: MissionConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mission.kind.displayName).font(.headline)
            if mission.kind.usesDifficulty {
                Picker("Difficulty", selection: $mission.difficulty) {
                    ForEach(MissionDifficulty.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            if let range = mission.kind.targetRange {
                Stepper("\(mission.target) \(mission.kind.targetLabel)", value: $mission.target,
                        in: range, step: mission.kind.targetStep)
            }
            if let setup = MissionRegistry.setupView(for: $mission) {
                setup
            }
        }
        .padding(.vertical, 4)
    }
}

private struct WeekdayPicker: View {
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
