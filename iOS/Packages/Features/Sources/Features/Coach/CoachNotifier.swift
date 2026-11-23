import AlarmEngine
import Coach
import Core
import Foundation
import os
import UserNotifications

private let log = Logger(subsystem: "be.gloop.app", category: "coach")

/// Keeps the coach's local notifications in sync with the alarms and today's result.
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
        guard settings.anyEnabled, status == .authorized || status == .provisional else { return }

        let calendar = Calendar.current
        let streak = StreakCalculator.currentStreak(completedDays: completedDays, today: now)
        let todayKey = NotificationPlanner.dayKey(now, calendar)
        let planned = NotificationPlanner.plan(
            now: now,
            upcomingAlarms: NotificationPlanner.upcomingRings(plans: coordinator.plans, from: now, calendar: calendar),
            settings: settings,
            streak: streak,
            session: coordinator.session,
            alreadyRoastedToday: preferences.lastRoastDay == todayKey,
            intensity: preferences.intensity,
            lines: CoachModel.shared.lines,
            pause: coordinator.activePause,
            onboarded: OnboardingStore().load().completed,
            name: ProfileName.shared.name,
            calendar: calendar)

        for item in planned {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            if let route = item.route { content.userInfo = [CoachNotification.routeKey: route.rawValue] }
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

    /// Developer tools: a coach notification in a few seconds.
    func sendTest(after seconds: TimeInterval = 5) async {
        let content = UNMutableNotificationContent()
        content.title = CoachIdentity.name
        content.body = CoachModel.shared.lines.line(for: .ringing, intensity: preferences.intensity, day: .now)
        content.sound = .default
        let request = UNNotificationRequest(identifier: "\(CoachNotification.idPrefix)test",
                                            content: content,
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false))
        try? await center.add(request)
    }
}

/// Shows coach notifications as banners even while the app is open, and routes taps
/// ("set your alarm" → `ReminderRouter`).
/// Completion-handler variants on purpose: the `async` ones run off the main thread and then call
/// UIKit's completion handler there → "Call must be made on main thread" crash on tap (found on device).
final class CoachNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        nonisolated(unsafe) let done = completionHandler
        DispatchQueue.main.async { done([.banner, .sound, .list]) }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let isTap = response.actionIdentifier == UNNotificationDefaultActionIdentifier
        let route = response.notification.request.content.userInfo[CoachNotification.routeKey] as? String
        nonisolated(unsafe) let done = completionHandler
        DispatchQueue.main.async {
            if isTap { MainActor.assumeIsolated { ReminderRouter.shared.open(route: route) } }
            done()
        }
    }
}
