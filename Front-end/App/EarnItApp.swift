import Account
import AlarmEngine
import Core
import Features
import SwiftData
import SwiftUI

/// Single shared object graph, reachable from App Intents (they run in the app process).
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let store = KeyValueStore()
    let coordinator: AlarmCoordinator
    let modelContainer: ModelContainer
    let auth: any AuthService = AuthServiceFactory.make()

    private init() {
        let scheduler = AlarmKitScheduler(intents: AlarmIntentFactory(
            stop: { StopAlarmIntent(alarmID: $0) }
        ))
        coordinator = AlarmCoordinator(store: store, scheduler: scheduler, sound: AlarmSoundPlayer())
        do {
            modelContainer = try ModelContainer(for: DayLog.self)
        } catch {
            fatalError("SwiftData container failed: \(error)")
        }
    }
}

@main
struct EarnItApp: App {
    private let env = AppEnvironment.shared

    var body: some Scene {
        WindowGroup {
            RootView(coordinator: env.coordinator, auth: env.auth)
                .tint(.orange)
        }
        .modelContainer(env.modelContainer)
    }
}
