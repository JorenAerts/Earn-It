import Core
import Foundation

/// Pure decision: what happens when a ringing alarm is ended (Stop slider or Start mission).
public enum ReArmDecision: Equatable, Sendable {
    /// Mission already done today: let it end.
    case done
    /// Schedule a follow-up alarm.
    case reArm(at: Date, attempt: Int)
    /// Too many follow-ups: stop for good so nobody gets stuck.
    case failSafe
}

public enum ReArmPolicy {
    public static func decide(session: SessionState, plan: AlarmPlan, now: Date) -> ReArmDecision {
        if session.missionDone { return .done }
        if session.failSafeTriggered || session.reArmCount >= plan.maxReArms { return .failSafe }
        let fire = now.addingTimeInterval(TimeInterval(max(1, plan.reArmMinutes) * 60))
        return .reArm(at: fire, attempt: session.reArmCount + 1)
    }

    /// A session is one ring cycle. Starts fresh on a new day, or when an alarm rings
    /// (`newRing`) after the previous cycle finished — on finish every other alarm is
    /// cancelled, so any later ring is necessarily a new one.
    public static func currentSession(_ stored: SessionState?, now: Date, newRing: Bool = false,
                                      calendar: Calendar = .current) -> SessionState {
        let today = calendar.startOfDay(for: now)
        if let stored, calendar.isDate(stored.day, inSameDayAs: today), !(newRing && stored.isFinished) {
            return stored
        }
        return SessionState(day: today)
    }
}
