import Foundation

/// Where the paywall was opened from (conversion per source).
public enum PaywallSource: String, Sendable, CaseIterable {
    case onboarding, settings, homeBanner, addAlarm, enableAlarm, lockedMission, lockedSound, mySounds, appleMusic
    case createClub, widget, downgradeNotice, developer, other
}

/// How the app was opened.
public enum LaunchSource: String, Sendable {
    case cold, alarm, widget, link, notification
}

/// Every analytics event Gloop sends. The catalog lives here so nothing else can send free text:
/// parameters are enums, counts, durations and buckets only — never names, emails, labels or
/// photos. See docs/Telemetry.md.
public enum TelemetryEvent: Equatable, Sendable {
    // App & sessions
    case appLaunched(source: LaunchSource)
    case appForegrounded
    case appBackgrounded(screen: String, secondsOnScreen: Int, sessionSeconds: Int)
    case screenViewed(screen: String)

    // Onboarding
    case onboardingStepViewed(step: String, index: Int)
    case onboardingStepCompleted(step: String, seconds: Int, answers: [String: String])
    case onboardingBack(from: String)
    case onboardingPermission(kind: String, granted: Bool)
    case onboardingInviteShared(completed: Bool)
    case onboardingSignIn(method: String)
    case onboardingCompleted(totalSeconds: Int, outcome: String)

    // Paywall & purchases
    case paywallShown(source: PaywallSource)
    case paywallPlanSelected(plan: String, source: PaywallSource)
    case paywallPlansUnavailable(source: PaywallSource)
    case purchaseStarted(plan: String, source: PaywallSource)
    case purchaseCompleted(plan: String, source: PaywallSource, trial: Bool)
    case purchaseCancelled(plan: String, source: PaywallSource)
    case purchaseFailed(plan: String, source: PaywallSource)
    case purchaseRestored(found: Bool)
    case paywallDismissed(source: PaywallSource, secondsShown: Int, purchased: Bool)
    case entitlementChanged(from: String, to: String)

    // Mornings & retention
    case alarmCreated(AlarmSummary)
    case alarmEdited(AlarmSummary)
    case alarmToggled(on: Bool)
    case alarmDeleted
    case alarmRang
    case alarmStopped(attempt: Int)
    case missionStarted(kinds: String, attempt: Int)
    case missionCompleted(kinds: String, rings: Int, secondsFromFirstRing: Int, firstTry: Bool)
    case missionBackupUsed(kind: String)
    case morningFailSafe(rings: Int)
    case streakMilestone(days: Int)
    case gloopEvolved(stage: String)
    case stickerEarned(sticker: String)
    case pauseSet(option: String)
    case pauseResumed

    // Features
    case action(TelemetryAction)

    // Errors (a short code, never the message text)
    case errorShown(area: String, code: String)

    /// Signal name, e.g. "Onboarding.stepCompleted".
    public var name: String {
        switch self {
        case .appLaunched: "App.launched"
        case .appForegrounded: "App.foregrounded"
        case .appBackgrounded: "App.backgrounded"
        case .screenViewed: "Screen.viewed"
        case .onboardingStepViewed: "Onboarding.stepViewed"
        case .onboardingStepCompleted: "Onboarding.stepCompleted"
        case .onboardingBack: "Onboarding.back"
        case .onboardingPermission: "Onboarding.permission"
        case .onboardingInviteShared: "Onboarding.inviteShared"
        case .onboardingSignIn: "Onboarding.signIn"
        case .onboardingCompleted: "Onboarding.completed"
        case .paywallShown: "Paywall.shown"
        case .paywallPlanSelected: "Paywall.planSelected"
        case .paywallPlansUnavailable: "Paywall.plansUnavailable"
        case .purchaseStarted: "Purchase.started"
        case .purchaseCompleted: "Purchase.completed"
        case .purchaseCancelled: "Purchase.cancelled"
        case .purchaseFailed: "Purchase.failed"
        case .purchaseRestored: "Purchase.restored"
        case .paywallDismissed: "Paywall.dismissed"
        case .entitlementChanged: "Entitlement.changed"
        case .alarmCreated: "Alarm.created"
        case .alarmEdited: "Alarm.edited"
        case .alarmToggled: "Alarm.toggled"
        case .alarmDeleted: "Alarm.deleted"
        case .alarmRang: "Alarm.rang"
        case .alarmStopped: "Alarm.stopped"
        case .missionStarted: "Mission.started"
        case .missionCompleted: "Mission.completed"
        case .missionBackupUsed: "Mission.backupUsed"
        case .morningFailSafe: "Morning.failSafe"
        case .streakMilestone: "Streak.milestone"
        case .gloopEvolved: "Gloop.evolved"
        case .stickerEarned: "Sticker.earned"
        case .pauseSet: "Pause.set"
        case .pauseResumed: "Pause.resumed"
        case .action(let action): action.name
        case .errorShown: "Error.shown"
        }
    }

