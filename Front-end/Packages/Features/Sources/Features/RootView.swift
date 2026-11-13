import Account
import AlarmEngine
import Core
import SwiftData
import SwiftUI

/// Routes between onboarding, the forced mission screen, and home.
public struct RootView: View {
    @Bindable var coordinator: AlarmCoordinator
    let auth: any AuthService
    @AppStorage("earnit.onboarded") private var onboarded = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @State private var showSuccess = false

    public init(coordinator: AlarmCoordinator, auth: any AuthService) {
        self.coordinator = coordinator
        self.auth = auth
    }

    public var body: some View {
        Group {
            if !onboarded {
                PermissionView(coordinator: coordinator) { onboarded = true }
            } else if coordinator.needsMission {
                MissionRunnerView(missions: coordinator.activePlan?.missions ?? [],
                                  reArmCount: coordinator.session?.reArmCount ?? 0,
                                  reArmMinutes: coordinator.activePlan?.reArmMinutes ?? 2,
                                  onAllComplete: completeMission)
            } else {
                HomeView(coordinator: coordinator, auth: auth)
            }
        }
        .animation(.default, value: coordinator.needsMission)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { coordinator.reload() }
        }
        // Cold launch from the alarm's X: scenePhase never "changes", so sync on first appear too.
        .task {
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
            SuccessView { showSuccess = false }
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
    let dismiss: () -> Void
    @Query private var logs: [DayLog]

    var body: some View {
        let streak = StreakCalculator.currentStreak(completedDays: logs.compactMap(\.missionCompletedAt), today: .now)
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "sun.max.fill")
                .font(.system(size: 90))
                .foregroundStyle(.orange)
                .symbolEffect(.bounce, options: .nonRepeating)
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
