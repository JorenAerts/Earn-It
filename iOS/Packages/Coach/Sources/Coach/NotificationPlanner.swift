import Core
import Foundation
import Localization

/// A local notification in the coach's voice.
public struct CoachNotification: Equatable, Sendable {
    public let id: String
    public let date: Date
    public let title: String
    public let body: String
    /// What a tap opens (`userInfo["route"]`); nil = just the app.
    public let route: Route?

    public enum Route: String, Sendable {
        /// "Set your alarm": new-alarm editor, or the Alarms tab when alarms exist (`SetAlarmTap`).
        case setAlarm
    }

    public init(id: String, date: Date, title: String = CoachIdentity.name, body: String, route: Route? = nil) {
        self.id = id
        self.date = date
        self.title = title
        self.body = body
        self.route = route
    }

    public static let idPrefix = "coach."
    public static let routeKey = "route"
}

public struct CoachNotificationSettings: Equatable, Sendable {
    /// "Coach reminders": the evening before each alarm + the roast after a fail-safe.
    public var enabled: Bool
    /// "Remind me to set an alarm": at the evening time when tomorrow has no alarm. Independent of `enabled`.
    public var remindNoAlarm: Bool
    /// Evening reminder time, shared by both reminders.
    public var eveningHour: Int
    public var eveningMinute: Int

    public init(enabled: Bool, remindNoAlarm: Bool = true, eveningHour: Int = 22, eveningMinute: Int = 0) {
        self.enabled = enabled
        self.remindNoAlarm = remindNoAlarm
        self.eveningHour = eveningHour
        self.eveningMinute = eveningMinute
    }

    /// Anything to schedule at all (and so: needs notification permission).
    public var anyEnabled: Bool { enabled || remindNoAlarm }
}

/// Pure: which coach notifications should be pending right now.
public enum NotificationPlanner {
    /// Don't remind if the alarm is less than this far after the evening reminder.
    public static let minimumLeadTime: TimeInterval = 30 * 60
    public static let horizonDays = 7
    /// Reminder times before this hour (e.g. 00:30) are about that same morning; any later time
    /// (evening, or a daytime test) is about tomorrow. Was `< 12`, which made a 10:35 reminder look at
    /// today and say "no alarm" although tomorrow had one (found on device, 23 Nov 2026).
    public static let afterMidnightCutoffHour = 6

    static func remindsSameDay(_ hour: Int) -> Bool { hour < afterMidnightCutoffHour }

    /// The day a reminder at `date` is about.
    public static func targetDay(forReminderAt date: Date, calendar: Calendar = .current) -> Date? {
        let day = calendar.startOfDay(for: date)
        return remindsSameDay(calendar.component(.hour, from: date)) ? day : calendar.date(byAdding: .day, value: 1, to: day)
    }

    /// Every ring of the enabled plans within `days` days after `now` (pause not applied).
    /// A one-off ("Once", no weekdays) rings only once: `nextFireDate` would return it every day.
    public static func upcomingRings(plans: [AlarmPlan], from now: Date, days: Int = horizonDays,
                                     calendar: Calendar = .current) -> [Date] {
        let horizon = now.addingTimeInterval(TimeInterval(days) * 86_400)
        var dates: [Date] = []
        for plan in plans where plan.isEnabled {
            var cursor = now
            while let next = plan.nextFireDate(after: cursor, calendar: calendar), next <= horizon {
                dates.append(next)
                if plan.weekdays.isEmpty { break }
                cursor = next
            }
        }
        return dates.sorted()
    }

