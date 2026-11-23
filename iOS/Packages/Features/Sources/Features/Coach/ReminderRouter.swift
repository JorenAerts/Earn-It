import Coach
import Core
import Observation
import Telemetry
import UserNotifications

/// Where a tap on the "set your alarm" reminder lands. Pure.
public enum SetAlarmTap: Equatable, Sendable {
    /// No alarms at all: straight into the new-alarm editor.
    case newAlarm
    /// Alarms exist (just none tomorrow): the Alarms tab, so one can be switched on or get a day added.
    /// (A new alarm would hit the free plan's 1-alarm limit.)
    case alarmsList

    public static func destination(plans: [AlarmPlan]) -> SetAlarmTap {
        plans.isEmpty ? .newAlarm : .alarmsList
    }
}

/// Hands a notification tap to the UI: RootView switches to the Alarms tab, HomeView consumes it.
@MainActor @Observable
public final class ReminderRouter {
    public static let shared = ReminderRouter()
    public var pendingSetAlarm = false

    /// Call from `App.init`: a tap that cold-launches the app is only delivered if the delegate is
    /// set before launch finishes.
    public static func installNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = CoachModel.shared.notificationDelegate
    }

    func open(route: String?) {
        guard route == CoachNotification.Route.setAlarm.rawValue else { return }
        pendingSetAlarm = true
        Telemetry.shared.send(.action(.reminderOpened(kind: route ?? "")))
    }
}
