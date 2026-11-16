import SwiftUI

/// One-shot confetti for the success screen, drawn in code. Pieces burst up from the top centre,
/// tumble down and fade out after about 3 seconds. With Reduce Motion: a short sparkle fade instead.
struct ConfettiBurst: View {
    var colors: [Color] = [.orange, .yellow, .pink, .green, .mint, .purple]
    var count = 70
    var duration: Double = 3.2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date?
    @State private var pieces: [Piece] = []

    struct Piece {
        let x: Double          // start, 0…1 of the width
        let vx: Double         // sideways speed, widths per second
        let vy: Double         // upward kick, heights per second
        let spin: Double       // radians per second
        let size: CGSize
        let color: Int
        let round: Bool
    }

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { timeline in
            Canvas { context, size in
                guard let start else { return }
                let t = timeline.date.timeIntervalSince(start)
                guard t < duration else { return }
                for piece in pieces { draw(piece, at: t, in: &context, size: size) }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard start == nil else { return }
            pieces = (0..<count).map { _ in
                Piece(x: .random(in: 0.3...0.7), vx: .random(in: -0.45...0.45), vy: .random(in: 0.55...1.1),
                      spin: .random(in: -9...9), size: CGSize(width: .random(in: 6...11), height: .random(in: 9...16)),
                      color: .random(in: 0..<colors.count), round: Bool.random())
            }
            start = .now
        }
    }

    private func draw(_ piece: Piece, at t: Double, in context: inout GraphicsContext, size: CGSize) {
        let fade = max(0, min(1, (duration - t) / 0.8))
        if reduceMotion {
            // No movement: pieces appear where they would land and fade away.
            let point = CGPoint(x: piece.x * size.width + piece.vx * size.width * 0.6,
                                y: size.height * (0.15 + piece.vy * 0.3))
            context.opacity = fade * 0.8
            context.fill(Path(ellipseIn: CGRect(origin: point, size: CGSize(width: 6, height: 6))),
                         with: .color(colors[piece.color]))
            return
        }
        let gravity = 1.4  // heights per second²
        let x = (piece.x + piece.vx * t) * size.width
        let y = (0.12 - piece.vy * t + 0.5 * gravity * t * t) * size.height
        var c = context
        c.opacity = fade
        c.translateBy(x: x, y: y)
        c.rotate(by: .radians(piece.spin * t))
        // Flutter: squash the width as the piece turns.
        c.scaleBy(x: cos(piece.spin * t * 0.7), y: 1)
        let rect = CGRect(x: -piece.size.width / 2, y: -piece.size.height / 2,
                          width: piece.size.width, height: piece.round ? piece.size.width : piece.size.height)
        let path = piece.round ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 2)
        c.fill(path, with: .color(colors[piece.color]))
    }
}
