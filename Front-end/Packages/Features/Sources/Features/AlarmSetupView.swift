import AlarmEngine
import Core
import Missions
import Purchases
import SwiftUI

struct AlarmSetupView: View {
    @State var plan: AlarmPlan
    let isNew: Bool
    let onSave: (AlarmPlan) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var preview = SoundPreview()
    @State private var confirmDelete = false
    @State private var showPaywall = false
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
                    ForEach(AlarmSound.allCases) { sound in
                        SoundRow(sound: sound,
                                 isSelected: plan.sound == sound,
                                 isPlaying: preview.playing == sound,
                                 isLocked: gate.isLocked(sound)) {
                            preview.toggle(sound)
                            if gate.isLocked(sound) {
                                showPaywall = true
                            } else {
                                plan.sound = sound
                            }
                        }
                    }
                } header: {
                    Text("Sound")
                } footer: {
                    Text("The same sound keeps playing in the app until your mission is done. Tap to preview.")
                }

                Section("Missions") {
                    ForEach($plan.missions) { $mission in
                        MissionConfigRow(mission: $mission)
                    }
                    .onDelete { plan.missions.remove(atOffsets: $0) }
                    Menu("Add mission") {
                        ForEach(MissionKind.allCases) { kind in
                            if gate.isLocked(kind) {
                                Button { showPaywall = true } label: {
                                    Label("\(kind.displayName) — Pro", systemImage: "lock.fill")
                                }
                            } else {
                                Button(kind.displayName) { plan.missions.append(MissionConfig(kind: kind)) }
                            }
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

                if !isNew {
                    Section {
                        Button("Delete alarm", role: .destructive) { confirmDelete = true }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(isNew ? "New alarm" : "Edit alarm")
            .onDisappear { preview.stop() }
            .paywallSheet(isPresented: $showPaywall)
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

private struct SoundRow: View {
    let sound: AlarmSound
    let isSelected: Bool
    let isPlaying: Bool
    var isLocked = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                    .foregroundStyle(.tint)
                    .frame(width: 24)
                Text(sound.displayName).foregroundStyle(.primary)
                Spacer()
                if isLocked { ProBadge() }
                if isSelected {
                    Image(systemName: "checkmark").foregroundStyle(.tint).fontWeight(.semibold)
                }
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Plays a few seconds of a tone in the editor. Tapping the playing tone stops it.
@MainActor
@Observable
final class SoundPreview {
    private(set) var playing: AlarmSound?
    @ObservationIgnored private let player = AlarmSoundPlayer()
    @ObservationIgnored private var stopTask: Task<Void, Never>?

    func toggle(_ sound: AlarmSound) {
        if playing == sound {
            stop()
            return
        }
        playing = sound
        player.start(sound)
        stopTask?.cancel()
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    func stop() {
        stopTask?.cancel()
        player.stop()
        playing = nil
    }
}
