import ActivityKit
import AlarmKit
import AVFoundation
import Foundation
import MusicKit
import Observation
import UIKit
import UserNotifications

/// Pure mapping from each framework's status to `PermissionStatus` (tested).
public enum PermissionMapping {
    public static func alarms(_ s: AlarmManager.AuthorizationState) -> PermissionStatus {
        switch s {
        case .authorized: .granted
        case .denied: .denied
        default: .notDetermined
        }
    }

    public static func notifications(_ s: UNAuthorizationStatus) -> PermissionStatus {
        switch s {
        case .authorized, .provisional, .ephemeral: .granted
        case .denied: .denied
        default: .notDetermined
        }
    }

    public static func capture(_ s: AVAuthorizationStatus, hardware: Bool = true) -> PermissionStatus {
        guard hardware else { return .unavailable }
        switch s {
        case .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .unavailable
        default: return .notDetermined
        }
    }

    public static func microphone(_ s: AVAudioApplication.recordPermission) -> PermissionStatus {
        switch s {
        case .granted: .granted
        case .denied: .denied
        default: .notDetermined
        }
    }

    public static func music(_ s: MusicAuthorization.Status) -> PermissionStatus {
        switch s {
        case .authorized: .granted
        case .denied: .denied
        case .restricted: .unavailable
        default: .notDetermined
        }
    }

    public static func liveActivities(enabled: Bool) -> PermissionStatus {
        enabled ? .granted : .denied
    }
}

/// One place that knows every permission's status, can ask for it, and opens the right Settings page.
/// `ensure(_:)` is what features call before they need a permission; when it's off, `blocked` is set
/// and the app-wide `.permissionPrompt()` explains it with an "Open Settings" button.
@MainActor
@Observable
public final class PermissionCenter {
    public static let shared = PermissionCenter()

    public private(set) var statuses: [PermissionKind: PermissionStatus] = [:]
    /// The permission a feature just needed but is off (drives the prompt).
    public var blocked: PermissionKind?

    public init() {}

    public func status(_ kind: PermissionKind) -> PermissionStatus { statuses[kind] ?? .notDetermined }
    public func isGranted(_ kind: PermissionKind) -> Bool { status(kind) == .granted }

    /// Re-reads every status (on launch and when the app becomes active, e.g. back from Settings).
    public func refresh() async {
        var new: [PermissionKind: PermissionStatus] = [:]
        new[.alarms] = PermissionMapping.alarms(AlarmManager.shared.authorizationState)
        new[.notifications] = PermissionMapping.notifications(await UNUserNotificationCenter.current().notificationSettings().authorizationStatus)
        new[.camera] = PermissionMapping.capture(AVCaptureDevice.authorizationStatus(for: .video),
                                                 hardware: AVCaptureDevice.default(for: .video) != nil)
        new[.microphone] = PermissionMapping.microphone(AVAudioApplication.shared.recordPermission)
        new[.appleMusic] = PermissionMapping.music(MusicAuthorization.currentStatus)
        new[.liveActivities] = PermissionMapping.liveActivities(enabled: ActivityAuthorizationInfo().areActivitiesEnabled)
        if new != statuses { statuses = new }
    }

    /// Shows the system dialog (first time only). Returns the resulting status.
    @discardableResult
    public func request(_ kind: PermissionKind) async -> PermissionStatus {
        switch kind {
        case .alarms:
            _ = try? await AlarmManager.shared.requestAuthorization()
        case .notifications:
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        case .camera:
            _ = await AVCaptureDevice.requestAccess(for: .video)
        case .microphone:
            _ = await AVAudioApplication.requestRecordPermission()
        case .appleMusic:
            _ = await MusicAuthorization.request()
        case .liveActivities:
            break
        }
        await refresh()
        return status(kind)
    }

    /// Call before using a feature. Asks if never asked; if off, shows the Settings prompt.
    public func ensure(_ kind: PermissionKind) async -> Bool {
        await refresh()
        switch status(kind) {
        case .granted:
            return true
        case .notDetermined where kind.canRequest:
            if await request(kind) == .granted { return true }
            blocked = kind
            return false
        default:
            blocked = kind
            return false
        }
    }

    /// Opens Earn It's page in the Settings app (notifications: its notification page).
    public func openSettings(_ kind: PermissionKind) {
        let string = kind.opensNotificationSettings ? UIApplication.openNotificationSettingsURLString
                                                    : UIApplication.openSettingsURLString
        if let url = URL(string: string) { UIApplication.shared.open(url) }
    }

    /// Runs the row's action: ask, or open Settings.
    public func perform(_ kind: PermissionKind) async {
        switch PermissionAction.for(kind, status(kind)) {
        case .request: await request(kind)
        case .openSettings: openSettings(kind)
        case .none: break
        }
    }
}
