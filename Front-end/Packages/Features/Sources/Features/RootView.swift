import Account
import AlarmEngine
import Coach
import Core
import Missions
import Purchases
import SwiftData
import SwiftUI
import UserNotifications
import WidgetShared

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
    @State private var tab: MainTabView.TabID = .alarms
    @State private var showPaywallFromWidget = false

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
            #if DEBUG
            // Launch argument for screenshots: -widgetPreviews [-sample] [-free]
            let previewWidgets = CommandLine.arguments.contains("-widgetPreviews")
            #else
            let previewWidgets = false
            #endif
            // A ringing alarm's mission always wins, even mid-onboarding.
            if previewWidgets {
                #if DEBUG
                NavigationStack { WidgetPreviewsView(coordinator: coordinator, store: store) }
                #endif
            } else if CommandLine.arguments.contains("-missionPicker") {
                // Screenshot helper: -missionPicker
                MissionPickerView(gate: store.gate) { _ in }
            } else if CommandLine.arguments.contains("-missionRunner") {
                // Screenshot helper: -missionRunner (object step without a scan, then math)
                MissionRunnerView(missions: [MissionConfig(kind: .object, payload: "none", label: "Toothbrush"),
                                             MissionConfig(kind: .math)],
                                  reArmCount: 2, reArmMinutes: 2,
                                  coachState: CoachState(mood: .angry, context: .reRing, anger: 0.4),
                                  coachLine: "Ring 2, private. My patience has a snooze limit too.") {}
            } else if coordinator.needsMission {
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
                         selection: $tab,
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
        .paywallSheet(isPresented: $showPaywallFromWidget)
        .environment(\.paywall, PaywallContext(store: store, accountToken: auth.user?.id,
                                               termsURL: auth.config.termsURL,
                                               privacyURL: auth.config.privacyURL))
        // Free tier: once StoreKit has answered, bring alarms within the free limits.
        .onChange(of: store.entitlement) {
            enforceTier()
            refreshCoachNotifications()
        }
        .onChange(of: store.hasLoadedEntitlement) { enforceTier() }
        .onChange(of: onboarded) { enforceTier() }
        .onChange(of: coordinator.needsMission) { enforceTier() }
        .onAppear { noticeMessages = notices.messages }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                coordinator.reload()
                refreshCoachNotifications()
            }
        }
        .onChange(of: coordinator.plans) {
            refreshCoachNotifications()
            // Delete item scans that no alarm uses anymore.
            let inUse = Set(coordinator.plans.flatMap(\.missions).filter { $0.kind == .object }.compactMap(\.payload))
            ObjectReferenceStore.shared.prune(keeping: inUse)
        }
        .onChange(of: coordinator.session) { refreshCoachNotifications() }
        // Cold launch from the alarm's X: scenePhase never "changes", so sync on first appear too.
        .task {
            UNUserNotificationCenter.current().delegate = CoachModel.shared.notificationDelegate
            store.start()
            coordinator.reload()
            refreshCoachNotifications()
            await coordinator.refreshAlarms()
            await coordinator.observeSystemAlarms()
        }
        // Tap on the Live Activity (earnit://mission).
        .onOpenURL { url in
            switch url.host() {
            case "mission": coordinator.missionStarted(id: nil)
            case "auth-callback": Task { await auth.handle(url: url) }  // email confirmation links
            case "progress": tab = .progress                                // widget tap
            case "paywall": if onboarded { showPaywallFromWidget = true }  // locked Pro widget
            default: break
            }
        }
        .fullScreenCover(isPresented: $showSuccess) {
            SuccessView(coordinator: coordinator) { showSuccess = false }
        }
    }

    /// Coach notifications + widget snapshot: both derive from alarms, today's session and history.
    private func refreshCoachNotifications() {
        let logs = (try? modelContext.fetch(FetchDescriptor<DayLog>())) ?? []
        CoachNotifier.shared.completedDays = logs.compactMap(\.missionCompletedAt)
        Task { await CoachNotifier.shared.refresh(coordinator: coordinator) }
        WidgetPublisher.shared.publish(coordinator: coordinator, logs: logs, isPro: store.entitlement.isPro)
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
        refreshCoachNotifications()
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
