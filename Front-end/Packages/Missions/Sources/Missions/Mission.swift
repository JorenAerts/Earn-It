import Core
import SwiftUI

public enum MissionResult: Sendable, Equatable {
    case success
    /// The mission can't be done right now (e.g. the scanned item is gone, no camera):
    /// the runner swaps in the backup mission.
    case needsBackup
}

/// Plug-in contract: one folder per mission, registered in `MissionRegistry`.
public protocol Mission: Identifiable, Sendable {
    static var kind: MissionKind { get }
    var config: MissionConfig { get }
    /// The UI the user interacts with; calls `onComplete` once verified.
    @MainActor func makeView(onComplete: @escaping @MainActor (MissionResult) -> Void) -> AnyView
    /// Optional extra setup UI shown in the alarm editor (e.g. register a QR code).
    @MainActor static func makeSetupView(config: Binding<MissionConfig>) -> AnyView?
}

extension Mission {
    public var id: UUID { config.id }
    @MainActor public static func makeSetupView(config: Binding<MissionConfig>) -> AnyView? { nil }
}

@MainActor
public enum MissionRegistry {
    public static func make(_ config: MissionConfig) -> any Mission {
        switch config.kind {
        case .math: MathMission(config: config)
        case .shake: ShakeMission(config: config)
        case .qr: QRMission(config: config)
        case .object: ObjectMission(config: config)
        case .quiz: QuizMission(config: config)
        case .memory: MemoryMission(config: config)
        case .typing: TypingMission(config: config)
        case .sky: SkyMission(config: config)
        case .bed: BedMission(config: config)
        case .colorHunt: ColorHuntMission(config: config)
        }
    }

    public static func setupView(for config: Binding<MissionConfig>) -> AnyView? {
        switch config.wrappedValue.kind {
        case .math: MathMission.makeSetupView(config: config)
        case .shake: ShakeMission.makeSetupView(config: config)
        case .qr: QRMission.makeSetupView(config: config)
        case .object: ObjectMission.makeSetupView(config: config)
        case .quiz: QuizMission.makeSetupView(config: config)
        case .memory: MemoryMission.makeSetupView(config: config)
        case .typing: TypingMission.makeSetupView(config: config)
        case .sky: SkyMission.makeSetupView(config: config)
        case .bed: BedMission.makeSetupView(config: config)
        case .colorHunt: ColorHuntMission.makeSetupView(config: config)
        }
    }
}
