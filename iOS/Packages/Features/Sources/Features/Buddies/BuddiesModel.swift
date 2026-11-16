import Buddies
import Coach
import Core
import Foundation
import Observation
import Telemetry

/// App-wide Buddies state: the user's clubs, today's photo decision, pending wake-up reports,
/// and a join code waiting for the user (deep link). Injected with `.environment(model)`.
@MainActor
@Observable
public final class BuddiesModel {
    public let service: any BuddiesService
    private(set) var clubs: [Club] = []
    private(set) var myPhotoState: PhotoState = .none
    private(set) var loaded = false
    var error: String?
    /// From `gloop://join/<code>`: BuddiesView opens the join sheet with it.
    var pendingJoinCode: String?

    @ObservationIgnored private let queue: WakeReportQueue
    @ObservationIgnored private let defaults: UserDefaults
    private static let rulesKey = "gloop.buddies.rulesAccepted"
    private(set) var rulesAccepted: Bool
    /// Screenshot samples (`-buddiesSample`): act signed in without an account.
    var sampleMode = false {
        didSet { if sampleMode { rulesAccepted = true } }
    }

    func isSignedIn(_ user: UUID?) -> Bool { sampleMode || user != nil }

    public init(service: any BuddiesService, defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        self.queue = WakeReportQueue(defaults: defaults)
        rulesAccepted = defaults.bool(forKey: Self.rulesKey)
    }

    var today: String { DayKey.string(.now) }
    var weekStart: String { DayKey.string(WeekWindow.start(of: .now)) }
    var ownedClubCount: Int { clubs.filter(\.isOwner).count }

    func acceptRules() {
        rulesAccepted = true
        defaults.set(true, forKey: Self.rulesKey)
    }

    /// Clubs + today's photo state. Signed out → empty.
    func refresh(signedIn: Bool) async {
        guard service.isAvailable, signedIn else {
            clubs = []
            myPhotoState = .none
            loaded = true
            return
        }
        do {
            clubs = try await service.myClubs(day: today)
            myPhotoState = try await service.myPhotoState(day: today)
            error = nil
            await flushReports()
        } catch {
            self.error = error.localizedDescription
        }
        loaded = true
    }

    /// After a finished mission: queue the morning and send it (kept for later when offline).
    func reportMorning(day: Date, completedAt: Date, rings: Int, alarmTime: String?, history: [DaySummary],
                       signedIn: Bool) async {
        guard service.isAvailable, signedIn else { return }
        queue.enqueue(WakeReport.make(day: day, completedAt: completedAt, rings: rings, alarmTime: alarmTime,
                                      history: history))
        await flushReports()
        await refresh(signedIn: signedIn)
    }

    func flushReports() async {
        await queue.flush { try await self.service.send($0) }
    }

    func shouldPromptPhoto(missionDoneToday: Bool) -> Bool {
        FeedGate.shouldPrompt(missionDoneToday: missionDoneToday, clubCount: clubs.count, myPhotoState: myPhotoState)
    }

    /// Short, non-personal error code for analytics.
    static func errorCode(_ error: any Error) -> String {
        switch error as? BuddiesError {
        case .signedOut: "signedOut"
        case .unavailable: "unavailable"
        case .message: "server"
        case nil: "other"
        }
    }

    func didDecidePhoto(_ state: PhotoState) {
        myPhotoState = state
    }

    /// Runs a service call, turning errors into `error`. Returns whether it worked.
    @discardableResult
    func perform(_ work: () async throws -> Void) async -> Bool {
        do {
            try await work()
            error = nil
            return true
        } catch {
            self.error = error.localizedDescription
            Telemetry.shared.send(.errorShown(area: "buddies", code: Self.errorCode(error)))
            return false
        }
    }
}
