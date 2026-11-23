import Account
import AlarmEngine
import Buddies
import Coach
import Core
import Localization
import Missions
import Permissions
import Purchases
import StoreKit
import SwiftData
import SwiftUI
import Telemetry
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
    /// Happy moment from this morning worth asking for a rating at (see `RatingPolicy`).
    @State private var ratingMoment: RatingPolicy.Moment?
    @State private var whatsNew: HelpContent.Release?
    @State private var buddies: BuddiesModel
    @State private var language = LanguageSettings.shared
    @State private var reminders = ReminderRouter.shared

    public init(coordinator: AlarmCoordinator, auth: any AuthService, store: StoreService,
                buddies: any BuddiesService = UnavailableBuddiesService(),
                onboardingStore: OnboardingStore = OnboardingStore()) {
        self.coordinator = coordinator
        self.auth = auth
        self.store = store
        self.onboardingStore = onboardingStore
        // Screenshot helper: -language <code> (e.g. nl) picks the app language for this run (first: sample data is localized too).
        if let i = CommandLine.arguments.firstIndex(of: "-language"), i + 1 < CommandLine.arguments.count {
            LanguageSettings.shared.select(CommandLine.arguments[i + 1], persist: false)
        }
        #if DEBUG
        // Screenshot helper: -buddiesSample (fake clubs, members and photos; opens the Buddies tab).
        let sample = CommandLine.arguments.contains("-buddiesSample")
        let model = BuddiesModel(service: sample ? BuddiesSamples.make() : buddies)
        model.sampleMode = sample
        _buddies = State(initialValue: model)
        if sample { _tab = State(initialValue: .buddies) }
        #else
        _buddies = State(initialValue: BuddiesModel(service: buddies))
        #endif
        _onboarded = State(initialValue: (onboardingStore.load().completed
                                          || CommandLine.arguments.contains("-buddiesSample"))  // screenshots on a fresh simulator
                           && !CommandLine.arguments.contains("-onboardingStep"))  // screenshot helper
        // Screenshot helper: -settings opens on the Settings tab.
        if CommandLine.arguments.contains("-settings") { _tab = State(initialValue: .settings) }
        #if DEBUG
        // Screenshot / regression helper: -successScreen opens the mission-done screen (same cover as a real morning).
        if CommandLine.arguments.contains("-successScreen") { _showSuccess = State(initialValue: true) }
        #endif
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
            } else if let scene = Self.storeShotScene {
                #if DEBUG
                StoreShotView(scene: scene, store: store)  // App Store screenshots: -storeShot <scene>
                #endif
            } else if let i = CommandLine.arguments.firstIndex(of: "-legal"), i + 1 < CommandLine.arguments.count,
                      let kind = LegalDocumentKind(rawValue: CommandLine.arguments[i + 1]) {
                NavigationStack { LegalDocumentView(kind: kind) }  // Screenshot helper: -legal privacy|terms|health-safety|community
            } else if CommandLine.arguments.contains("-feedbackBoard"), let board = auth.config.feedbackURL {
                NavigationStack { FeedbackBoardView(auth: auth, base: board) }  // Debug helper: -feedbackBoard
            } else if CommandLine.arguments.contains("-slimeGallery") {
                NavigationStack { SlimeGallery() }  // Screenshot helper: -slimeGallery
            } else if CommandLine.arguments.contains("-permissionsPreview") {
                // Screenshot helper: -permissionsPreview
                NavigationStack {
                    List { Section("Permissions") { ForEach(PermissionKind.allCases) { PermissionRow(kind: $0) } } }
                        .navigationTitle("Permissions")
                }
            } else if CommandLine.arguments.contains("-soundPicker") {
                // Screenshot helper: -soundPicker
                NavigationStack { SoundPickerView(selection: .constant(.builtIn(.morningMood)), gate: FeatureGate(isPro: true)) }
            } else if CommandLine.arguments.contains("-missionPicker") {
                // Screenshot helper: -missionPicker
                MissionPickerView(gate: store.gate) { _ in }
            } else if CommandLine.arguments.contains("-missionRunner") {
                // Screenshot helper: -missionRunner (object step without a scan, then math)
                // Screenshot helper: -missionRunner [kind] (e.g. sky, colorHunt, quiz); default = item scan + math.
                let i = CommandLine.arguments.firstIndex(of: "-missionRunner")!
                let kind = CommandLine.arguments.dropFirst(i + 1).first.flatMap(MissionKind.init(rawValue:))
                MissionRunnerView(missions: kind.map { [MissionConfig(kind: $0)] }
                                  ?? [MissionConfig(kind: .object, payload: "none", label: L10n.tr("Toothbrush")),
                                      MissionConfig(kind: .math)],
                                  reArmCount: 2, reArmMinutes: 2,
                                  coachState: CoachState(mood: .angry, context: .reRing, anger: 0.4),
                                  coachLine: L10n.tr("Ring 2, private. My patience has a snooze limit too.")) {}
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
        // A new language redraws every screen (model texts are resolved when a view is built).
        // Tab, sheets and the language picker live above this, so they stay put.
        .id(language.current.code)
        // Mission done. Must stay *inside* the environment modifiers below: a presented view only
        // inherits what is applied outside its presentation modifier. SuccessView reads BuddiesModel,
        // and without it SwiftUI traps, which closed the app after every mission.
        .fullScreenCover(isPresented: $showSuccess, onDismiss: { ratingMoment = nil }) {
            SuccessView(coordinator: coordinator, ratingMoment: ratingMoment) { showSuccess = false }
                .environment(buddies)
                .modifier(LanguageEnvironment(language: language.current))
                .trackScreen("Success")
        }
        .animation(.default, value: coordinator.needsMission)
        .permissionPrompt()
        .environment(buddies)
        .preferredColorScheme(AppearanceSettings.shared.preference.colorScheme)
        .sheet(isPresented: $language.isPickerPresented) {
            LanguagePickerView(settings: language) { language.isPickerPresented = false }
                .modifier(LanguageEnvironment(language: language.current))
        }
        .onChange(of: language.current) { languageChanged() }
        .modifier(LanguageEnvironment(language: language.current))
        .environment(\.paywall, PaywallContext(store: store, accountToken: auth.user?.id))
        .paywallSheet(isPresented: $showPaywallFromWidget, source: .widget)  // after \.paywall, or it opens empty
        // Free tier: once StoreKit has answered, bring alarms within the free limits.
        .onChange(of: store.entitlement) {
            enforceTier()
            refreshCoachNotifications()
        }
        .onChange(of: store.hasLoadedEntitlement) { enforceTier() }
        .onChange(of: onboarded) { enforceTier() }
        .onChange(of: coordinator.needsMission) { enforceTier() }
        .onAppear { noticeMessages = notices.messages }
        .onChange(of: store.entitlement) { old, new in
            guard store.hasLoadedEntitlement, old != new else { return }
            Telemetry.shared.send(.entitlementChanged(from: old.telemetryName, to: new.telemetryName))
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { Telemetry.shared.sessionEnded() }
            if phase == .active {
                Telemetry.shared.sessionStarted()
                Task { await PermissionCenter.shared.refresh() }  // back from Settings
                coordinator.reload()
                refreshCoachNotifications()
                Task { await coordinator.restoreMissingAlarms() }  // pause over → weekly repeat back
                Task { await buddies.refresh(signedIn: buddies.isSignedIn(auth.user?.id)) }  // + sends queued wake-up reports
            }
        }
        // An own sound was deleted: alarms using it go back to Classic Beep.
        .onChange(of: MySounds.shared.sounds) { _, sounds in
            let ids = Set(sounds.map(\.id))
            for var plan in coordinator.plans {
                if case .custom(let id, _) = plan.sound, !ids.contains(id) {
                    plan.sound = .classic
                    Task { await coordinator.save(plan) }
                }
            }
        }
        .onChange(of: coordinator.plans) {
            refreshCoachNotifications()
            // Delete item scans that no alarm uses anymore.
            let inUse = Set(coordinator.plans.flatMap(\.missions).filter { $0.kind == .object || $0.kind == .bed }.compactMap(\.payload))
            ObjectReferenceStore.shared.prune(keeping: inUse)
        }
        .onChange(of: coordinator.session) { refreshCoachNotifications() }
        .onChange(of: coordinator.pause) { refreshCoachNotifications() }
        // "Set your alarm" reminder tapped: Alarms tab (HomeView opens the editor when there are no alarms).
        .onChange(of: reminders.pendingSetAlarm, initial: true) { _, pending in
            if pending { tab = .alarms }
        }
        .onChange(of: PermissionCenter.shared.blocked) { _, kind in
            if let kind { Telemetry.shared.send(.action(.permissionDenied(kind: kind.rawValue))) }
        }
        // Cold launch from the alarm's X: scenePhase never "changes", so sync on first appear too.
        .task {
            Telemetry.shared.commonParameters = { [store, onboardingStore] in
                ["plan": store.entitlement.telemetryName, "onboarded": "\(onboardingStore.load().completed)",
                 "language": L10n.languageCode]
            }
            coordinator.onEvent = { event in
                switch event {
                case .rang: Telemetry.shared.send(.alarmRang)
                case .stopped(let attempt): Telemetry.shared.send(.alarmStopped(attempt: attempt))
                case .failSafe(let rings):
                    Telemetry.shared.send(.morningFailSafe(rings: rings))
                    if let session = coordinator.session { logCycle(session) }  // Progress shows fail-safe days
                    refreshCoachNotifications()
                }
            }
            Telemetry.shared.sessionStarted(source: coordinator.needsMission ? .alarm : .cold)
            ReminderRouter.installNotificationDelegate()  // also in GloopApp.init (cold-launch taps)
            store.start()
            await PermissionCenter.shared.refresh()
            coordinator.reload()
            refreshCoachNotifications()
            await coordinator.refreshAlarms()
            await coordinator.observeSystemAlarms()
        }
        // Tap on the Live Activity (gloop://mission).
        .onOpenURL { url in
            switch url.host() {
            case "mission":
                coordinator.missionStarted(id: nil)
                Telemetry.shared.send(.appLaunched(source: .link))
            case "auth-callback": Task { await auth.handle(url: url) }  // email confirmation links
            case "progress": tab = .progress                                // widget tap
            case "paywall": if onboarded { showPaywallFromWidget = true }  // locked Pro widget
            case "join":                                                    // club invite link
                if let code = url.pathComponents.dropFirst().first {
                    tab = .buddies
                    buddies.pendingJoinCode = code
                }
            default: break
            }
        }
        .sheet(item: $whatsNew) { release in
            WhatsNewSheet(release: release) {
                GrowthStore.shared.markWhatsNewSeen(release.version)
                whatsNew = nil
            }
            .modifier(LanguageEnvironment(language: language.current))
        }
        .task(id: onboarded) { checkWhatsNew() }
    }

    /// Everything outside SwiftUI that carries text: the iOS alarm titles, coach notifications, widgets.
    private func languageChanged() {
        refreshCoachNotifications()
        WidgetPublisher.shared.reloadAll()
        guard !coordinator.needsMission else { return }  // never touch a ringing alarm
        Task { await coordinator.refreshAlarms() }
    }

    /// Coach notifications + widget snapshot: both derive from alarms, today's session and history.
    private func refreshCoachNotifications() {
        let logs = (try? modelContext.fetch(FetchDescriptor<DayLog>())) ?? []
        CoachNotifier.shared.completedDays = logs.compactMap(\.missionCompletedAt)
        CoachModel.shared.refreshVitality(logs: logs, plans: coordinator.plans)
        Task { await CoachNotifier.shared.refresh(coordinator: coordinator) }
        WidgetPublisher.shared.publish(coordinator: coordinator, logs: logs, isPro: store.entitlement.isPro)
    }

    /// Launched by scripts/screenshots/make.sh (demo scenes): no What's New sheet over them.
    static var isScreenshotRun: Bool {
        let args = CommandLine.arguments
        return ["-buddiesSample", "-storeShot", "-successScreen", "-widgetPreviews"].contains(where: args.contains)
    }

    /// What's New after an update: once per version, never on a fresh install or during a mission.
    private func checkWhatsNew() {
        guard onboarded, !coordinator.needsMission, !Self.isScreenshotRun else { return }
        let store = GrowthStore.shared
        let current = GrowthStore.appVersion
        guard let seen = store.whatsNewSeenVersion else {
            store.markWhatsNewSeen(current)  // first launch: nothing "new" yet
            return
        }
        let content = HelpContent.load()
        if let version = WhatsNewPolicy.versionToShow(current: current, lastSeenVersion: seen,
                                                       availableVersions: content.releases.map(\.version)),
           let release = content.releases.first(where: { $0.version == version }) {
            whatsNew = release
            Telemetry.shared.send(.action(.whatsNewShown(version: version)))
        } else {
            store.markWhatsNewSeen(current)
        }
    }

    /// Tell the clubs about this morning (queued when offline).
    private func reportToBuddies(_ session: SessionState) {
        guard let completedAt = session.missionCompletedAt else { return }
        let logs = (try? modelContext.fetch(FetchDescriptor<DayLog>())) ?? []
        let plan = coordinator.plan(id: session.planID)
        Task {
            await buddies.reportMorning(day: session.day, completedAt: completedAt, rings: session.reArmCount + 1,
                                        alarmTime: plan?.timeText, history: logs.map(DaySummary.init(log:)),
                                        signedIn: auth.user != nil)
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

    /// Stores a finished ring cycle in its day's log (`DayLogRule`: first completed cycle wins).
    private func logCycle(_ session: SessionState) {
        let day = session.day
        let existing = try? modelContext.fetch(FetchDescriptor<DayLog>(predicate: #Predicate { $0.day == day })).first
        guard let values = DayLogRule.merge(existing: existing?.values, cycle: session) else { return }
        if let existing {
            existing.apply(values)
        } else {
            modelContext.insert(DayLog(values))
        }
        try? modelContext.save()
    }

    private func completeMission() {
        let session = coordinator.missionSucceeded()
        logCycle(session)
        refreshCoachNotifications()
        reportToBuddies(session)
        reportMorningTelemetry(session)
        showSuccess = true
    }

    /// Mission done: how the morning went, plus evolutions, stickers and streak milestones.
    private func reportMorningTelemetry(_ session: SessionState) {
        let kinds = coordinator.plan(id: session.planID)?.missions.map(\.kind.rawValue).joined(separator: "+") ?? "unknown"
        let seconds = session.firstEndedAt.flatMap { start in session.missionCompletedAt.map { Int($0.timeIntervalSince(start)) } } ?? 0
        Telemetry.shared.send(.missionCompleted(kinds: kinds, rings: session.reArmCount + 1,
                                                secondsFromFirstRing: max(0, seconds), firstTry: session.reArmCount == 0))
        let logs = (try? modelContext.fetch(FetchDescriptor<DayLog>())) ?? []
        let report = MorningReport.make(history: logs.map(DaySummary.init(log:)), day: session.day)
        if report.promoted { Telemetry.shared.send(.gloopEvolved(stage: report.after.rank.englishTitle)) }
        for sticker in report.newMedals { Telemetry.shared.send(.stickerEarned(sticker: sticker.rawValue)) }
        let streak = StreakCalculator.currentStreak(completedDays: logs.compactMap(\.missionCompletedAt), today: .now)
        if [3, 7, 14, 30, 60, 100, 365].contains(streak) { Telemetry.shared.send(.streakMilestone(days: streak)) }

        // Ask for a rating only at a happy moment (shown on the success screen).
        let firstRings = logs.filter { $0.missionCompletedAt != nil && $0.reArmCount == 0 }.count
        var moments: [RatingPolicy.Moment] = [.streak(streak), .firstRingMornings(firstRings)]
        if report.promoted { moments.insert(.evolved, at: 0) }
        ratingMoment = RatingPolicy.moment(from: moments, state: GrowthStore.shared.ratingState, now: .now,
                                           appVersion: GrowthStore.appVersion, failSafeToday: session.failSafeTriggered)
    }
}

struct SuccessView: View {
    let coordinator: AlarmCoordinator
    var ratingMoment: RatingPolicy.Moment? = nil
    let dismiss: () -> Void
    @Environment(\.requestReview) private var requestReview
    @Query private var logs: [DayLog]
    @Environment(BuddiesModel.self) private var buddies
    @State private var sharing = false
    @State private var landed = false
    @State private var tip = MorningTips.pick(from: MorningTips.load(), day: .now)

    var body: some View {
        let streak = StreakCalculator.currentStreak(completedDays: logs.compactMap(\.missionCompletedAt), today: .now)
        let coach = CoachModel.shared
        let state = coach.state(coordinator: coordinator, logs: logs)
        VStack(spacing: 0) {
          ScrollView {
           VStack(spacing: 20) {
            CoachAvatarView(state: state, size: 170)
                .scaleEffect(landed ? 1 : 0.3)
                .opacity(landed ? 1 : 0)
                .padding(.top, 32)
            Text(coach.line(for: state, coordinator: coordinator, logs: logs))
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            let report = MorningReport.make(history: logs.map(DaySummary.init(log:)),
                                            day: coordinator.session?.day ?? .now)
            if report.promoted {
                VStack(spacing: 6) {
                    RankInsignia(rank: report.after.rank, size: 64)
                    Text("\(CoachIdentity.name) evolved into \(report.after.rank.title)!").font(.title2.bold()).multilineTextAlignment(.center)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Text("You earned it.").font(.largeTitle.bold())
                    .scaleEffect(landed ? 1 : 0.6)
                    .opacity(landed ? 1 : 0)
            }
            if let tip { MorningTipCard(tip: tip).opacity(landed ? 1 : 0) }
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
                    Text(report.newMedals.count == 1 ? L10n.tr("New sticker!") : L10n.tr("New stickers!"))
                        .font(.caption.weight(.heavy)).textCase(.uppercase).foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        ForEach(report.newMedals.prefix(3)) { MedalTile(medal: $0, earned: true).frame(width: 96) }
                    }
                }
            }
            Text("Follow-up alarms cancelled.").foregroundStyle(.secondary)
            Text("Streak: \(streak) days")
                .font(.title2.weight(.semibold))
           }
           .frame(maxWidth: .infinity)
           .padding(24)
          }
          .scrollBounceBehavior(.basedOnSize)
            VStack(spacing: 10) {
                if buddies.shouldPromptPhoto(missionDoneToday: true) {
                    Button { sharing = true } label: {
                        Label("Share your morning face", systemImage: "camera.fill")
                            .font(.headline).frame(maxWidth: 360).padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                ShareStreakButton(style: .plain)
                    .font(.subheadline.weight(.semibold))
                    .padding(.bottom, 2)
                if buddies.shouldPromptPhoto(missionDoneToday: true) {
                    Button("Done", action: dismiss).buttonStyle(.bordered).controlSize(.large)
                } else {
                    Button("Done", action: dismiss).buttonStyle(.borderedProminent).controlSize(.large)
                }
            }
            .padding(.bottom, 24)
        }
        .overlay { ConfettiBurst().ignoresSafeArea() }
        .sensoryFeedback(.success, trigger: landed)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.1)) { landed = true }
        }
        .sheet(isPresented: $sharing) { ShareMorningView() }
        .task {
            // Happy moment: Apple's rating prompt, after the celebration has landed.
            guard let ratingMoment else { return }
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            requestReview()
            GrowthStore.shared.didPromptRating(version: GrowthStore.appVersion)
            Telemetry.shared.send(.action(.ratingPrompted(reason: ratingMoment.reason)))
        }
    }
}

