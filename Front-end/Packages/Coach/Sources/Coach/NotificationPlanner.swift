import Core
import Foundation

/// A local notification in Sergeant Rise's voice.
public struct CoachNotification: Equatable, Sendable {
    public let id: String
    public let date: Date
    public let title: String
    public let body: String

    public init(id: String, date: Date, title: String = "Sergeant Rise", body: String) {
        self.id = id
        self.date = date
        self.title = title
        self.body = body
    }

    public static let idPrefix = "coach."
}

public struct CoachNotificationSettings: Equatable, Sendable {
    public var enabled: Bool
    public var eveningHour: Int
    public var eveningMinute: Int

    public init(enabled: Bool, eveningHour: Int = 22, eveningMinute: Int = 0) {
        self.enabled = enabled
        self.eveningHour = eveningHour
        self.eveningMinute = eveningMinute
    }
}

/// Pure: which coach notifications should be pending right now.
public enum NotificationPlanner {
    /// Don't remind if the alarm is less than this far after the evening reminder.
    public static let minimumLeadTime: TimeInterval = 30 * 60
    public static let horizonDays = 7

    public static func plan(now: Date,
                            upcomingAlarms: [Date],
                            settings: CoachNotificationSettings,
                            streak: Int,
                            session: SessionState?,
                            alreadyRoastedToday: Bool,
                            intensity: CoachIntensity,
                            lines: CoachLines,
                            calendar: Calendar = .current) -> [CoachNotification] {
        guard settings.enabled else { return [] }
        var result: [CoachNotification] = []
        let horizon = now.addingTimeInterval(TimeInterval(horizonDays) * 86_400)

        // Evening reminders: the evening before each alarm day (earliest alarm per day).
        let byDay = Dictionary(grouping: upcomingAlarms.filter { $0 > now && $0 <= horizon }) {
            calendar.startOfDay(for: $0)
        }
        for (day, alarms) in byDay.sorted(by: { $0.key < $1.key }) {
            guard let alarm = alarms.min(),
                  let eveBefore = calendar.date(byAdding: .day, value: -1, to: day),
                  let evening = calendar.date(bySettingHour: settings.eveningHour, minute: settings.eveningMinute,
                                              second: 0, of: eveBefore)
            else { continue }
            // Evening reminder after midnight settings (e.g. 00:30) belong to the alarm day itself.
            let reminder = settings.eveningHour < 12
                ? (calendar.date(bySettingHour: settings.eveningHour, minute: settings.eveningMinute, second: 0, of: day) ?? evening)
                : evening
            guard reminder > now, alarm.timeIntervalSince(reminder) >= minimumLeadTime else { continue }
            let time = alarm.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
            var body = lines.line(for: .night, intensity: intensity, day: day, values: ["time": time], calendar: calendar)
            if streak >= 3 { body += " Your \(streak)-day streak is on the line." }
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

    public static func dayKey(_ date: Date, _ calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