    /// Parameters sent with the signal.
    public var parameters: [String: String] {
        switch self {
        case .appLaunched(let source): ["source": source.rawValue]
        case .appForegrounded, .alarmDeleted, .alarmRang, .pauseResumed: [:]
        case .appBackgrounded(let screen, let onScreen, let session):
            ["screen": screen, "secondsOnScreen": "\(onScreen)", "sessionSeconds": "\(session)",
             "sessionLength": TelemetryBuckets.duration(session)]
        case .screenViewed(let screen): ["screen": screen]
        case .onboardingStepViewed(let step, let index): ["step": step, "index": "\(index)"]
        case .onboardingStepCompleted(let step, let seconds, let answers):
            answers.merging(["step": step, "seconds": "\(seconds)"]) { _, new in new }
        case .onboardingBack(let from): ["from": from]
        case .onboardingPermission(let kind, let granted): ["kind": kind, "granted": "\(granted)"]
        case .onboardingInviteShared(let completed): ["completed": "\(completed)"]
        case .onboardingSignIn(let method): ["method": method]
        case .onboardingCompleted(let total, let outcome):
            ["totalSeconds": "\(total)", "duration": TelemetryBuckets.duration(total), "outcome": outcome]
        case .paywallShown(let source), .paywallPlansUnavailable(let source): ["source": source.rawValue]
        case .paywallPlanSelected(let plan, let source), .purchaseStarted(let plan, let source),
             .purchaseCancelled(let plan, let source), .purchaseFailed(let plan, let source):
            ["plan": plan, "source": source.rawValue]
        case .purchaseCompleted(let plan, let source, let trial):
            ["plan": plan, "source": source.rawValue, "trial": "\(trial)"]
        case .purchaseRestored(let found): ["found": "\(found)"]
        case .paywallDismissed(let source, let seconds, let purchased):
            ["source": source.rawValue, "secondsShown": "\(seconds)", "purchased": "\(purchased)"]
        case .entitlementChanged(let from, let to): ["from": from, "to": to]
        case .alarmCreated(let alarm), .alarmEdited(let alarm): alarm.parameters
        case .alarmToggled(let on): ["on": "\(on)"]
        case .alarmStopped(let attempt): ["attempt": "\(attempt)"]
        case .missionStarted(let kinds, let attempt): ["missions": kinds, "attempt": "\(attempt)"]
        case .missionCompleted(let kinds, let rings, let seconds, let firstTry):
            ["missions": kinds, "rings": "\(rings)", "secondsFromFirstRing": "\(seconds)",
             "wakeDuration": TelemetryBuckets.duration(seconds), "firstTry": "\(firstTry)"]
        case .missionBackupUsed(let kind): ["mission": kind]
        case .morningFailSafe(let rings): ["rings": "\(rings)"]
        case .streakMilestone(let days): ["days": "\(days)"]
        case .gloopEvolved(let stage): ["stage": stage]
        case .stickerEarned(let sticker): ["sticker": sticker]
        case .pauseSet(let option): ["option": option]
        case .action(let action): action.parameters
        case .errorShown(let area, let code): ["area": area, "code": code]
        }
    }
}

/// The shape of an alarm, without its label or anything personal.
public struct AlarmSummary: Equatable, Sendable {
    public var missions: String
    public var soundKind: String
    public var weekdaysCount: Int
    public var hour: Int
    public var reRingMinutes: Int
    public var alarmCount: Int

