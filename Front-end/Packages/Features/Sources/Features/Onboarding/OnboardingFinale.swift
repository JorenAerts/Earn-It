import Coach
import Core
import SwiftUI

// MARK: - Building

/// "Getting your mornings ready": a counter and checklist while the alarm is really created.
struct BuildingStep: View {
    let answers: OnboardingAnswers
    /// Saves the alarm and applies the answers. Runs once; the step moves on when it's done
    /// and the animation has finished.
    let work: @MainActor () async -> Void
    let onNext: () -> Void

    @State private var percent = 0
    @State private var done = 0
    @State private var proof = SocialProof.load()

    private var tasks: [String] {
        let mission = answers.chosenMissions.first?.kind.displayName ?? "Math"
        return ["Setting your \(answers.timeText) alarm", "Loading \(mission)",
                "Adding your alarm sound", "Waking up \(CoachIdentity.name)"]
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 40)
            Text("\(percent)%")
                .font(.system(size: 88, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(percent)))
            Text("Getting your mornings ready").font(.title2.bold()).multilineTextAlignment(.center)
            ProgressView(value: Double(percent), total: 100).tint(.orange)
                .frame(maxWidth: 420)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(tasks.enumerated()), id: \.offset) { index, task in
                    HStack(spacing: 10) {
                        Image(systemName: index < done ? "checkmark.circle.fill" : "circle.dotted")
                            .foregroundStyle(index < done ? .green : .secondary)
                            .contentTransition(.symbolEffect(.replace))
                        Text(task).foregroundStyle(index < done ? .primary : .secondary)
                    }
                    .font(.body.weight(.medium))
                }
            }
            QuoteCarousel(proof: proof)
                .frame(maxWidth: 520)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .task { await run() }
        .accessibilityElement(children: .contain)
    }

    private func run() async {
        let saving = Task { @MainActor in await work() }
        // ~4 seconds of progress, one checklist item per quarter.
        for value in stride(from: 1, through: 100, by: 1) {
            try? await Task.sleep(for: .milliseconds(value < 90 ? 32 : 60))
            withAnimation(.snappy(duration: 0.2)) {
                percent = value
                done = min(tasks.count, value / 25)
            }
        }
        await saving.value
        try? await Task.sleep(for: .milliseconds(400))
        onNext()
    }
}

// MARK: - Summary

struct SummaryStep: View {
    let answers: OnboardingAnswers
    let onNext: () -> Void
    @State private var proof = SocialProof.load()
    @State private var appeared = false

    private var whenText: String {
        let plan = answers.firstAlarm()
        guard let next = plan.nextFireDate(after: .now) else { return "You'll be up at" }
        return Calendar.current.isDateInToday(next) ? "Today, you'll be up at"
            : Calendar.current.isDateInTomorrow(next) ? "Tomorrow, you'll be up at"
            : "\(next.formatted(.dateTime.weekday(.wide))), you'll be up at"
    }

    var body: some View {
        OnboardingPage {
            VStack(spacing: 20) {
                Image(systemName: "checkmark")
                    .font(.title.bold()).foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(Color.orange.gradient, in: .circle)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .padding(.top, 12)
                VStack(spacing: 4) {
                    Text(whenText).font(.title3).foregroundStyle(.secondary)
                    Text(answers.timeText)
                        .font(.system(size: 80, weight: .heavy, design: .rounded)).monospacedDigit()
                    Text(OnboardingPersonalization.goalLine(answers.goal)).font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
                timeline
                VStack(spacing: 12) {
                    Text("And every \(answers.weekdays.count == 7 ? "morning" : "alarm day") after.")
                        .font(.title3.bold())
                    WeekdayCircles(weekdays: answers.weekdays)
                    if let hours = OnboardingPersonalization.hoursBackPerWeek(answers.getUpTime, weekdays: answers.weekdays) {
                        Text(OnboardingPersonalization.hoursBackText(hours)).foregroundStyle(.secondary)
                    }
                }
                SocialProofView(proof: proof)
            }
            .frame(maxWidth: .infinity)
        } footer: {
            PrimaryButton(title: "I'm ready", action: onNext)
        }
        .onAppear { withAnimation(.spring(duration: 0.5, bounce: 0.4)) { appeared = true } }
    }

    private var timeline: some View {
        let mission = answers.chosenMissions.first?.kind ?? .math
        let steps: [(String, String)] = [
            ("bell.fill", "Alarm rings"),
            (mission.symbol, "Complete \(mission.displayName)"),
            ("checkmark", OnboardingPersonalization.finishLine(answers.goal)),
        ]
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 16) {
                    Image(systemName: step.0)
                        .font(.headline).foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.orange.gradient, in: .circle)
                    Text(step.1).font(.body.weight(.semibold))
                }
                if index < steps.count - 1 {
                    Rectangle().fill(Color.orange.opacity(0.35)).frame(width: 3, height: 22).padding(.leading, 20.5)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
    }
}
