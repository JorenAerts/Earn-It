import AlarmEngine
import Core
import SwiftUI
import UIKit

// MARK: - 1. Welcome

struct WelcomeStep: View {
    let onNext: () -> Void

    var body: some View {
        OnboardingPage {
            VStack(alignment: .leading, spacing: 20) {
                // App logo (App/Assets.xcassets/Logo). Clipped like an iOS app icon.
                Image("Logo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 112, height: 112)
                    .clipShape(.rect(cornerRadius: 25, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                    .padding(.top, 32)
                    .accessibilityHidden(true)
                Text("Earn It")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                Text("An alarm you can't snooze your way out of.")
                    .font(.title2.weight(.semibold))
                Text("Every morning starts with a small mission. Stopping the alarm without doing it just makes it ring again.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } footer: {
            PrimaryButton(title: "Get started", action: onNext)
        }
    }
}

// MARK: - 2. How it works

struct HowItWorksStep: View {
    let onNext: () -> Void

    private let items: [(symbol: String, title: String, text: String)] = [
        ("alarm.fill", "Your alarm rings", "Through silent mode and Focus, like a real alarm."),
        ("brain.head.profile", "Complete a mission", "Solve math, shake your phone or scan a code in another room."),
        ("checkmark.seal.fill", "Earn your morning", "Only a finished mission ends the alarm. Build a streak."),
    ]

    var body: some View {
        OnboardingPage {
            VStack(alignment: .leading, spacing: 28) {
                Text("How it works")
                    .font(.largeTitle.bold())
                ForEach(items, id: \.title) { item in
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: item.symbol)
                            .font(.title)
                            .foregroundStyle(.orange)
                            .frame(width: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.headline)
                            Text(item.text).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        } footer: {
            PrimaryButton(title: "Continue", action: onNext)
        }
    }
}

// MARK: - 3. Goals

struct GoalsStep: View {
    @Binding var answers: OnboardingAnswers
    let onNext: () -> Void

    private var time: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: answers.hour, minute: answers.minute, second: 0, of: .now) ?? .now },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                answers.hour = c.hour ?? 7
                answers.minute = c.minute ?? 0
            })
    }

    var body: some View {
        OnboardingPage {
            VStack(alignment: .leading, spacing: 24) {
                Text("Your mornings").font(.largeTitle.bold())

                VStack(alignment: .leading, spacing: 8) {
                    Text("When do you want to get up?").font(.headline)
                    DatePicker("Wake-up time", selection: time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    WeekdayPicker(selection: $answers.weekdays)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("What makes mornings hard?").font(.headline)
                    Text("Pick any — we'll suggest the right mission.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    ForEach(MorningStruggle.allCases) { struggle in
                        let selected = answers.struggles.contains(struggle)
                        Button {
                            if selected { answers.struggles.remove(struggle) } else { answers.struggles.insert(struggle) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: struggle.symbol).frame(width: 28)
                                Text(struggle.title)
                                Spacer()
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            }
                            .padding(14)
                            .foregroundStyle(selected ? Color.orange : Color.primary)
                            .background(selected ? Color.orange.opacity(0.12) : Color(.secondarySystemBackground),
                                        in: .rect(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
        } footer: {
            PrimaryButton(title: "Continue", action: onNext)
        }
    }
}

// MARK: - 5. Permissions

struct PermissionsStep: View {
    let coordinator: AlarmCoordinator
    let onNext: () -> Void
    @State private var status: AlarmAuthorization = .notDetermined
    @Environment(\.openURL) private var openURL

    var body: some View {
        OnboardingPage {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "alarm.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.orange)
                    .padding(.top, 24)
                Text("Allow alarms").font(.largeTitle.bold())
                Text("Earn It uses iOS alarms, so your wake-up rings through silent mode and Focus — even when the app is closed.")
                    .foregroundStyle(.secondary)
                if status == .denied {
                    Label("Alarms are turned off for Earn It. Without them your alarm can't ring.",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
                if status == .authorized {
                    Label("Alarms allowed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.headline)
                }
            }
        } footer: {
            switch status {
            case .authorized:
                PrimaryButton(title: "Continue", action: onNext)
            case .denied:
                PrimaryButton(title: "Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("Continue anyway", action: onNext).foregroundStyle(.secondary)
            case .notDetermined:
                PrimaryButton(title: "Allow alarms") {
                    Task { status = await coordinator.requestAuthorization() }
                }
            }
        }
        .onAppear { status = coordinator.authorization }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            status = coordinator.authorization  // back from Settings
        }
    }
}

// MARK: - 6. First alarm

struct FirstAlarmStep: View {
    @State var plan: AlarmPlan
    let onCreate: (AlarmPlan) -> Void
    @State private var customizing = false

    var body: some View {
        OnboardingPage {
            VStack(alignment: .leading, spacing: 20) {
                Text("Your first alarm").font(.largeTitle.bold())
                Text("Based on your answers. You can change everything later.")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    Text(plan.timeText)
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Label(plan.repeatText, systemImage: "calendar")
                    Label(plan.missions.map(\.kind.displayName).joined(separator: " + "), systemImage: "target")
                    Label(plan.sound.displayName, systemImage: "speaker.wave.2.fill")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 20))

                Button("Customize") { customizing = true }
            }
        } footer: {
            PrimaryButton(title: "Create alarm", disabled: !plan.isReady) { onCreate(plan) }
        }
        .sheet(isPresented: $customizing) {
            AlarmSetupView(plan: plan, isNew: true,
                           onSave: { plan = $0 },
                           onDelete: {})
        }
    }
}
