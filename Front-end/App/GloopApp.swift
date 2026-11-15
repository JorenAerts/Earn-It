import Account
import AlarmEngine
import Buddies
import Core
import Features
import Localization
import Purchases
import SwiftData
import SwiftUI
import Telemetry

/// Single shared object graph, reachable from App Intents (they run in the app process).
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let store = KeyValueStore()
    let coordinator: AlarmCoordinator
    let modelContainer: ModelContainer
    let auth: any AuthService = AuthServiceFactory.make()
    /// Buddies shares the auth client (same session); without Supabase config it's unavailable.
    lazy var buddies: any BuddiesService = {
        guard let supabase = auth as? SupabaseAuthService else { return UnavailableBuddiesService() }
        return SupabaseBuddiesService(client: supabase.client) { [weak supabase] in supabase?.user?.id }
    }()
    let purchases: StoreService = {
        do {
            return StoreService(catalog: try PricingCatalog.load())
        } catch {
            fatalError(L10n.tr("Config/Pricing.json missing from the app bundle: \(error)"))
        }
    }()

    private init() {
        let scheduler = AlarmKitScheduler(intents: AlarmIntentFactory(
            stop: { StopAlarmIntent(alarmID: $0) }
        ))
        coordinator = AlarmCoordinator(store: store, scheduler: scheduler, sound: AlarmSoundPlayer())
        do {
            modelContainer = try ModelContainer(for: DayLog.self)
        } catch {
            fatalError(L10n.tr("SwiftData container failed: \(error)"))
        }
    }
}

@main
struct GloopApp: App {
    private let env = AppEnvironment.shared

    /// Launched as the unit-test host: start nothing (StoreKit, AlarmKit, UI) so tests own
    /// their environment — e.g. SKTestSession product loading isn't raced by the app.
    private static let isTestHost = ProcessInfo.processInfo.environment[L10n.tr("XCTestConfigurationFilePath")] != nil

    init() {
        guard !Self.isTestHost else { return }
        #if DEBUG
        let testMode = true   // Xcode builds show up as test signals in TelemetryDeck
        #else
        let testMode = false
        #endif
        let config = Telemetry.bundledConfig()
        Telemetry.shared.configure(appID: config.appID, namespace: config.namespace, testMode: testMode)
    }

    var body: some Scene {
        WindowGroup {
            if Self.isTestHost {
                Color.clear
            } else {
                RootView(coordinator: env.coordinator, auth: env.auth, store: env.purchases, buddies: env.buddies)
                    .tint(.orange)
            }
        }
        .modelContainer(env.modelContainer)
    }
}
