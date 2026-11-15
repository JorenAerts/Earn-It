import AlarmKit
import Foundation

/// Carried with every alarm; read by the Live Activity widget to render title + countdown.
public struct GloopAlarmMetadata: AlarmMetadata {
    /// "Gloop - Math Problem"
    public var title: String
    /// 0 = first ring, 1+ = re-rings after Stop.
    public var attempt: Int

    public init(title: String, attempt: Int) {
        self.title = title
        self.attempt = attempt
    }
}
