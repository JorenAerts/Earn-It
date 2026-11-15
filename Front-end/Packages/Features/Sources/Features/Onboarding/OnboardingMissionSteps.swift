import AlarmEngine
import Core
import Missions
import Permissions
import Purchases
import SwiftUI
import UIKit

// MARK: - Pick a mission

struct MissionStep: View {
    @Binding var answers: OnboardingAnswers
    let gate: FeatureGate
    let onNext: () -> Void

    private var selected: MissionKind { answers.chosenMissions.first?.kind ?? answers.suggestedMission }

    var body: some View {
        OnboardingPage(title: "Pick a mission to wake you up", subtitle: "You'll do this to turn off your alarm.") {
            VStack(spacing: 12) {
                ForEach(MissionKind.allCases) { kind in
                    ChoiceCard(title: kind.displayName,
                               subtitle: kind == answers.suggestedMission ? "Suggested for you · \(kind.estimatedDuration)" : kind.tagline,
                               symbol: kind.symbol,
                               selected: selected == kind,
                               badge: gate.isLocked(kind) ? "PRO" : nil) {
                        withAnimation(.snappy) { select(kind) }
                    }
                }
            }
            if MissionKind.allCases.contains(where: gate.isLocked) {
                Text("PRO missions are included in the free trial at the end. On the free plan your alarm uses Math.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            CoachBubble(line: OnboardingPersonalization.coachReaction(to: .mission, answers: answers) ?? "")
        } footer: {
            PrimaryButton(title: "Continue", action: onNext)
        }
        .onAppear { if answers.missions == nil { select(answers.suggestedMission) } }
    }

    private func select(_ kind: MissionKind) {
        guard answers.missions?.first?.kind != kind else { return }
        answers.missions = [MissionConfig(kind: kind)]
    }
}

// MARK: - Mission settings

struct MissionSetupStep: View {
    @Binding var answers: OnboardingAnswers
    let onNext: () -> Void

    private var config: Binding<MissionConfig> {
        Binding(
            get: { answers.chosenMissions.first ?? MissionConfig(kind: .math) },
            set: { answers.missions = [$0] })
    }

    var body: some View {
        let kind = config.wrappedValue.kind
        OnboardingPage(title: title(kind), subtitle: subtitle(kind)) {
            switch kind {
            case .math:
                mathSetup
            case .shake:
                countCard(label: "Shakes", range: kind.targetRange ?? 5...200, step: kind.targetStep)
            case .qr, .object:
                if let setup = MissionRegistry.setupView(for: config) {
                    setup
                        .padding(16)
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
                }
            }
        } footer: {
            if kind.needsPayload && !config.wrappedValue.isReady {
                PrimaryButton(title: "Continue", disabled: true) {}
                Button("Set up later (use Math for now)") {
                    answers.missions = [MissionConfig(kind: .math)]
                    onNext()
                }
                .foregroundStyle(.secondary)
            } else {
                PrimaryButton(title: "Continue", action: onNext)
            }
        }
    }

    private func title(_ kind: MissionKind) -> String {
        switch kind {
        case .math: "Set up your math"
        case .shake: "How hard should you shake?"
        case .qr: "Register your code"
        case .object: "Scan your item"
        }
    }

    private func subtitle(_ kind: MissionKind) -> String {
        switch kind {
        case .math: "Pick how hard the problems are, and how many you'll solve."
        case .shake: "More shakes, more awake."
        case .qr: "Print or pick any code and stick it somewhere out of bed, like the bathroom."
        case .object: "Something that's not in your bedroom: your toothbrush, coffee mug or shoes."
        }
    }

    private var mathSetup: some View {
        VStack(spacing: 12) {
            ForEach(MissionDifficulty.allCases) { level in
                let on = config.wrappedValue.difficulty == level
                Button {
                    withAnimation(.snappy) { config.wrappedValue.difficulty = level }
                } label: {
                    HStack {
                        Text(level.rawValue.capitalized).font(.headline)
                        Spacer()
                        Text(example(level)).font(.body.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .background(on ? Color.orange.opacity(0.14) : Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(on ? Color.orange : .clear, lineWidth: 2.5))
                    .contentShape(.rect)
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityHint("Example: \(example(level))")
            }
            countCard(label: "Problems in a row", range: MissionKind.math.targetRange ?? 1...20, step: 1)
        }
    }

    private func example(_ level: MissionDifficulty) -> String {
        switch level {
        case .easy: "5 + 9"
        case .medium: "5 × 8 + 7"
        case .hard: "17 × 9 − 46"
        }
    }

    private func countCard(label: String, range: ClosedRange<Int>, step: Int) -> some View {
        HStack {
            Text(label).font(.headline).foregroundStyle(.primary)
            Spacer()
            Button {
                config.wrappedValue.target = max(range.lowerBound, config.wrappedValue.target - step)
            } label: { Image(systemName: "minus.circle.fill").font(.system(size: 34)) }
                .disabled(config.wrappedValue.target <= range.lowerBound)
                .accessibilityLabel("Fewer")
            Text("\(config.wrappedValue.target)")
                .font(.title.bold().monospacedDigit())
                .frame(minWidth: 56)
                .contentTransition(.numericText())
                .animation(.snappy, value: config.wrappedValue.target)
            Button {
                config.wrappedValue.target = min(range.upperBound, config.wrappedValue.target + step)
            } label: { Image(systemName: "plus.circle.fill").font(.system(size: 34)) }
                .disabled(config.wrappedValue.target >= range.upperBound)
                .accessibilityLabel("More")
        }
        .foregroundStyle(.orange)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Sound

struct SoundStep: View {
    @Binding var answers: OnboardingAnswers
    let gate: FeatureGate
    let onNext: () -> Void
    @State private var preview = SoundPreview()

    var body: some View {
        OnboardingPage(title: "Pick your alarm sound", subtitle: "Tap to hear it. You can add your own sounds later.") {
            ForEach(AlarmSound.Category.allCases, id: \.self) { category in
                VStack(alignment: .leading, spacing: 8) {
                    Text(category.rawValue.uppercased())
                        .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    VStack(spacing: 0) {
                        let sounds = AlarmSound.allCases.filter { $0.category == category }
                        ForEach(sounds) { sound in
                            row(sound)
                            if sound != sounds.last { Divider().padding(.leading, 56) }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
                }
            }
        } footer: {
            PrimaryButton(title: "Continue") {
                preview.stop()
                onNext()
            }
        }
        .onDisappear { preview.stop() }
    }

    private func row(_ sound: AlarmSound) -> some View {
        let choice = SoundChoice.builtIn(sound)
        let selected = answers.sound == choice
        let locked = gate.isLocked(sound)
        return Button {
            preview.toggle(choice)
            answers.sound = choice
        } label: {
            HStack(spacing: 12) {
                Image(systemName: preview.playing == choice ? "speaker.wave.2.fill" : "play.circle.fill")
                    .font(.title2).foregroundStyle(.orange).frame(width: 32)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 1) {
                    Text(sound.displayName).foregroundStyle(.primary)
                    if sound == BonusUnlocks.inviteSound && locked {
                        Text("Unlock by inviting a friend").font(.caption).foregroundStyle(.secondary)
                    } else if let credit = sound.credit {
                        Text(credit).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if locked { ProBadge() }
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(selected ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.tertiary))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Invite a friend

struct InviteFriendStep: View {
    let store: StoreService
    @Binding var answers: OnboardingAnswers
    /// Website / App Store page (`shareURL` in Auth.json).
    let link: URL?
    let onNext: () -> Void
    @State private var sharing = false
    @State private var unlocked = false

    static let message = "I'm using Earn It: an alarm that keeps ringing until I'm actually out of bed. Want to be my wake-up buddy?"

    var body: some View {
        OnboardingPage {
            VStack(spacing: 22) {
                ZStack {
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(LinearGradient(colors: [.yellow.opacity(0.8), .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 170, height: 170)
                        .shadow(color: .orange.opacity(0.35), radius: 20, y: 10)
                    Image(systemName: unlocked ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 92, height: 92)
                        .background(.white, in: .circle)
                        .contentTransition(.symbolEffect(.replace))
                }
                .padding(.top, 24)
                .accessibilityHidden(true)
                Text(unlocked ? "Rise & Conquer unlocked!" : "Unlock an exclusive alarm sound")
                    .font(.largeTitle.bold()).multilineTextAlignment(.center)
                Text(unlocked ? "It's yours, free, forever. Want to use it as your alarm?"
                              : "Know someone who oversleeps? Send them Earn It and get Rise & Conquer, a brass fanfare that's not in the free plan.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                if !unlocked {
                    Text("We'll write the message for you.").font(.subheadline).foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
        } footer: {
            if unlocked {
                PrimaryButton(title: "Use Rise & Conquer") {
                    answers.sound = .builtIn(BonusUnlocks.inviteSound)
                    onNext()
                }
                Button("Keep my sound", action: onNext).foregroundStyle(.secondary)
            } else {
                PrimaryButton(title: "Text one friend") { sharing = true }
                Button("Skip", action: onNext).foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $sharing) {
            ShareSheet(items: [Self.message] + (link.map { [$0] } ?? [])) { completed in
                sharing = false
                if completed {
                    store.unlockInviteSound()
                    withAnimation(.snappy) { unlocked = true }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

/// `UIActivityViewController`, reporting whether something was actually shared.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let onFinish: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in onFinish(completed) }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
