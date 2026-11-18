import AlarmKit
import AVFoundation
import MusicKit
import Permissions
import Testing
import UserNotifications

struct PermissionMappingTests {
    @Test func systemStatusesMap() {
        #expect(PermissionMapping.alarms(.authorized) == .granted)
        #expect(PermissionMapping.alarms(.denied) == .denied)
        #expect(PermissionMapping.alarms(.notDetermined) == .notDetermined)
        #expect(PermissionMapping.notifications(.provisional) == .granted)
        #expect(PermissionMapping.notifications(.denied) == .denied)
        #expect(PermissionMapping.capture(.authorized) == .granted)
        #expect(PermissionMapping.capture(.restricted) == .unavailable)
        #expect(PermissionMapping.capture(.authorized, hardware: false) == .unavailable)
        #expect(PermissionMapping.microphone(.undetermined) == .notDetermined)
        #expect(PermissionMapping.microphone(.granted) == .granted)
        #expect(PermissionMapping.music(.restricted) == .unavailable)
        #expect(PermissionMapping.liveActivities(enabled: false) == .denied)
    }

    @Test func actions() {
        #expect(PermissionAction.for(.camera, .notDetermined) == .request)
        #expect(PermissionAction.for(.camera, .denied) == .openSettings)
        #expect(PermissionAction.for(.camera, .granted) == .none)
        #expect(PermissionAction.for(.camera, .unavailable) == .none, "no camera: nothing to open")
        #expect(PermissionAction.for(.liveActivities, .denied) == .openSettings)
        #expect(PermissionAction.for(.liveActivities, .notDetermined) == .openSettings, "can't be requested")
    }

    @Test func onboardingNeedsAlarmsOrExplicitSkip() {
        #expect(PermissionRules.canFinishOnboarding([.alarms: .denied, .notifications: .granted], skipped: false) == false)
        #expect(PermissionRules.canFinishOnboarding([.alarms: .granted], skipped: false))
        #expect(PermissionRules.canFinishOnboarding([.alarms: .denied], skipped: true))
    }

    @Test(arguments: PermissionKind.allCases)
    func everyKindIsDescribed(kind: PermissionKind) {
        #expect(kind.title.isEmpty == false)
        #expect(kind.reason.isEmpty == false)
        #expect(kind.blockedMessage.isEmpty == false)
        #expect(kind.symbol.isEmpty == false)
    }

    @Test func onlyAlarmsAreRequiredAndNotificationsOpenTheirOwnSettings() {
        #expect(PermissionKind.allCases.filter { $0.importance == .required } == [.alarms])
        #expect(PermissionKind.notifications.opensNotificationSettings)
        #expect(PermissionKind.camera.opensNotificationSettings == false)
    }
}
