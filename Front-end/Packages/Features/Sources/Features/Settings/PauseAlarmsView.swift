import AlarmEngine
import Core
import SwiftUI

/// Settings › Pause all alarms (vacation mode).
struct PauseAlarmsView: View {
    let coordinator: AlarmCoordinator
    @State private var choosingDate = false
    @State private var backOn = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var busy = false

    private var tomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now
    }

    var body: some View {
        List {
            if let pause = coordinator.activePause {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Alarms paused", systemImage: "pause.circle.fill")
                            .font(.headline).foregroundStyle(.indigo)
                        Text(Self.description(pause, coordinator: coordinator))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    Button("Resume alarms now") { run { await coordinator.resumeAll() } }
                        .disabled(busy)
                }
            }

            Section {
                option("Tomorrow only", .days(1))
                option("3 days", .days(3))
                option("1 week", .days(7))
                Button("Until a date…") { choosingDate.toggle() }
                if choosingDate {
                    DatePicker("Back on", selection: $backOn, in: tomorrow..., displayedComponents: .date)
                    Button("Pause until \(backOn.formatted(.dateTime.weekday(.wide).day().month()))") {
                        run { await coordinator.pauseAll(PausePolicy.pause(.untilDay(backOn), now: .now)) }
                    }
                    .fontWeight(.semibold)
                }
                option("Until I turn them back on", .indefinitely)
            } header: {
                Text(coordinator.activePause == nil ? "Pause for" : "Change pause")
            } footer: {
                Text("Paused days don't ring, don't send reminders and don't break your streak. Your alarms come back on their own afterwards, even if you don't open the app. An alarm that's ringing right now isn't affected.")
            }
        }
        .navigationTitle("Pause all alarms")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(busy)
    }

    private func option(_ title: String, _ option: PausePolicy.Option) -> some View {
        Button(title) {
            run { await coordinator.pauseAll(PausePolicy.pause(option, now: .now)) }
        }
    }

    private func run(_ action: @escaping @MainActor () async -> Void) {
        busy = true
        choosingDate = false
        Task {
            await action()
            busy = false
        }
    }

    /// "Back on Monday 18 November, first alarm 07:00."
    static func description(_ pause: AlarmPause, coordinator: AlarmCoordinator) -> String {
        guard let until = pause.until else { return "No alarm rings until you resume." }
        var text = "Back on " + until.formatted(.dateTime.weekday(.wide).day().month(.wide)) + "."
        if let next = coordinator.nextAlarm {
            text += " First alarm: " + next.date.formatted(.dateTime.weekday(.abbreviated).hour().minute()) + "."
        }
        return text
    }
}

/// Home: "Alarms paused · Resume" while a pause is active.
struct PauseBanner: View {
    let coordinator: AlarmCoordinator
    @State private var busy = false

    var body: some View {
        if let pause = coordinator.activePause {
            HStack(spacing: 12) {
                Image(systemName: "pause.circle.fill").font(.title2).foregroundStyle(.indigo)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Alarms paused").font(.headline)
                    Text(pause.until.map { "Back on " + $0.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) }
                         ?? "Until you resume")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Resume") {
                    busy = true
                    Task {
                        await coordinator.resumeAll()
                        busy = false
                    }
                }
                .buttonStyle(.bordered)
                .disabled(busy)
            }
            .accessibilityElement(children: .combine)
        }
    }
}
