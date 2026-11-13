import AlarmEngine
import SwiftUI

struct PermissionView: View {
    let coordinator: AlarmCoordinator
    let onContinue: () -> Void
    @State private var status: AlarmAuthorization = .notDetermined
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            Text("Earn It").font(.system(size: 44, weight: .heavy, design: .rounded))
            Text("An alarm you can't snooze your way out of. Stopping it without doing your mission just makes it ring again.")
                .font(.title3)
                .foregroundStyle(.secondary)

            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Alarms").font(.headline)
                    Text("Needed so your alarm rings through silent mode and Focus.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "alarm.fill").foregroundStyle(.orange)
            }
            Spacer()

            switch status {
            case .authorized:
                Button("Continue", action: onContinue)
                    .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
            case .denied:
                Text("Alarm access is off. Turn it on in Settings to use Earn It.")
                    .foregroundStyle(.red)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
            case .notDetermined:
                Button("Allow alarms") {
                    Task { status = await coordinator.requestAuthorization() }
                }
                .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .onAppear { status = coordinator.authorization }
    }
}
