import AlarmEngine
import Core
import Localization
import Missions
import Permissions
import Purchases
import SwiftUI
import Telemetry
import UIKit

// MARK: - Pick a mission

struct MissionStep: View {
    @Binding var answers: OnboardingAnswers
    /// Read live (not a captured gate), so a trial started from the sheet unlocks right away.
    let store: StoreService
    let onNext: () -> Void
    @Environment(\.paywall) private var paywall
    /// A locked mission the user tapped: the paywall is open for it.
    @State private var unlocking: PaywallUnlock?
    /// Same as `unlocking`, but survives until the sheet's onDismiss has run.
    @State private var pending: MissionKind?

    private var selected: MissionKind { answers.chosenMissions.first?.kind ?? .math }

    var body: some View {
        OnboardingPage(title: L10n.tr("Pick a mission to wake you up"), subtitle: L10n.tr("You'll do this to turn off your alarm.")) {
            VStack(spacing: 12) {
                ForEach(MissionKind.onboardingKinds) { kind in
                    ChoiceCard(title: kind.displayName,
                               subtitle: kind == answers.suggestedMission ? L10n.tr("Suggested for you · \(kind.estimatedDuration)") : kind.tagline,
                               symbol: kind.symbol,
                               selected: selected == kind,
                               badge: store.gate.isLocked(kind) ? "PRO" : nil) {
                        tapped(kind)
                    }
                }
            }
            if MissionKind.onboardingKinds.contains(where: store.gate.isLocked) {
                Text("PRO missions come with a free trial. Tap one to try it, or keep Math on the free plan.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Text("More missions, like memory match and tongue twisters, are waiting in the app.")
                .font(.footnote).foregroundStyle(.secondary)
            CoachBubble(line: OnboardingPersonalization.coachReaction(to: .mission, answers: answers) ?? "")
        } footer: {
            PrimaryButton(title: L10n.tr("Continue"), action: onNext)
        }
        .onAppear {
            // Pre-select the suggestion only when it's usable; a free user starts on Math.
            if answers.missions == nil {
                select(store.gate.isLocked(answers.suggestedMission) ? .math : answers.suggestedMission)
            } else if store.gate.isLocked(selected) {
                select(.math)  // e.g. back from a later step after the trial ended
            }
        }
        .sheet(item: $unlocking, onDismiss: unlockSheetClosed) { unlock in
            if let paywall {
                PaywallView(store: paywall.store, mode: .sheet, source: .lockedMission, accountToken: paywall.accountToken, unlocking: unlock) { unlocking = nil }
            }
        }
    }

    /// Free missions select straight away; a PRO one opens the trial paywall first.
    private func tapped(_ kind: MissionKind) {
        if store.gate.isLocked(kind) {
            pending = kind
            unlocking = .mission(kind)
        } else {
            withAnimation(.snappy) { select(kind) }
        }
    }

    /// Trial started → keep the tapped mission. "Not now" / closed → Math.
    private func unlockSheetClosed() {
        guard let kind = pending else { return }
        pending = nil
        withAnimation(.snappy) { select(store.gate.isLocked(kind) ? .math : kind) }
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
                countCard(label: L10n.tr("Shakes"), range: kind.targetRange ?? 5...200, step: kind.targetStep)
            case .quiz:
                VStack(spacing: 12) {
                    QuizTopicGrid(topic: config.quizTopic)
                    countCard(label: L10n.tr("Correct answers"), range: kind.targetRange ?? 1...10, step: 1)
                }
            case .memory, .typing:
                VStack(spacing: 12) {
                    difficultyCards
                    if kind == .typing {
                        countCard(label: L10n.tr("Tongue twisters"), range: kind.targetRange ?? 1...5, step: 1)
                    }
                }
            case .qr, .object, .sky, .bed, .colorHunt:
                if let setup = MissionRegistry.setupView(for: config) {
                    setup
                        .padding(16)
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
                }
            }
        } footer: {
            if kind.needsPayload && !config.wrappedValue.isReady {
                PrimaryButton(title: L10n.tr("Continue"), disabled: true) {}
                Button("Set up later (use Math for now)") {
                    answers.missions = [MissionConfig(kind: .math)]
                    onNext()
                }
                .foregroundStyle(.secondary)
            } else {
                PrimaryButton(title: L10n.tr("Continue"), action: onNext)
            }
        }
    }

    private func title(_ kind: MissionKind) -> String {
        switch kind {
        case .math: L10n.tr("Set up your math problems")
        case .shake: L10n.tr("How hard should you shake?")
        case .qr: L10n.tr("Register your code")
        case .object: L10n.tr("Scan your item")
        case .quiz: L10n.tr("Pick your quiz")
        case .memory: L10n.tr("How big is the board?")
        case .typing: L10n.tr("Set up your tongue twisters")
        case .sky, .bed, .colorHunt: kind.displayName
        }
    }

    private func subtitle(_ kind: MissionKind) -> String {
        switch kind {
        case .math: L10n.tr("Pick how hard the problems are, and how many you'll solve.")
        case .shake: L10n.tr("More shakes, more awake.")
        case .qr: L10n.tr("Print a code or use one you already have, and stick it far from your bed, like in the bathroom.")
        case .object: L10n.tr("Something that's not in your bedroom: your toothbrush, coffee mug or shoes.")
        case .quiz: L10n.tr("Pick a topic and how many right answers it takes.")
        case .memory: L10n.tr("More pairs, more brain power.")
        case .typing: L10n.tr("Longer twisters on harder levels.")
        case .sky, .bed, .colorHunt: kind.tagline
        }
    }

