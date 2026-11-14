import Foundation

/// Every iOS permission Earn It uses. Adding one: a case here + mapping/request in
/// `PermissionCenter` + an Info.plist usage string (project.yml).
public enum PermissionKind: String, CaseIterable, Sendable, Identifiable {
    case alarms, notifications, camera, microphone, appleMusic, liveActivities

    public var id: String { rawValue }

    public enum Importance: Int, Comparable, Sendable {
        case required, recommended, optional, info
        public static func < (a: Importance, b: Importance) -> Bool { a.rawValue < b.rawValue }

        public var label: String {
            switch self {
            case .required: "Required"
            case .recommended: "Recommended"
            case .optional: "Optional"
            case .info: "Info"
            }
        }
    }

    public var title: String {
        switch self {
        case .alarms: "Alarms"
        case .notifications: "Notifications"
        case .camera: "Camera"
        case .microphone: "Microphone"
        case .appleMusic: "Apple Music"
        case .liveActivities: "Live Activities"
        }
    }

    public var symbol: String {
        switch self {
        case .alarms: "alarm.fill"
        case .notifications: "bell.badge.fill"
        case .camera: "camera.fill"
        case .microphone: "mic.fill"
        case .appleMusic: "music.note"
        case .liveActivities: "platter.filled.bottom.iphone"
        }
    }

    /// Why the app needs it, in one line.
    public var reason: String {
        switch self {
        case .alarms: "Your alarm rings through silent mode and Focus, even when the app is closed."
        case .notifications: "Evening reminders and a word from Sergeant Rise after a missed morning."
        case .camera: "Scan your code or item to stop the alarm."
        case .microphone: "Record your own alarm sound."
        case .appleMusic: "Wake up to a song from Apple Music."
        case .liveActivities: "Shows the re-ring countdown on the Lock Screen."
        }
    }

    /// Shown when a feature needs it but it's off.
    public var blockedMessage: String {
        switch self {
        case .alarms: "Without alarm access your alarms can't ring. Turn on Alarms for Earn It in Settings."
        case .notifications: "Turn on notifications for Earn It in Settings to get coach reminders."
        case .camera: "Earn It needs the camera to scan your code or item. Turn on Camera for Earn It in Settings."
        case .microphone: "Earn It needs the microphone to record your sound. Turn on Microphone for Earn It in Settings."
        case .appleMusic: "Turn on Media & Apple Music for Earn It in Settings to pick a song."
        case .liveActivities: "Turn on Live Activities for Earn It in Settings to see the re-ring countdown."
        }
    }

    public var importance: Importance {
        switch self {
        case .alarms: .required
        case .notifications: .recommended
        case .camera, .microphone, .appleMusic: .optional
        case .liveActivities: .info
        }
    }

    /// Live Activities can't be requested, only switched off by the user in Settings.
    public var canRequest: Bool { self != .liveActivities }

    /// Notifications have their own Settings page; everything else is on the app's page.
    public var opensNotificationSettings: Bool { self == .notifications }
}

public enum PermissionStatus: String, Sendable, Equatable {
    case notDetermined, granted, denied
    /// No hardware, or blocked by Screen Time / device management.
    case unavailable

    public var label: String {
        switch self {
        case .notDetermined: "Not asked"
        case .granted: "Allowed"
        case .denied: "Off"
        case .unavailable: "Unavailable"
        }
    }
}

/// What tapping a permission row does.
public enum PermissionAction: Equatable, Sendable {
    case request, openSettings, none

    public static func `for`(_ kind: PermissionKind, _ status: PermissionStatus) -> PermissionAction {
        switch status {
        case .granted: .none
        case .notDetermined: kind.canRequest ? .request : .openSettings
        case .denied: .openSettings
        case .unavailable: kind == .camera ? .none : .openSettings
        }
    }

    public var buttonTitle: String? {
        switch self {
        case .request: "Allow"
        case .openSettings: "Open Settings"
        case .none: nil
        }
    }
}

/// Onboarding may continue once required permissions are granted, or when the user explicitly
/// skips (they're warned on Home afterwards).
public enum PermissionRules {
    public static func canFinishOnboarding(_ statuses: [PermissionKind: PermissionStatus], skipped: Bool) -> Bool {
        skipped || PermissionKind.allCases.filter { $0.importance == .required }.allSatisfy { statuses[$0] == .granted }
    }
}
