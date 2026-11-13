import Account
import AlarmEngine
import Core
import Purchases
import SwiftUI

/// Full-screen onboarding: welcome → how it works → goals → account → permissions →
/// first alarm → paywall. Progress is saved after every step.
struct OnboardingView: View {
    let coordinator: AlarmCoordinator
    let auth: any AuthService
    let store: StoreService
    let onboardingStore: OnboardingStore
    let onFinish: () -> Void

    @State private var progress: OnboardingProgress
    @State private var goingBack = false

    init(coordinator: AlarmCoordinator, auth: any AuthService, store: StoreService,
         onboardingStore: OnboardingStore, onFinish: @escaping () -> Void) {
        self.coordinator = coordinator
        self.auth = auth
        self.store = store
        self.onboardingStore = onboardingStore
        self.onFinish = onFinish
        _progress = State(initialValue: onboardingStore.load())
    }

    private var context: OnboardingContext {
        OnboardingContext(accountsAvailable: auth.isAvailable, isSignedIn: auth.user != nil,
                          isPro: store.entitlement.isPro)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                stepView
                    .id(progress.step)
                    .transition(.asymmetric(
                        insertion: .move(edge: goingBack ? .leading : .trailing).combined(with: .opacity),
                        removal: .move(edge: goingBack ? .trailing : .leading).combined(with: .opacity)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemBackground))
        .onChange(of: progress) { _, new in onboardingStore.save(new) }
        .onChange(of: auth.user) { _, user in
            // Signed in from the account step (incl. OAuth / email link): move on.
            if user != nil, progress.step == .account { advance() }
        }
    }

    // MARK: Header (back + progress)

    private var header: some View {
        let steps = OnboardingFlow.visibleSteps(context)
        let index = steps.firstIndex(of: progress.step) ?? 0
        return HStack(spacing: 12) {
            Button {
                back()
            } label: {
                Image(systemName: "chevron.left").font(.headline)
                    .frame(width: 44, height: 44)
            }
            .opacity(OnboardingFlow.previous(before: progress.step, context) == nil ? 0 : 1)
            .disabled(OnboardingFlow.previous(before: progress.step, context) == nil)
            .accessibilityLabel("Back")

            ProgressView(value: Double(index + 1), total: Double(max(steps.count, 1)))
                .tint(.orange)
                .accessibilityLabel("Step \(index + 1) of \(steps.count)")
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
    }

    // MARK: Steps

    @ViewBuilder
    private var stepView: some View {
        switch progress.step {
        case .welcome:
            WelcomeStep(onNext: advance)
        case .howItWorks:
            HowItWorksStep(onNext: advance)
        case .goals:
            GoalsStep(answers: $progress.answers, onNext: advance)
        case .account:
            AccountStepView(auth: auth, onSkip: advance)
        case .permissions:
            PermissionsStep(coordinator: coordinator, onNext: advance)
        case .firstAlarm:
            FirstAlarmStep(plan: progress.answers.firstAlarm()) { plan in
                Task {
                    await coordinator.save(plan)
                    advance()
                }
            }
        case .paywall:
            OnboardingPaywallStep(store: store, accountToken: auth.user?.id, onNext: advance)
        }
    }

    // MARK: Navigation

    private func advance() {
        if auth.user != nil {
            let a = progress.answers
            let goal = ProfileUpdate.WakeGoal(hour: a.hour, minute: a.minute, weekdays: a.weekdays.sorted(),
                                              struggles: a.struggles.map(\.rawValue).sorted())
            Task { await auth.updateProfile(ProfileUpdate(wakeGoal: goal)) }
        }
        goingBack = false
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

/// Shared step layout: scrollable content, primary button pinned to the bottom.
struct OnboardingPage<Content: View, Footer: View>: View {
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                content
                    .frame(maxWidth: 560, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(spacing: 12) { footer }
                .frame(maxWidth: 560)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .padding(.top, 8)
        }
    }
}

struct PrimaryButton: View {
    let title: String
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(.orange)
        .disabled(disabled)
    }
}
