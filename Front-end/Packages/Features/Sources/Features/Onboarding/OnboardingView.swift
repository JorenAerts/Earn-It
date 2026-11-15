import Account
import AlarmEngine
import Coach
import Core
import Permissions
import Purchases
import SwiftUI

/// Full-screen onboarding: personal questions → guided first alarm → summary → paywall.
/// Progress (step + answers) is saved after every change, so a killed app resumes.
struct OnboardingView: View {
    let coordinator: AlarmCoordinator
    let auth: any AuthService
    let store: StoreService
    let onboardingStore: OnboardingStore
    let onFinish: () -> Void

    @State private var progress: OnboardingProgress
    @State private var goingBack = false
    @State private var showSignIn = false

    init(coordinator: AlarmCoordinator, auth: any AuthService, store: StoreService,
         onboardingStore: OnboardingStore, onFinish: @escaping () -> Void) {
        self.coordinator = coordinator
        self.auth = auth
        self.store = store
        self.onboardingStore = onboardingStore
        self.onFinish = onFinish
        var initial = onboardingStore.load()
        #if DEBUG
        // Screenshot helper: -onboardingStep <name> opens that step.
        if let i = CommandLine.arguments.firstIndex(of: "-onboardingStep"), i + 1 < CommandLine.arguments.count,
           let step = OnboardingStep(rawValue: CommandLine.arguments[i + 1]) {
            initial.step = step
        }
        #endif
        _progress = State(initialValue: initial)
    }

    private var context: OnboardingContext {
        OnboardingContext(accountsAvailable: auth.isAvailable, isSignedIn: auth.user != nil,
                          isPro: store.entitlement.isPro, bonusSoundUnlocked: store.bonusSounds.contains(BonusUnlocks.inviteSound))
    }