    private var mathSetup: some View {
        VStack(spacing: 12) {
            difficultyCards
            countCard(label: L10n.tr("Problems in a row"), range: MissionKind.math.targetRange ?? 1...20, step: 1)
        }
    }

    private var difficultyCards: some View {
        VStack(spacing: 12) {
            ForEach(MissionDifficulty.allCases) { level in
                let on = config.wrappedValue.difficulty == level
                Button {
                    withAnimation(.snappy) { config.wrappedValue.difficulty = level }
                } label: {
                    HStack {
                        Text(level.title).font(.headline)
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
        }
    }

    private func example(_ level: MissionDifficulty) -> String {
        var c = config.wrappedValue
        c.difficulty = level
        switch c.kind {
        case .memory: return L10n.tr("\(c.memoryPairs) pairs")
        case .typing:
            switch level {
            case .easy: return L10n.tr("Short")
            case .medium: return L10n.tr("Medium length")
            case .hard: return L10n.tr("Long")
            }
        default:
            switch level {
            case .easy: return "5 + 9"
            case .medium: return "5 × 8 + 7"
            case .hard: return "17 × 9 − 46"
            }
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
    /// Read live (not a captured gate), so a trial started from the sheet unlocks right away.
    let store: StoreService
    let onNext: () -> Void
    @State private var preview = SoundPreview()
    @Environment(\.paywall) private var paywall
    /// The locked sound the paywall is open for (after Continue).
    @State private var unlocking: PaywallUnlock?
    /// "Not now, use Classic Beep" was tapped (vs. closing the sheet).
    @State private var declined = false

    private var gate: FeatureGate { store.gate }

    var body: some View {
        OnboardingPage(title: L10n.tr("Pick your alarm sound"), subtitle: L10n.tr("Tap to hear it. You can add your own sounds later.")) {
            ForEach(AlarmSound.Category.allCases, id: \.self) { category in
                VStack(alignment: .leading, spacing: 8) {
                    Text(category.title.uppercased(with: L10n.locale))
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
            if answers.soundNeedsPaywall(gate: gate), case .builtIn(let sound) = answers.sound {
                Label(L10n.tr("\(sound.displayName) is a Pro sound. Continue to try it free, or pick Classic Beep."),
                      systemImage: "lock.fill")
                    .font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
            PrimaryButton(title: L10n.tr("Continue"), action: continueTapped)
        }
        .animation(.snappy, value: answers.sound)
        .onDisappear { preview.stop() }
        .sheet(item: $unlocking, onDismiss: unlockSheetClosed) { unlock in
            if let paywall {
                PaywallView(store: paywall.store, mode: .sheet, source: .lockedSound, accountToken: paywall.accountToken, unlocking: unlock,
                            onDecline: {
                                declined = true
                                unlocking = nil
                            }) { unlocking = nil }
            }
        }
    }

    /// Previews are free; a PRO sound only asks for the trial when the user moves on with it.
    /// Rise & Conquer goes on to the invite step, which unlocks it for free.
    private func continueTapped() {
        preview.stop()
        if answers.soundNeedsPaywall(gate: gate), case .builtIn(let sound) = answers.sound {
            declined = false
            unlocking = .sound(sound)
        } else {
            onNext()
        }
    }

    /// Trial started → keep the sound and move on. "Not now" → Classic Beep and move on.
    /// Closed (X / swipe) → stay here with Classic Beep selected, so Continue doesn't loop.
    private func unlockSheetClosed() {
        if !gate.isLocked(answers.sound) {
            onNext()
        } else {
            answers.sound = .classic
            if declined { onNext() }
        }
        declined = false
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

    static let message = L10n.tr("I'm using Gloop: an alarm that keeps ringing until I'm actually out of bed. Want to be my wake-up buddy?")

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
                Text(unlocked ? L10n.tr("Rise & Conquer unlocked!") : L10n.tr("Unlock an exclusive alarm sound"))
                    .font(.largeTitle.bold()).multilineTextAlignment(.center)
                Text(unlocked ? "It's yours, free, forever. Want to use it as your alarm?"
                              : "Know someone who oversleeps? Send them Gloop and get Rise & Conquer, a brass fanfare that's not in the free plan.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                if !unlocked {
                    Text("We'll write the message for you.").font(.subheadline).foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
        } footer: {
            if unlocked {
                PrimaryButton(title: L10n.tr("Use Rise & Conquer")) {
                    answers.sound = .builtIn(BonusUnlocks.inviteSound)
                    onNext()
                }
                Button("Keep my sound", action: onNext).foregroundStyle(.secondary)
            } else {
                PrimaryButton(title: L10n.tr("Text one friend")) { sharing = true }
                Button("Skip", action: onNext).foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $sharing) {
            ShareSheet(items: [Self.message] + (link.map { [$0] } ?? [])) { completed in
                sharing = false
                Telemetry.shared.send(.onboardingInviteShared(completed: completed))
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

/// Quiz topics as tappable tiles (onboarding).
struct QuizTopicGrid: View {
    @Binding var topic: QuizTopic

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(QuizTopic.allCases) { t in
                let on = t == topic
                Button { withAnimation(.snappy) { topic = t } } label: {
                    Label(t.title, systemImage: t.symbol)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(on ? Color.orange.opacity(0.14) : Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(on ? Color.orange : .clear, lineWidth: 2.5))
                        .contentShape(.rect)
                }
                .buttonStyle(PressableStyle())
                .foregroundStyle(.primary)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}
