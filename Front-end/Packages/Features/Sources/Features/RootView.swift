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
        VStack(spacing: 0) {
          ScrollView {
           VStack(spacing: 20) {
            CoachAvatarView(state: state, size: 170)
                .padding(.top, 32)
            Text(coach.line(for: state, coordinator: coordinator, logs: logs))
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            let report = MorningReport.make(history: logs.map(DaySummary.init(log:)),
                                            day: coordinator.session?.day ?? .now)
            if report.promoted {
                VStack(spacing: 6) {
                    RankInsignia(rank: report.after.rank, size: 64)
                    Text("Promoted to \(report.after.rank.title)!").font(.title2.bold())
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Text("You earned it.").font(.largeTitle.bold())
            }
            if report.xpGained > 0 {
                VStack(spacing: 6) {
                    Text("+\(report.xpGained) XP").font(.headline).foregroundStyle(.orange).monospacedDigit()
                    ProgressView(value: report.after.fraction).tint(.orange).frame(maxWidth: 240)
                    if let next = report.after.next, let toGo = report.after.xpToNext {
                        Text("\(toGo) XP to \(next.title)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if !report.newMedals.isEmpty {
                VStack(spacing: 8) {
                    Text(report.newMedals.count == 1 ? "New medal" : "New medals")
                        .font(.caption.weight(.heavy)).textCase(.uppercase).foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        ForEach(report.newMedals.prefix(3)) { MedalTile(medal: $0, earned: true).frame(width: 96) }
                    }
                }
            }
            Text("Follow-up alarms cancelled.").foregroundStyle(.secondary)
            Text("Streak: \(streak) day\(streak == 1 ? "" : "s")")
                .font(.title2.weight(.semibold))
           }
           .frame(maxWidth: .infinity)
           .padding(24)
          }
          .scrollBounceBehavior(.basedOnSize)
            Button("Done", action: dismiss)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom, 24)
        }
    }
}