/// Today's tip or quote on the success screen (`MorningTips`, same one all day).
struct MorningTipCard: View {
    let tip: MorningTip

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(tip.kind == .quote ? "Quote of the morning" : "Morning tip",
                  systemImage: tip.kind == .quote ? "quote.opening" : "lightbulb.fill")
                .font(.caption.weight(.heavy))
                .textCase(.uppercase)
                .foregroundStyle(.orange)
            Text(tip.kind == .quote ? "“\(tip.text)”" : tip.text)
                .font(tip.kind == .quote ? .body.italic() : .body)
                .fixedSize(horizontal: false, vertical: true)
            if let author = tip.author, tip.kind == .quote {
                Text("— \(author)").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: 420, alignment: .leading)
        .padding(16)
        .background(Color.orange.opacity(0.1), in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}

extension EntitlementState {
    /// "free", "trial", "pro", "lifetime" for analytics.
    var telemetryName: String {
        switch self {
        case .free: "free"
        case .trial: "trial"
        case .pro(let until): until == nil ? "lifetime" : "pro"
        }
    }
}

extension RootView {
    #if DEBUG
    static var storeShotScene: StoreShotScene? {
        guard let i = CommandLine.arguments.firstIndex(of: "-storeShot"), i + 1 < CommandLine.arguments.count else { return nil }
        return StoreShotScene(rawValue: CommandLine.arguments[i + 1])
    }
    #else
    static var storeShotScene: Never? { nil }
    #endif
}
