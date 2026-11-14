import Core
import Foundation

/// What each tier may use. Free: 1 alarm, Math, Classic Beep. Pro: everything.
/// The ringing / mission path is never gated — only creating and editing alarms.
public struct FeatureGate: Equatable, Sendable {
    public let isPro: Bool

    public init(isPro: Bool) {
        self.isPro = isPro
    }

    public init(_ state: EntitlementState) {
        self.init(isPro: state.isPro)
    }

    public static let freeMissions: Set<MissionKind> = [.math]
    public static let freeSounds: Set<AlarmSound> = [.classic]
    public static let freeAlarmLimit = 1

    /// nil = unlimited.
    public var maxAlarms: Int? { isPro ? nil : Self.freeAlarmLimit }

    public func canAddAlarm(currentCount: Int) -> Bool {
        maxAlarms.map { currentCount < $0 } ?? true
    }

    /// Switching an alarm on: free users may have one alarm enabled at a time.
    public func canEnableAlarm(enabledCount: Int) -> Bool {
        maxAlarms.map { enabledCount < $0 } ?? true
    }

    public func isLocked(_ mission: MissionKind) -> Bool {
        !isPro && !Self.freeMissions.contains(mission)
    }

    public func isLocked(_ sound: AlarmSound) -> Bool {
        !isPro && !Self.freeSounds.contains(sound)
    }

    /// Own sounds and Apple Music are Pro; built-ins follow `freeSounds`.
    public func isLocked(_ choice: SoundChoice) -> Bool {
        guard !isPro else { return false }
        if case .builtIn(let sound) = choice { return isLocked(sound) }
        return true
    }

    /// The plan uses something the tier doesn't allow.
    public func isAllowed(_ plan: AlarmPlan) -> Bool {
        !isLocked(plan.sound) && !plan.missions.contains { isLocked($0.kind) }
    }
}

/// Brings alarms within the free tier when Pro ends. Never deletes anything: extra alarms are
/// switched off (back on as soon as Pro returns, by the user), locked missions become Math and
/// locked sounds become Classic Beep — so no alarm ever stops ringing without the user knowing.
public enum DowngradePolicy {
    public enum Change: Hashable, Sendable {
        case alarmTurnedOff(time: String)
        case missionsReplaced(time: String)
        case soundReplaced(time: String, from: String)
    }

    public static func apply(to plans: [AlarmPlan], gate: FeatureGate) -> (plans: [AlarmPlan], changes: [Change]) {
        guard !gate.isPro else { return (plans, []) }
        var result = plans
        var changes: [Change] = []
        // Keep the first enabled alarm (list order) on; switch the others off.
        let keeperIndex = result.firstIndex(where: \.isEnabled) ?? result.indices.first
        for index in result.indices {
            if index != keeperIndex, result[index].isEnabled {
                result[index].isEnabled = false
                changes.append(.alarmTurnedOff(time: result[index].timeText))
            }
        }
        if let keeperIndex {
            var keeper = result[keeperIndex]
            let allowed = keeper.missions.filter { !gate.isLocked($0.kind) }
            if allowed.count != keeper.missions.count {
                keeper.missions = allowed.isEmpty ? [MissionConfig(kind: .math)] : allowed
                changes.append(.missionsReplaced(time: keeper.timeText))
            }
            if gate.isLocked(keeper.sound) {
                changes.append(.soundReplaced(time: keeper.timeText, from: keeper.sound.displayName))
                keeper.sound = .classic
            }
            result[keeperIndex] = keeper
        }
        return (result, changes)
    }
}

extension DowngradePolicy.Change {
    public var message: String {
        switch self {
        case .alarmTurnedOff(let time): "Alarm \(time) was switched off (free plan: 1 alarm)."
        case .missionsReplaced(let time): "Alarm \(time) now uses the Math mission."
        case .soundReplaced(let time, let from): "Alarm \(time) now uses Classic Beep instead of \(from)."
        }
    }
}
