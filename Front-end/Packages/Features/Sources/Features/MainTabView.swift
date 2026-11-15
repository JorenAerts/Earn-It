import Account
import AlarmEngine
import Buddies
import Purchases
import SwiftUI

/// The app after onboarding: Alarms · Progress · Settings.
struct MainTabView: View {
    enum TabID: Hashable { case alarms, progress, buddies, settings }

    let coordinator: AlarmCoordinator
    let auth: any AuthService
    let store: StoreService
    @Binding var selection: TabID
    var notices: [String]
    var onDismissNotices: () -> Void
    var onReplayOnboarding: () -> Void

    var body: some View {
        TabView(selection: $selection) {
            Tab("Alarms", systemImage: "alarm.fill", value: TabID.alarms) {
                HomeView(coordinator: coordinator, store: store,
                         notices: notices, onDismissNotices: onDismissNotices)
            }
            Tab("Progress", systemImage: "flame.fill", value: TabID.progress) {
                StatsView()
            }
            Tab("Buddies", systemImage: "person.3.fill", value: TabID.buddies) {
                BuddiesView(auth: auth, store: store)
            }
            Tab("Settings", systemImage: "gearshape.fill", value: TabID.settings) {
                SettingsView(coordinator: coordinator, auth: auth, store: store,
                             onReplayOnboarding: onReplayOnboarding)
            }
        }
    }
}
