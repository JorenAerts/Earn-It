import Core
import Missions
import SwiftUI

/// Full-screen, no way back: runs each configured mission in order.
struct MissionRunnerView: View {
    let missions: [MissionConfig]
    let reArmCount: Int
    let reArmMinutes: Int
    let onAllComplete: () -> Void
    @State private var index = 0

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("Morning mission").font(.caption.weight(.semibold)).textCase(.uppercase)
                    .foregroundStyle(.secondary)
                if missions.count > 1 {
                    Text("Step \(min(index + 1, missions.count)) of \(missions.count)").font(.subheadline)
                }
                Label("Alarm keeps sounding until you finish", systemImage: "speaker.wave.3.fill")
                    .font(.footnote).foregroundStyle(.orange)
                Text("Leaving the app won't stop it.")
                    .font(.footnote).foregroundStyle(.secondary)
                if reArmCount > 0 {
                    Text("Re-rung \(reArmCount)×").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(.top, 24)

            Spacer()
            if index < missions.count {
                MissionRegistry.make(missions[index])
                    .makeView { _ in advance() }
                    .id(missions[index].id)
                    .transition(.push(from: .trailing))
            }
            Spacer()
        }
        .interactiveDismissDisabled()
        .onAppear { if missions.isEmpty { onAllComplete() } }
    }

    private func advance() {
        if index + 1 >= missions.count {
            onAllComplete()  // coordinator stops the alarm sound
        } else {
            withAnimation { index += 1 }
        }
    }
}
