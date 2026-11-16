import AlarmKit
import AppIntents
import Foundation

/// The alarm's only control (X / Stop). Opens the app straight on the mission and re-arms a
/// countdown follow-up; the app keeps sounding an alarm until the mission is completed.
struct StopAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start mission"
    static let isDiscoverable = false
    static let supportedModes: IntentModes = .foreground(.immediate)

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init() {}
    init(alarmID: UUID) { self.alarmID = alarmID.uuidString }

    @MainActor
    func perform() async throws -> some IntentResult {
        await AppEnvironment.shared.coordinator.alarmEnded(id: UUID(uuidString: alarmID))
        return .result()
    }
}