    public static func plan(now: Date,
                            upcomingAlarms: [Date],
                            settings: CoachNotificationSettings,
                            streak: Int,
                            session: SessionState?,
                            alreadyRoastedToday: Bool,
                            intensity: CoachIntensity,
                            lines: CoachLines,
                            pause: AlarmPause? = nil,
                            onboarded: Bool = true,
                            name: String = "",
                            calendar: Calendar = .current) -> [CoachNotification] {
        guard settings.anyEnabled else { return [] }
        var result: [CoachNotification] = []
        let horizon = now.addingTimeInterval(TimeInterval(horizonDays) * 86_400)
        let rings = PausePolicy.filter(upcomingAlarms, pause: pause, now: now).filter { $0 > now && $0 <= horizon }

        if settings.remindNoAlarm, onboarded {
            result += setAlarmReminders(now: now, rings: rings, horizon: horizon, settings: settings,
                                        intensity: intensity, lines: lines, pause: pause, name: name, calendar: calendar)
        }
        guard settings.enabled else { return result.sorted { $0.date < $1.date } }

        // Evening reminders: the evening before each alarm day (earliest alarm per day).
        // Paused days have no alarm, so no reminder; the first day back gets a "leave's over".
        let byDay = Dictionary(grouping: rings) { calendar.startOfDay(for: $0) }
        let firstDayBack = PausePolicy.isPaused(pause, at: now) ? rings.min().map { calendar.startOfDay(for: $0) } : nil
        for (day, alarms) in byDay.sorted(by: { $0.key < $1.key }) {
            guard let alarm = alarms.min(),
                  let eveBefore = calendar.date(byAdding: .day, value: -1, to: day),
                  let evening = calendar.date(bySettingHour: settings.eveningHour, minute: settings.eveningMinute,
                                              second: 0, of: eveBefore)
            else { continue }
            // Reminder times after midnight (e.g. 00:30) belong to the alarm day itself.
            let reminder = remindsSameDay(settings.eveningHour)
                ? (calendar.date(bySettingHour: settings.eveningHour, minute: settings.eveningMinute, second: 0, of: day) ?? evening)
                : evening
            guard reminder > now, alarm.timeIntervalSince(reminder) >= minimumLeadTime else { continue }
            let time = alarm.localized(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
            var body = lines.line(for: .night, intensity: intensity, day: day, values: ["time": time], calendar: calendar)
            if day == firstDayBack { body = L10n.tr("Break's over! I'm back tomorrow, ready to bounce. ") + body }
            if streak >= 3 { body += " " + L10n.tr("Your \(streak)-day streak is on the line.") }
            result.append(CoachNotification(id: "\(CoachNotification.idPrefix)evening.\(dayKey(day, calendar))",
                                            date: reminder, body: body))
        }

        // Roast after a fail-safe, once.
        if let session, session.failSafeTriggered, !session.missionDone, !alreadyRoastedToday,
           calendar.isDate(session.day, inSameDayAs: now) {
            let body = lines.line(for: .failSafe, intensity: intensity, day: now, calendar: calendar)
            result.append(CoachNotification(id: "\(CoachNotification.idPrefix)roast.\(dayKey(now, calendar))",
                                            date: now.addingTimeInterval(60), body: body))
        }
        return result.sorted { $0.date < $1.date }
    }

    /// "Set your alarm": at the evening time before each day without an alarm (paused days excluded).
    /// Only days fully inside the horizon, so a ring just past the horizon can't look like "no alarm".
    static func setAlarmReminders(now: Date, rings: [Date], horizon: Date, settings: CoachNotificationSettings,
                                  intensity: CoachIntensity, lines: CoachLines, pause: AlarmPause?,
                                  name: String, calendar: Calendar) -> [CoachNotification] {
        let alarmDays = Set(rings.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: now)
        var result: [CoachNotification] = []
        for offset in 0...horizonDays {
            guard let evening = calendar.date(byAdding: .day, value: offset, to: today)
                    .flatMap({ calendar.date(bySettingHour: settings.eveningHour, minute: settings.eveningMinute,
                                             second: 0, of: $0) }),
                  evening > now,
                  let target = targetDay(forReminderAt: evening, calendar: calendar),
                  let targetEnd = calendar.date(byAdding: .day, value: 1, to: target), targetEnd <= horizon
            else { continue }
            guard !alarmDays.contains(target), !PausePolicy.isPaused(pause, at: target) else { continue }
            let body = lines.line(for: .setAlarm, intensity: intensity, day: target,
                                  values: ["name": name], calendar: calendar)
            result.append(CoachNotification(id: "\(CoachNotification.idPrefix)setAlarm.\(dayKey(target, calendar))",
                                            date: evening, body: body, route: .setAlarm))
        }
        return result
    }

    public static func dayKey(_ date: Date, _ calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
