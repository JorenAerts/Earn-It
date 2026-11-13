import Core
import SwiftUI

public enum MissionResult: Sendable, Equatable {
    case success
}

/// Plug-in contract: one folder per mission, registered in `MissionRegistry`.
public protocol Mission: Identifiable, Sendable {
    static var kind: MissionKind { get }
    var config: MissionConfig { get }
    /// The UI the user interacts with; calls `onComplete` once verified.
    @MainActor func makeView(onComplete: @escaping @MainActor (MissionResult) -> Void) -> AnyView
}

extension Mission {
    public var id: UUID { config.id }
}

@MainActor
public enum MissionRegistry {
    public static func make(_ config: MissionConfig) -> any Mission {
        switch config.kind {
        case .math: MathMission(config: config)
        case .shake: ShakeMission(config: config)
        }
    }
}
