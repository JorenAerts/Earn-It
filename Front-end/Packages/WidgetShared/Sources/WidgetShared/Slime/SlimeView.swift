import Coach
import SwiftUI

/// How the slime looks: long-term droop from vitality, expression from the mood, plus a live
/// overlay while the alarm rings (each re-ring melts and reddens him a bit more).
public struct SlimeLook: Equatable, Sendable {
    public var pose: SlimePose
    /// Breathing / bounce amplitude 0…1.
    public var bounce: Double
    /// Trembling 0…1 (anger).
    public var tremble: Double

    public static func make(vitality: Double, state: CoachState, accessory: SlimeAccessory = .none) -> SlimeLook {
        let v = min(1, max(0, vitality))
        var droop = 1 - v
        var pose = SlimePose(droop: droop,
                             eyes: v >= 0.8 ? .sparkly : v >= 0.5 ? .open : v >= 0.25 ? .sleepy : .teary,
                             mouth: v >= 0.8 ? .grin : v >= 0.5 ? .smile : v >= 0.25 ? .flat : .frown,
                             blush: v >= 0.7, sparkle: v >= 0.8, saturation: 0.55 + 0.45 * v, accessory: accessory)
        var bounce = 0.3 + 0.7 * v
        var tremble = 0.0
        switch state.mood {
        case .proud:
            // Mission done: puffs up and sparkles, whatever the history.
            droop = max(0, droop - 0.35)
            pose.eyes = .sparkly
            pose.mouth = .grin
            pose.blush = true
            pose.sparkle = true
            pose.saturation = max(pose.saturation, 0.9)
            bounce = max(bounce, 0.9)
        case .calm:
            break
        case .suspicious:
            pose.eyes = .squint
            pose.mouth = .flat
            pose.sweat = true
            pose.sparkle = false
        case .angry:
            let anger = state.anger
            droop = min(1, droop + 0.25 * anger)
            pose.redness = 0.25 + 0.55 * anger
            pose.eyes = .squint
            pose.mouth = anger > 0.5 ? .open : .frown
            pose.steam = anger >= 0.6
            pose.blush = false
            pose.sparkle = false
            tremble = anger
        case .disappointed:
            droop = min(1, droop + 0.2)
            pose.eyes = .teary
            pose.mouth = .frown
            pose.blush = false
            pose.sparkle = false
            pose.saturation = min(pose.saturation, 0.7)
        }
        pose.droop = droop
        pose.drips = droop >= 0.75 ? 3 : droop >= 0.5 ? 2 : droop >= 0.3 ? 1 : 0
        return SlimeLook(pose: pose, bounce: bounce, tremble: tremble)
    }
}

/// The animated slime. Droop changes melt / spring smoothly; it breathes and trembles over time.
public struct SlimeView: View {
    let look: SlimeLook
    var color: SlimeColor
    var size: CGFloat
    /// Widgets draw a single still frame.
    var animated: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(look: SlimeLook, color: SlimeColor = .orange, size: CGFloat = 96, animated: Bool = true) {
        self.look = look
        self.color = color
        self.size = size
        self.animated = animated
    }

    public var body: some View {
        let moving = animated && !reduceMotion
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !moving)) { context in
            let t = moving ? context.date.timeIntervalSinceReferenceDate : 0
            SlimeFigure(droop: look.pose.droop, pose: look.pose, color: color,
                        squash: sin(t * 2.6) * look.bounce, time: t)
                .offset(x: look.tremble > 0.3 ? sin(t * 42) * size * 0.025 * look.tremble * max(0, sin(t * 2.4)) : 0,
                        y: -abs(sin(t * 2.6)) * size * 0.02 * look.bounce * (1 - look.pose.droop))
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.8, dampingFraction: 0.55), value: look.pose.droop)
        .accessibilityElement()
        .accessibilityLabel("\(CoachIdentity.name), \(description)")
    }

    private var description: String {
        switch look.pose.droop {
        case ..<0.25: "bouncy and happy"
        case ..<0.5: "doing fine"
        case ..<0.75: "drooping"
        default: "melted into a puddle"
        }
    }
}

extension Rank {
    /// What Gloop wears at this stage.
    public var accessory: SlimeAccessory {
        switch self {
        case .droplet: .none
        case .blob: .sprout
        case .jelly: .bow
        case .gloopling: .sweatband
        case .bouncer: .cap
        case .squisher: .headphones
        case .wobbler: .sunglasses
        case .megaGloop: .scarf
        case .superGloop: .halo
        case .royalGloop: .tiara
        case .kingGloop: .crown
        }
    }
}

/// Animatable wrapper so changes in droop melt smoothly.
struct SlimeFigure: View, Animatable {
    var droop: Double
    let pose: SlimePose
    let color: SlimeColor
    let squash: Double
    let time: Double

    nonisolated var animatableData: Double {
        get { droop }
        set { droop = newValue }
    }

    var body: some View {
        Canvas { ctx, size in
            var p = pose
            p.droop = droop
            SlimeRenderer.draw(ctx, size: size, pose: p, color: color, squash: squash, time: time)
        }
    }
}
