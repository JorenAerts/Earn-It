import AlarmEngine
import Coach
import Core
import Foundation
import os
import UserNotifications

private let log = Logger(subsystem: "be.earnit.app", category: "coach")

/// Keeps Sergeant Rise's local notifications in sync with the alarms and today's result.
/// Only touches notifications whose id starts with `coach.`.
@MainActor
final class CoachNotifier {
    static let shared = CoachNotifier()

    private let center = UNUserNotificationCenter.current()
    private let preferences = CoachPreferences()
    /// Latest completed mission days (for the streak line); set by RootView.
    var completedDays: [Date] = []

    /// Asks for permission. Returns whether notifications may be shown.
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func authorizationDenied() async -> Bool {
        await center.notificationSettings().authorizationStatus == .denied
    }

    func refresh(coordinator: AlarmCoordinator, now: Date = .now) async {
        let pending = await center.pendingNotificationRequests().map(\.identifier)
            .filter { $0.hasPrefix(CoachNotification.idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        let settings = preferences.notifications
        let status = await center.notificationSettings().authorizationStatus
        guard settings.enabled, status == .authorized || status == .provisional else { return }

        let calendar = Calendar.current
        let streak = StreakCalculator.currentStreak(completedDays: completedDays, today: now)
        let todayKey = NotificationPlanner.dayKey(now, calendar)
        let planned = NotificationPlanner.plan(
            now: now,
            upcomingAlarms: Self.upcomingAlarms(coordinator.plans, from: now, days: NotificationPlanner.horizonDays),
            settings: settings,
            streak: streak,
            session: coordinator.session,
            alreadyRoastedToday: preferences.lastRoastDay == todayKey,
            intensity: preferences.intensity,
            lines: CoachModel.shared.lines,
            calendar: calendar)

        for item in planned {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.date)
            let request = UNNotificationRequest(identifier: item.id, content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            do {
                try await center.add(request)
            } catch {
                log.error("schedule \(item.id, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        if planned.contains(where: { $0.id.contains(".roast.") }) { preferences.lastRoastDay = todayKey }
        log.info("coach notifications scheduled: \(planned.count)")
    }

    #if DEBUG
    func sendTest(after seconds: TimeInterval = 5) async {
        let content = UNMutableNotificationContent()
        content.title = "Sergeant Rise"
        content.body = CoachModel.shared.lines.line(for: .ringing, intensity: preferences.intensity, day: .now)
        content.sound = .default
        let request = UNNotificationRequest(identifier: "\(CoachNotification.idPrefix)test",
                                            content: content,
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false))
        try? await center.add(request)
    }
    #endif

    /// All rings of enabled alarms within `days` days.
    static func upcomingAlarms(_ plans: [AlarmPlan], from now: Date, days: Int) -> [Date] {
        let horizon = now.addingTimeInterval(TimeInterval(days) * 86_400)
        var dates: [Date] = []
        for plan in plans where plan.isEnabled {
            var cursor = now
            while let next = plan.nextFireDate(after: cursor), next <= horizon {
                dates.append(next)
                cursor = next
            }
        }
        return dates.sorted()
    }
}

/// Shows coach notifications as banners even while the app is open.
final class CoachNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
