import AlarmEngine
import Coach
import Core
import Permissions
import SwiftUI
import UIKit

// MARK: - Welcome

struct WelcomeStep: View {
    let canSignIn: Bool
    let onSignIn: () -> Void
    let onNext: () -> Void

    private let points: [(String, String)] = [
        ("alarm.fill", "An alarm that keeps ringing until you're up"),
        ("brain.head.profile", "A quick mission proves you're awake"),
        ("flame.fill", "Streaks, evolutions and buddies keep you going"),
    ]

    var body: some View {
        OnboardingPage {
            VStack(spacing: 22) {
                CoachAvatarView(state: CoachState(mood: .proud, context: .idle), size: 150, vitality: 0.95)
                    .padding(.top, 20)
                Text("Waking up,\nearned.")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(points, id: \.1) { symbol, text in
                        HStack(spacing: 14) {
                            Image(systemName: symbol).font(.title3).foregroundStyle(.orange).frame(width: 30)
                            Text(text).font(.body.weight(.medium))
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
                CoachBubble(line: OnboardingPersonalization.coachReaction(to: .welcome, answers: OnboardingAnswers()) ?? "")
            }
            .frame(maxWidth: .infinity)
        } footer: {
            PrimaryButton(title: "Get started", action: onNext)
            if canSignIn {
                HStack(spacing: 4) {
                    Text("Already have an account?").foregroundStyle(.secondary)
                    Button("Sign in", action: onSignIn).fontWeight(.semibold)
                }
                .font(.subheadline)
            }
        }
    }
}

// MARK: - Name

struct NameStep: View {
    @Binding var answers: OnboardingAnswers
    let onNext: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        OnboardingPage(title: "What should \(CoachIdentity.name) call you?",
                       subtitle: "Your first name or a nickname. Used in your coach's lines and your profile.") {
            TextField("Your name", text: $answers.name)
                .font(.title2.weight(.semibold))
                .textContentType(.givenName)
                .submitLabel(.continue)
                .focused($focused)
                .padding(18)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
                .onSubmit(onNext)
            CoachBubble(line: OnboardingPersonalization.coachReaction(to: .name, answers: answers) ?? "",
                        mood: answers.name.isEmpty ? .suspicious : .proud)
        } footer: {
            PrimaryButton(title: "Continue", disabled: answers.name.trimmingCharacters(in: .whitespaces).isEmpty,
                          action: onNext)
            Button("Skip") {
                answers.name = ""
                onNext()
            }
            .foregroundStyle(.secondary)
        }
        .onAppear { focused = answers.name.isEmpty }
    }
}

// MARK: - Multi-select: what keeps you in bed

struct StrugglesStep: View {
    @Binding var answers: OnboardingAnswers
    let onNext: () -> Void

    var body: some View {
        OnboardingPage(title: "What keeps you in bed after your alarm?", subtitle: "Pick everything that sounds like you.") {
            VStack(spacing: 12) {
                ForEach(MorningStruggle.choices) { struggle in
                    let on = answers.struggles.contains(struggle)
                    ChoiceCard(title: struggle.title, symbol: struggle.symbol, selected: on, multiSelect: true) {
                        withAnimation(.snappy) {
                            if on { answers.struggles.remove(struggle) } else { answers.struggles.insert(struggle) }
                        }
                    }
                }
            }
            if !answers.struggles.isEmpty, let line = OnboardingPersonalization.coachReaction(to: .struggles, answers: answers) {
                CoachBubble(line: line, mood: .suspicious)
            }
        } footer: {
            PrimaryButton(title: "Continue", disabled: answers.struggles.isEmpty, action: onNext)
        }
    }
}

// MARK: - Why it works

struct WhyItWorksStep: View {
    let onNext: () -> Void

    var body: some View {
        OnboardingPage(title: "Gloop gets you out of bed and wide awake") {
            EnergyChart()
            Text("Snoozing drops you back into sleep you can't finish, so every extra ring tends to leave you groggier. One alarm and a short mission gets your brain and body going at once.")
                .font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } footer: {
            PrimaryButton(title: "Continue", action: onNext)
        }
    }
}

// MARK: - Wake-up time

struct WakeTimeStep: View {
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
        OnboardingPage(title: "What time do you want to be up?") {
            VStack(spacing: 6) {
                Text(answers.timeText)
                    .font(.system(size: 76, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: answers.timeText)
                DatePicker("Wake-up time", selection: time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 10) {
                Text("On these days").font(.headline)
                WeekdayPicker(selection: $answers.weekdays)
            }
            CoachBubble(line: OnboardingPersonalization.coachReaction(to: .wakeTime, answers: answers) ?? "")
        } footer: {
            PrimaryButton(title: "Continue", disabled: answers.weekdays.isEmpty, action: onNext)
        }
    }
}

// MARK: - Comparison

struct ComparisonStep: View {
    let answers: OnboardingAnswers
    let onNext: () -> Void

    var body: some View {
        OnboardingPage(title: "Let's get you out of bed",
                       subtitle: "No more stacking alarms. One alarm that doesn't give up.") {
            AlarmComparison(hour: answers.hour, minute: answers.minute)
        } footer: {
            PrimaryButton(title: "Continue", action: onNext)
        }
    }
}

// MARK: - Permissions

/// Alarms (required) + Notifications (recommended). Camera / microphone / Apple Music are asked the
/// moment a feature needs them.
struct PermissionsStep: View {
    let answers: OnboardingAnswers
    let onNext: () -> Void
    @State private var center = PermissionCenter.shared

    var body: some View {
        OnboardingPage {
            VStack(spacing: 26) {
                Text("Make sure your \(answers.timeText) alarm rings")
                    .font(.largeTitle.bold()).multilineTextAlignment(.center)
                    .padding(.top, 20)
                HStack(spacing: 22) {
                    badge("Alarms", symbol: "alarm.fill", tint: .orange, kind: .alarms)
                    badge("Notifications", symbol: "bell.badge.fill", tint: .red, kind: .notifications)
                }
                PermissionIllustration()
                    .padding(.bottom, 30)
                Text("Alarms ring through silent mode and Focus. Notifications bring \(CoachIdentity.name)'s evening reminders.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        } footer: {
            if center.isGranted(.alarms) {
                PrimaryButton(title: "Continue", action: onNext)
            } else if center.status(.alarms) == .denied {
                PrimaryButton(title: "Open Settings") { center.openSettings(.alarms) }
                Button("Continue anyway", action: onNext).foregroundStyle(.secondary)
            } else {
                PrimaryButton(title: "Allow") { Task { await requestAll() } }
            }
        }
        .task { await center.refresh() }
    }

    private func requestAll() async {
        await center.request(.alarms)
        if center.status(.notifications) == .notDetermined {
            await center.request(.notifications)
        }
        if center.isGranted(.notifications) { CoachModel.shared.notifications.enabled = true }
        if center.isGranted(.alarms) { onNext() }
    }

    private func badge(_ title: String, symbol: String, tint: Color, kind: PermissionKind) -> some View {
        HStack(spacing: 8) {
            Image(systemName: center.isGranted(kind) ? "checkmark" : symbol)
                .font(.headline).foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background((center.isGranted(kind) ? Color.green : tint).gradient, in: .rect(cornerRadius: 9))
                .contentTransition(.symbolEffect(.replace))
            Text(title).font(.headline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(center.status(kind).label)
    }
}
