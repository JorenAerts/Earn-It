import Account
import AlarmEngine
import Purchases
import SwiftUI

/// The app after onboarding: Alarms · Progress · Settings.
struct MainTabView: View {
    enum TabID: Hashable { case alarms, progress, settings }

    let coordinator: AlarmCoordinator
    let auth: any AuthService
    let store: StoreService
    var notices: [String]
    var onDismissNotices: () -> Void
    var onReplayOnboarding: () -> Void

    @State private var selection: TabID = .alarms

    var body: some View {
        TabView(selection: $selection) {
            Tab("Alarms", systemImage: "alarm.fill", value: TabID.alarms) {
                HomeView(coordinator: coordinator, store: store,
                         notices: notices, onDismissNotices: onDismissNotices)
            }
            Tab("Progress", systemImage: "flame.fill", value: TabID.progress) {
                StatsView()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: TabID.settings) {
                SettingsView(coordinator: coordinator, auth: auth, store: store,
                             onReplayOnboarding: onReplayOnboarding)
            }
        }
    }
}
