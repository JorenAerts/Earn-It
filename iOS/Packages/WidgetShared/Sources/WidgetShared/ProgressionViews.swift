import Coach
import Localization
import SwiftUI

/// Evolution stage badge: a mini Gloop in a soft circle, bigger and better dressed each stage.
public struct RankInsignia: View {
    let rank: Rank
    var size: CGFloat

    public init(rank: Rank, size: CGFloat = 44) {
        self.rank = rank
        self.size = size
    }

    /// Droplet is small, King Gloop fills the badge.
    private var scale: CGFloat { 0.62 + 0.38 * CGFloat(rank.rawValue) / CGFloat(Rank.allCases.count - 1) }

    public var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Color(red: 1, green: 0.95, blue: 0.84), Color(red: 1, green: 0.84, blue: 0.62)],
                                         startPoint: .top, endPoint: .bottom))
            Circle().strokeBorder(Color.orange.opacity(0.55), lineWidth: max(1, size * 0.04))
            Canvas { ctx, canvas in
                let side = canvas.width * scale
                var c = ctx
                c.translateBy(x: (canvas.width - side) / 2, y: canvas.height - side - canvas.height * 0.02)
                SlimeRenderer.draw(c, size: CGSize(width: side, height: side),
                                   pose: SlimePose(droop: 0.05, eyes: .open, mouth: .smile, blush: true,
                                                   accessory: rank.accessory),
                                   color: .orange, shadow: false)
            }
            .clipShape(.circle)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(rank.title)
    }
}

/// Same view under the Gloop name.
public typealias StageBadge = RankInsignia

/// Stage card: badge, stage name, XP and progress to the next evolution.
public struct RankCard: View {
    let progress: RankProgress

    public init(progress: RankProgress) { self.progress = progress }

    public var body: some View {
        HStack(spacing: 14) {
            RankInsignia(rank: progress.rank, size: 56)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(progress.rank.title).font(.title3.weight(.bold))
                    Spacer()
                    Text("\(progress.xp.formatted()) XP").font(.subheadline.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: progress.fraction).tint(.orange)
                if let next = progress.next, let toGo = progress.xpToNext {
                    Text("\(toGo.formatted()) XP to \(next.title)").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Fully evolved. Long live King Gloop.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A sticker (achievement): die-cut white border, slight tilt, glossy; dashed outline while locked.
public struct MedalTile: View {
    let medal: Medal
    let earned: Bool

    public init(medal: Medal, earned: Bool) {
        self.medal = medal
        self.earned = earned
    }

    /// Stable little tilt per sticker.
    private var tilt: Double { Double((medal.rawValue.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 11) - 5) }

    private var colors: [Color] {
        let palette: [[Color]] = [
            [Color(red: 1, green: 0.72, blue: 0.3), Color(red: 0.96, green: 0.42, blue: 0.1)],
            [Color(red: 0.55, green: 0.95, blue: 0.78), Color(red: 0.12, green: 0.7, blue: 0.55)],
            [Color(red: 0.8, green: 0.62, blue: 1), Color(red: 0.5, green: 0.28, blue: 0.86)],
            [Color(red: 1, green: 0.6, blue: 0.75), Color(red: 0.9, green: 0.3, blue: 0.5)],
            [Color(red: 0.55, green: 0.75, blue: 1), Color(red: 0.2, green: 0.4, blue: 0.9)],
        ]
        return palette[(Medal.allCases.firstIndex(of: medal) ?? 0) % palette.count]
    }

    public var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if earned {
                    Circle().fill(.white)
                        .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
                    Circle().fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                        .padding(4)
                    Ellipse().fill(.white.opacity(0.35)).frame(width: 26, height: 12).offset(x: -8, y: -14)
                    Image(systemName: medal.symbol).font(.title2.weight(.bold)).foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                } else {
                    Circle().strokeBorder(Color.secondary.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    Image(systemName: "lock.fill").font(.title3).foregroundStyle(.secondary)
                }
            }
            .frame(width: 58, height: 58)
            .rotationEffect(.degrees(earned ? tilt : 0))
            Text(medal.title).font(.caption.weight(.semibold)).multilineTextAlignment(.center)
            Text(medal.requirement).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .opacity(earned ? 1 : 0.75)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(earned ? L10n.tr("Sticker \(medal.title), collected. \(medal.requirement)")
                                   : L10n.tr("Sticker \(medal.title), locked. \(medal.requirement)"))
    }
}
