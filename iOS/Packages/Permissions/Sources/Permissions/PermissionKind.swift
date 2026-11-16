import Foundation
import Localization

/// Every iOS permission Gloop uses. Adding one: a case here + mapping/request in
/// `PermissionCenter` + an Info.plist usage string (project.yml).
public enum PermissionKind: String, CaseIterable, Sendable, Identifiable {
    case alarms, notifications, camera, microphone, appleMusic, liveActivities

    public var id: String { rawValue }

    public enum Importance: Int, Comparable, Sendable {
        case required, recommended, optional, info
        public static func < (a: Importance, b: Importance) -> Bool { a.rawValue < b.rawValue }

        public var label: String {
            switch self {
            case .required: L10n.tr("Required")
            case .recommended: L10n.tr("Recommended")
            case .optional: L10n.tr("Optional")
            case .info: L10n.tr("Info")
            }
        }
    }

    public var title: String {
        switch self {
        case .alarms: L10n.tr("Alarms")
        case .notifications: L10n.tr("Notifications")
        case .camera: L10n.tr("Camera")
        case .microphone: L10n.tr("Microphone")
        case .appleMusic: "Apple Music"
        case .liveActivities: L10n.tr("Live Activities")
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
        case .alarms: L10n.tr("Your alarm rings through silent mode and Focus, even when the app is closed.")
        case .notifications: L10n.tr("Evening reminders and a word from Gloop after a missed morning.")
        case .camera: L10n.tr("Scan your code or item to stop the alarm.")
        case .microphone: L10n.tr("Record your own alarm sound.")
        case .appleMusic: L10n.tr("Wake up to a song from Apple Music.")
        case .liveActivities: L10n.tr("Shows the re-ring countdown on the Lock Screen.")
        }
    }

    /// Shown when a feature needs it but it's off.
    public var blockedMessage: String {
        switch self {
        case .alarms: L10n.tr("Without alarm access your alarms can't ring. Turn on Alarms for Gloop in Settings.")
        case .notifications: L10n.tr("Turn on notifications for Gloop in Settings to get coach reminders.")
        case .camera: L10n.tr("Gloop needs the camera to scan your code or item. Turn on Camera for Gloop in Settings.")
        case .microphone: L10n.tr("Gloop needs the microphone to record your sound. Turn on Microphone for Gloop in Settings.")
        case .appleMusic: L10n.tr("Turn on Media & Apple Music for Gloop in Settings to pick a song.")
        case .liveActivities: L10n.tr("Turn on Live Activities for Gloop in Settings to see the re-ring countdown.")
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
        case .notDetermined: L10n.tr("Not asked")
        case .granted: L10n.tr("Allowed")
        case .denied: L10n.tr("Off")
        case .unavailable: L10n.tr("Unavailable")
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
        case .request: L10n.tr("Allow")
        case .openSettings: L10n.tr("Open Settings")
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

/// Settings home row: "All set" or "N need attention" (required / recommended ones that are off).
public enum PermissionSummary: Equatable, Sendable {
    case allSet
    case needsAttention(Int)

    public static func make(_ status: (PermissionKind) -> PermissionStatus) -> PermissionSummary {
        let missing = PermissionKind.allCases.filter { kind in
            kind.importance <= .recommended && [.denied, .notDetermined].contains(status(kind))
        }
        return missing.isEmpty ? .allSet : .needsAttention(missing.count)
    }

    public var text: String {
        switch self {
        case .allSet: L10n.tr("All set")
        case .needsAttention(let n): L10n.tr("\(n) need attention")
        }
    }
}
