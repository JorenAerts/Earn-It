import AlarmEngine
import Coach
import Core
import Localization
import SwiftUI
import WidgetShared

/// Shared coach data: lines (Shared/Config/CoachLines.json) and the user's tone setting.
@MainActor
@Observable
final class CoachModel {
    static let shared = CoachModel()

    /// Gloop's lines in the current language (reloaded after a language switch).
    var lines: CoachLines {
        if loadedLines?.language != L10n.languageCode {
            loadedLines = (L10n.languageCode, CoachLines.load())
        }
        return loadedLines!.lines
    }
    @ObservationIgnored private var loadedLines: (language: String, lines: CoachLines)?
    @ObservationIgnored private let preferences = CoachPreferences()

    var intensity: CoachIntensity {
        didSet { preferences.intensity = intensity }
    }

    var notifications: CoachNotificationSettings {
        didSet { preferences.notifications = notifications }
    }

    /// How well the user keeps up (0…1): drives how droopy Gloop is. Set by `refreshVitality`.
    private(set) var vitality = SlimeVitality.start
    /// Gloop's evolution stage (from XP): decides the accessory he wears.
    private(set) var rank: Rank = .droplet

    /// Recomputes vitality from the history and which days had an alarm.
    func refreshVitality(logs: [DayLog], plans: [AlarmPlan], now: Date = .now) {
        let calendar = Calendar.current
        let alarmWeekdays = Set(plans.filter(\.isEnabled).flatMap { $0.weekdays.isEmpty ? Array(1...7) : Array($0.weekdays) })
        let history = logs.map(DaySummary.init(log:))
        rank = XPRules.progress(history, calendar: calendar).rank
        vitality = SlimeVitality.compute(history: history, now: now, calendar: calendar) { day in
            alarmWeekdays.contains(calendar.component(.weekday, from: day))
        }
    }

    /// Keeps foreground banners working for the app's lifetime.
    @ObservationIgnored let notificationDelegate = CoachNotificationDelegate()

    private init() {
        let prefs = CoachPreferences()
        intensity = prefs.intensity
        notifications = prefs.notifications
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
                      "time": coordinator.nextAlarm?.plan.timeText ?? "07:00",
                      "name": ProfileName.shared.name]
        return lines.line(for: state.context, intensity: intensity, day: now, variant: rings, values: values)
    }
}

extension DaySummary {
    init(log: DayLog) {
        self.init(day: log.day, completed: log.missionCompletedAt != nil,
                  reArms: log.reArmCount, failSafe: log.failSafeTriggered,
                  completedAt: log.missionCompletedAt)
    }
}

/// The character's face: Gloop the slime, drooping with the user's vitality and showing the mood.
/// Every coach view goes through here, so swapping the character is one place.
struct CoachAvatarView: View {
    let state: CoachState
    var size: CGFloat = 96
    /// Override for previews; otherwise the user's current vitality.
    var vitality: Double? = nil
    /// Override for previews; otherwise the current stage's accessory.
    var accessory: SlimeAccessory? = nil

    var body: some View {
        SlimeView(look: SlimeLook.make(vitality: vitality ?? CoachModel.shared.vitality, state: state,
                                       accessory: accessory ?? CoachModel.shared.rank.accessory),
                  color: AppearanceSettings.shared.slimeColor, size: size)
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
                Text(CoachIdentity.name)
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