    public init(missions: String, soundKind: String, weekdaysCount: Int, hour: Int, reRingMinutes: Int, alarmCount: Int) {
        self.missions = missions
        self.soundKind = soundKind
        self.weekdaysCount = weekdaysCount
        self.hour = hour
        self.reRingMinutes = reRingMinutes
        self.alarmCount = alarmCount
    }

    var parameters: [String: String] {
        ["missions": missions, "soundKind": soundKind, "weekdaysCount": "\(weekdaysCount)",
         "wakeHour": TelemetryBuckets.hour(hour), "reRingMinutes": "\(reRingMinutes)", "alarmCount": "\(alarmCount)"]
    }
}

/// Feature usage.
public enum TelemetryAction: Equatable, Sendable {
    case clubCreated(isPublic: Bool)
    case clubJoined(via: String)
    case photoPosted(clubCount: Int)
    case photoSkipped
    case reacted
    case reported(kind: String)
    case blocked
    case soundImported, soundRecorded, appleMusicPicked
    case appearanceChanged(mode: String)
    case iconChanged(icon: String)
    case coachToneChanged(tone: String)
    case remindersToggled(on: Bool)
    case helpOpened
    case faqOpened(index: Int)
    case shareApp
    case rateRequested
    case signedIn(method: String)
    case signedOut
    case accountDeleted
    case permissionDenied(kind: String)
    case telemetryTest

    var name: String {
        switch self {
        case .clubCreated: "Buddies.clubCreated"
        case .clubJoined: "Buddies.joined"
        case .photoPosted: "Buddies.photoPosted"
        case .photoSkipped: "Buddies.photoSkipped"
        case .reacted: "Buddies.reacted"
        case .reported: "Buddies.reported"
        case .blocked: "Buddies.blocked"
        case .soundImported: "Sound.imported"
        case .soundRecorded: "Sound.recorded"
        case .appleMusicPicked: "Sound.appleMusicPicked"
        case .appearanceChanged: "Appearance.changed"
        case .iconChanged: "Icon.changed"
        case .coachToneChanged: "Coach.toneChanged"
        case .remindersToggled: "Reminders.toggled"
        case .helpOpened: "Help.opened"
        case .faqOpened: "Help.faqOpened"
        case .shareApp: "Share.app"
        case .rateRequested: "Rate.requested"
        case .signedIn: "Account.signedIn"
        case .signedOut: "Account.signedOut"
        case .accountDeleted: "Account.deleted"
        case .permissionDenied: "Permission.denied"
        case .telemetryTest: "Telemetry.test"
        }
    }

    var parameters: [String: String] {
        switch self {
        case .clubCreated(let isPublic): ["public": "\(isPublic)"]
        case .clubJoined(let via): ["via": via]
        case .photoPosted(let count): ["clubCount": "\(count)"]
        case .reported(let kind): ["kind": kind]
        case .appearanceChanged(let mode): ["mode": mode]
        case .iconChanged(let icon): ["icon": icon]
        case .coachToneChanged(let tone): ["tone": tone]
        case .remindersToggled(let on): ["on": "\(on)"]
        case .faqOpened(let index): ["question": "\(index)"]
        case .signedIn(let method): ["method": method]
        case .permissionDenied(let kind): ["kind": kind]
        default: [:]
        }
    }
}

/// Coarse buckets, so dashboards group nicely and nothing is too precise.
public enum TelemetryBuckets {
    public static func duration(_ seconds: Int) -> String {
        switch seconds {
        case ..<10: "<10s"
        case ..<30: "10-30s"
        case ..<60: "30-60s"
        case ..<180: "1-3m"
        case ..<600: "3-10m"
        case ..<1800: "10-30m"
        default: "30m+"
        }
    }

    public static func hour(_ hour: Int) -> String {
        switch hour {
        case ..<5: "before 5"
        case 5: "5-6"
        case 6: "6-7"
        case 7: "7-8"
        case 8: "8-9"
        case 9..<12: "9-12"
        default: "12+"
        }
    }

    public static func days(_ days: Int) -> String {
        switch days {
        case 0: "day 0"
        case 1: "day 1"
        case 2...6: "days 2-6"
        case 7...13: "week 2"
        case 14...29: "weeks 3-4"
        case 30...89: "month 2-3"
        default: "90d+"
        }
    }
}
