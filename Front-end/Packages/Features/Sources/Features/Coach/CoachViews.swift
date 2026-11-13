import AlarmEngine
import Coach
import Core
import SwiftUI

/// Shared coach data: lines (Config/CoachLines.json) and the user's tone setting.
@MainActor
@Observable
final class CoachModel {
    static let shared = CoachModel()

    let lines = CoachLines.load()
    @ObservationIgnored private let preferences = CoachPreferences()

    var intensity: CoachIntensity {
        didSet { preferences.intensity = intensity }
    }

    private init() {
        intensity = CoachPreferences().intensity
    }

    func state(coordinator: AlarmCoordinator, logs: [DayLog], now: Date = .now) -> CoachState {
        MoodEngine.evaluate(CoachInput(now: now, missionDue: coordinator.needsMission,
                                       session: coordinator.session,
                                       history: logs.map(DaySummary.init(log:)),
                                       nextAlarm: coordinator.nextAlarm?.date))
    }

    func line(for state: CoachState, coordinator: AlarmCoordinator, logs: [DayLog], now: Date = .now) -> String {
        let completed = logs.compactMap(\.missionCompletedAt)
        let streak = StreakCalculator.currentStreak(completedDays: completed, today: now)
        let rings = coordinator.session?.reArmCount ?? 0
        let values = ["streak": "\(streak)",
                      "rings": "\(rings)",
                      "time": coordinator.nextAlarm?.plan.timeText ?? "07:00"]
        return lines.line(for: state.context, intensity: intensity, day: now, variant: rings, values: values)
    }
}

extension DaySummary {
    init(log: DayLog) {
        self.init(day: log.day, completed: log.missionCompletedAt != nil,
                  reArms: log.reArmCount, failSafe: log.failSafeTriggered)
    }
}

/// Sergeant Rise's face. Swappable art: one image per mood (`coach_<mood>` in the asset catalog).
/// Angry escalates on top of the image: shake, steam and a pulsing glow as `anger` rises.
struct CoachAvatarView: View {
    let state: CoachState
    var size: CGFloat = 96
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var anger: Double { state.mood == .angry ? state.anger : 0 }

    var body: some View {
        ZStack {
            if anger >= 0.6 { steam }
            TimelineView(.animation(minimumInterval: 1 / 60, paused: !shaking)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                Image(state.mood.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .shadow(color: .red.opacity(anger * 0.5), radius: anger * size * 0.15)
                    // Bursts of shaking that grow with anger.
                    .offset(x: shaking ? sin(t * 45) * size * 0.03 * anger * max(0, sin(t * 2.2)) : 0)
            }
            .id(state.mood)
            .transition(.asymmetric(insertion: .scale(scale: 0.7).combined(with: .opacity),
                                    removal: .opacity))
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.45, dampingFraction: 0.6), value: state.mood)
        .accessibilityElement()
        .accessibilityLabel("Sergeant Rise, \(state.mood.displayName.lowercased())")
    }

    private var shaking: Bool { !reduceMotion && anger >= 0.4 }

    private var steam: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let phase = (t * 0.6 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                    Image(systemName: "cloud.fill")
                        .font(.system(size: size * 0.22))
                        .foregroundStyle(.white.opacity(0.9 * (1 - phase)))
                        .shadow(color: .black.opacity(0.15), radius: 2)
                        .offset(x: (i.isMultiple(of: 2) ? -1 : 1) * size * 0.48,
                                y: -size * (0.15 + phase * 0.45))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Avatar + speech bubble.
struct CoachCard: View {
    let state: CoachState
    let line: String
    var avatarSize: CGFloat = 84

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CoachAvatarView(state: state, size: avatarSize)
            VStack(alignment: .leading, spacing: 4) {
                Text("Sergeant Rise")
                    .font(.caption.weight(.heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Text(line.isEmpty ? " " : line)
                    .font(.callout.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SpeechBubble().fill(Color(.secondarySystemBackground)))
        }
        .animation(.easeInOut(duration: 0.25), value: line)
        .accessibilityElement(children: .combine)
    }
}

/// Rounded bubble with a small tail pointing left, towards the avatar.
private struct SpeechBubble: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect.insetBy(dx: 6, dy: 0), cornerRadius: 16)
        let y = rect.midY
        path.move(to: CGPoint(x: rect.minX + 6, y: y - 7))
        path.addLine(to: CGPoint(x: rect.minX, y: y))
        path.addLine(to: CGPoint(x: rect.minX + 6, y: y + 7))
        path.closeSubpath()
        return path
    }
}
