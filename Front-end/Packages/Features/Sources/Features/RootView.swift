import Account
import AlarmEngine
import Coach
import Core
import Purchases
import SwiftData
import SwiftUI

/// Routes between onboarding, the forced mission screen, and home.
public struct RootView: View {
    @Bindable var coordinator: AlarmCoordinator
    let auth: any AuthService
    let store: StoreService
    let onboardingStore: OnboardingStore
    @State private var onboarded: Bool
    private let notices = DowngradeNotices()
    @State private var noticeMessages: [String] = []
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @State private var showSuccess = false

    public init(coordinator: AlarmCoordinator, auth: any AuthService, store: StoreService,
                onboardingStore: OnboardingStore = OnboardingStore()) {
        self.coordinator = coordinator
        self.auth = auth
        self.store = store
        self.onboardingStore = onboardingStore
        _onboarded = State(initialValue: onboardingStore.load().completed)
    }

    public var body: some View {
        Group {
            // A ringing alarm's mission always wins, even mid-onboarding.
            if coordinator.needsMission {
                let coachState = CoachModel.shared.state(coordinator: coordinator, logs: [])
                MissionRunnerView(missions: coordinator.activePlan?.missions ?? [],
                                  reArmCount: coordinator.session?.reArmCount ?? 0,
                                  reArmMinutes: coordinator.activePlan?.reArmMinutes ?? 2,
                                  coachState: coachState,
                                  coachLine: CoachModel.shared.line(for: coachState, coordinator: coordinator, logs: []),
                                  onAllComplete: completeMission)
            } else if !onboarded {
                OnboardingView(coordinator: coordinator, auth: auth, store: store,
                               onboardingStore: onboardingStore) {
                    withAnimation { onboarded = true }
                }
            } else {
                MainTabView(coordinator: coordinator, auth: auth, store: store,
                         notices: noticeMessages,
                         onDismissNotices: {
                             notices.clear()
                             noticeMessages = []
                         },
                         onReplayOnboarding: {
                             onboardingStore.reset()
                             onboarded = false
                         })
            }
        }
        .animation(.default, value: coordinator.needsMission)
        .environment(\.paywall, PaywallContext(store: store, accountToken: auth.user?.id,
                                               termsURL: auth.config.termsURL,
                                               privacyURL: auth.config.privacyURL))
        // Free tier: once StoreKit has answered, bring alarms within the free limits.
        .onChange(of: store.entitlement) { enforceTier() }
        .onChange(of: store.hasLoadedEntitlement) { enforceTier() }
        .onChange(of: onboarded) { enforceTier() }
        .onChange(of: coordinator.needsMission) { enforceTier() }
        .onAppear { noticeMessages = notices.messages }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { coordinator.reload() }
        }
        // Cold launch from the alarm's X: scenePhase never "changes", so sync on first appear too.
        .task {
            store.start()
            coordinator.reload()
            await coordinator.refreshAlarms()
            await coordinator.observeSystemAlarms()
        }
        // Tap on the Live Activity (earnit://mission).
        .onOpenURL { url in
            switch url.host() {
            case "mission": coordinator.missionStarted(id: nil)
            case "auth-callback": Task { await auth.handle(url: url) }  // email confirmation links
            default: break
            }
        }
        .fullScreenCover(isPresented: $showSuccess) {
            SuccessView(coordinator: coordinator) { showSuccess = false }
        }
    }

    private func enforceTier() {
        guard onboarded, store.hasLoadedEntitlement, !store.entitlement.isPro else { return }
        Task {
            let changes = await TierEnforcement.enforce(on: coordinator, gate: store.gate)
            notices.add(changes.map(\.message))
            noticeMessages = notices.messages
        }
    }

    private func completeMission() {
        let session = coordinator.missionSucceeded()
        let day = session.day
        let existing = try? modelContext.fetch(FetchDescriptor<DayLog>(predicate: #Predicate { $0.day == day })).first
        if let existing {
            existing.missionCompletedAt = session.missionCompletedAt
            existing.firstEndedAt = session.firstEndedAt
            existing.reArmCount = session.reArmCount
        } else {
            modelContext.insert(DayLog(session: session))
        }
        try? modelContext.save()
        showSuccess = true
    }
}

struct SuccessView: View {
    let coordinator: AlarmCoordinator
    let dismiss: () -> Void
    @Query private var logs: [DayLog]

    var body: some View {
        let streak = StreakCalculator.currentStreak(completedDays: logs.compactMap(\.missionCompletedAt), today: .now)
        let coach = CoachModel.shared
        let state = coach.state(coordinator: coordinator, logs: logs)
        VStack(spacing: 20) {
            Spacer()
            CoachAvatarView(state: state, size: 170)
            Text(coach.line(for: state, coordinator: coordinator, logs: logs))
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("You earned it.").font(.largeTitle.bold())
            Text("Follow-up alarms cancelled.").foregroundStyle(.secondary)
            Text("Streak: \(streak) day\(streak == 1 ? "" : "s")")
                .font(.title2.weight(.semibold))
            Spacer()
            Button("Done", action: dismiss)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(24)
    }
}