    var body: some View {
        VStack(spacing: 0) {
            if !progress.step.isFullScreen { header }
            ZStack {
                stepView
                    .id(progress.step)
                    .transition(.asymmetric(
                        insertion: .move(edge: goingBack ? .leading : .trailing).combined(with: .opacity),
                        removal: .move(edge: goingBack ? .trailing : .leading).combined(with: .opacity)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .onChange(of: progress) { _, new in onboardingStore.save(new) }
        .onChange(of: auth.user) { _, user in
            guard user != nil else { return }
            showSignIn = false
            // Signed in from the account step (incl. OAuth / email link): move on.
            if progress.step == .account { advance() }
        }
        .sheet(isPresented: $showSignIn) {
            AccountStepView(auth: auth, skipTitle: "Not now") { showSignIn = false }
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: Header (back + progress)

    private var header: some View {
        let canGoBack = OnboardingFlow.previous(before: progress.step, context) != nil
        return HStack(spacing: 14) {
            Button(action: back) {
                Image(systemName: "chevron.left").font(.headline)
                    .frame(width: 44, height: 44)
                    .background(Color(.secondarySystemGroupedBackground), in: .circle)
            }
            .buttonStyle(.plain)
            .opacity(canGoBack ? 1 : 0)
            .disabled(!canGoBack)
            .accessibilityLabel("Back")

            ProgressView(value: OnboardingFlow.fraction(at: progress.step, context))
                .tint(.orange)
                .animation(.snappy, value: progress.step)
                .accessibilityLabel("Onboarding progress")
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: Steps

    @ViewBuilder
    private var stepView: some View {
        let answers = $progress.answers
        switch progress.step {
        case .welcome:
            WelcomeStep(canSignIn: auth.isAvailable && auth.user == nil, onSignIn: { showSignIn = true }, onNext: advance)
        case .name:
            NameStep(answers: answers, onNext: advance)
        case .ageRange:
            SingleChoiceStep(title: "What's your age range?", subtitle: "Helps us build Earn It for people like you.",
                             options: AgeRange.allCases, selection: answers.ageRange,
                             label: \.title, symbol: \.symbol, onNext: advance)
        case .heardFrom:
            SingleChoiceStep(title: "Where did you hear about us?", options: HeardFrom.allCases,
                             selection: answers.heardFrom, label: \.title, symbol: \.symbol,
                             coachLine: OnboardingPersonalization.coachReaction(to: .heardFrom, answers: progress.answers),
                             onNext: advance)
        case .alarmReaction:
            SingleChoiceStep(title: "What goes through your head when your alarm rings?",
                             options: AlarmReaction.allCases, selection: answers.reaction,
                             label: \.title, symbol: \.symbol,
                             coachLine: OnboardingPersonalization.coachReaction(to: .alarmReaction, answers: progress.answers),
                             onNext: advance)
        case .whyItWorks:
            WhyItWorksStep(onNext: advance)
        case .getUpTime:
            SingleChoiceStep(title: "How much time until you actually get up?", options: GetUpTime.allCases,
                             selection: answers.getUpTime, label: \.title, symbol: \.symbol,
                             coachLine: OnboardingPersonalization.coachReaction(to: .getUpTime, answers: progress.answers),
                             onNext: advance)
        case .struggles:
            StrugglesStep(answers: answers, onNext: advance)
        case .goal:
            SingleChoiceStep(title: "What would you do with that time back?", options: MorningGoal.allCases,
                             selection: answers.goal, label: \.title, symbol: \.symbol,
                             coachLine: OnboardingPersonalization.coachReaction(to: .goal, answers: progress.answers),
                             onNext: advance)
        case .wakeTime:
            WakeTimeStep(answers: answers, onNext: advance)
        case .comparison:
            ComparisonStep(answers: progress.answers, onNext: advance)
        case .permissions:
            PermissionsStep(answers: progress.answers, onNext: advance)
        case .mission:
            MissionStep(answers: answers, gate: store.gate, onNext: advance)
        case .missionSetup:
            MissionSetupStep(answers: answers, onNext: advance)
        case .sound:
            SoundStep(answers: answers, gate: store.gate, onNext: advance)
        case .inviteFriend:
            InviteFriendStep(store: store, answers: answers, link: auth.config.shareURL, onNext: advance)
        case .account:
            AccountStepView(auth: auth, onSkip: advance)
        case .building:
            BuildingStep(answers: progress.answers, work: applyAnswers, onNext: advance)
        case .summary:
            SummaryStep(answers: progress.answers, onNext: advance)
        case .paywall:
            PaywallView(store: store, mode: .onboarding, accountToken: auth.user?.id,
                        termsURL: auth.config.termsURL, privacyURL: auth.config.privacyURL,
                        onFinish: advance)
        }
    }

    // MARK: Applying the answers

    /// Creates (or, when replaying, updates) the first alarm and applies the personal settings.
    private func applyAnswers() async {
        let answers = progress.answers
        let plan = answers.firstAlarm()
        await coordinator.save(plan)
        progress.answers.createdPlanID = plan.id

        CoachModel.shared.intensity = OnboardingPersonalization.suggestedTone(answers.reaction)
        let name = answers.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { ProfileName.shared.set(name) }
        if PermissionCenter.shared.isGranted(.notifications) { CoachModel.shared.notifications.enabled = true }
        await CoachNotifier.shared.refresh(coordinator: coordinator)
        syncProfile()
    }

    private func syncProfile() {
        guard auth.user != nil else { return }
        let a = progress.answers
        let goal = ProfileUpdate.WakeGoal(hour: a.hour, minute: a.minute, weekdays: a.weekdays.sorted(),
                                          struggles: a.struggles.map(\.rawValue).sorted())
        var info: [String: String] = [:]
        info["age_range"] = a.ageRange?.rawValue
        info["heard_from"] = a.heardFrom?.rawValue
        info["alarm_reaction"] = a.reaction?.rawValue
        info["get_up_time"] = a.getUpTime?.rawValue
        info["goal"] = a.goal?.rawValue
        let name = a.name.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await auth.updateProfile(ProfileUpdate(displayName: name.isEmpty ? nil : name, wakeGoal: goal,
                                                   onboarding: info))
        }
    }

    // MARK: Navigation

    private func advance() {
        goingBack = false
        // Answers given before signing in reach the profile once an account exists.
        if progress.step == .account || progress.step == .summary { syncProfile() }
        guard let next = OnboardingFlow.next(after: progress.step, context) else {
            progress.completed = true
            onFinish()
            return
        }
        withAnimation(.snappy) { progress.step = next }
    }

    private func back() {
        guard let previous = OnboardingFlow.previous(before: progress.step, context) else { return }
        goingBack = true
        withAnimation(.snappy) { progress.step = previous }
    }
}
