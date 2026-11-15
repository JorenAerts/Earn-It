import ActivityKit
import AlarmEngine
import AlarmKit
import SwiftUI
import WidgetKit

@main
struct GloopWidgetBundle: WidgetBundle {
    var body: some Widget {
        AlarmLiveActivity()
        StreakWidget()
        StreakRankWidget()
        ServiceRecordWidget()
        LockStreakWidget()
        LockStreakRankWidget()
    }
}

/// Lock Screen + Dynamic Island UI for Gloop alarms. AlarmKit drives the state;
/// we render the title ("Gloop - Math Problem") and the re-ring countdown after Stop.
struct AlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<GloopAlarmMetadata>.self) { context in
            LockScreenView(context: context)
                .padding(16)
                .widgetURL(missionURL)
                .activityBackgroundTint(.black.opacity(0.75))
                .activitySystemActionForegroundColor(.orange)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "alarm.fill").foregroundStyle(.orange).font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(state: context.state).font(.title2.bold()).foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title(context)).font(.headline).lineLimit(1)
                        Text(subtitle(context.state)).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "alarm.fill").foregroundStyle(.orange)
            } compactTrailing: {
                CountdownText(state: context.state).foregroundStyle(.orange).frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "alarm.fill").foregroundStyle(.orange)
            }
            .keylineTint(.orange)
            .widgetURL(missionURL)
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<AlarmAttributes<GloopAlarmMetadata>>

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title(context))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle(context.state))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                if case .countdown = context.state.mode {
                    Text("Tap to start your mission")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 0)
            CountdownText(state: context.state)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)
        }
    }
}

/// Live ticking "1:59" while counting down; nothing otherwise.
private struct CountdownText: View {
    let state: AlarmPresentationState

    var body: some View {
        switch state.mode {
        case .countdown(let countdown):
            Text(timerInterval: Date.now...countdown.fireDate, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        case .alert:
            Image(systemName: "bell.and.waves.left.and.right.fill")
        default:
            EmptyView()
        }
    }
}

private let missionURL = URL(string: "gloop://mission")

private func title(_ context: ActivityViewContext<AlarmAttributes<GloopAlarmMetadata>>) -> String {
    context.attributes.metadata?.title ?? "Gloop"
}

private func subtitle(_ state: AlarmPresentationState) -> String {
    switch state.mode {
    case .countdown: "Rings again in"
    case .alert: "Tap ✕ to start your mission"
    default: "Paused"
    }
}
