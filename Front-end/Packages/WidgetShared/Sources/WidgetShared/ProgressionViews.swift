import Coach
import SwiftUI

/// Rank insignia: chevrons for enlisted, bars/leaf/eagle/star for officers.
public struct RankInsignia: View {
    let rank: Rank
    var size: CGFloat

    public init(rank: Rank, size: CGFloat = 44) {
        self.rank = rank
        self.size = size
    }
    private let gold = Color(red: 0.89, green: 0.70, blue: 0.24)

    public var body: some View {
        ZStack {
            Circle().fill(Color(red: 0.29, green: 0.35, blue: 0.18))
            Circle().strokeBorder(gold, lineWidth: size * 0.06)
            mark.foregroundStyle(gold)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(rank.title)
    }

    @ViewBuilder private var mark: some View {
        switch rank {
        case .recruit:
            Text("R").font(.system(size: size * 0.42, weight: .black, design: .rounded))
        case .privateSoldier, .privateFirstClass, .corporal, .sergeant, .staffSergeant:
            let count = [.privateSoldier: 1, .privateFirstClass: 2, .corporal: 2, .sergeant: 3, .staffSergeant: 3][rank] ?? 1
            VStack(spacing: -size * 0.16) {
                ForEach(0..<count, id: \.self) { _ in
                    Image(systemName: "chevron.up").font(.system(size: size * 0.32, weight: .black))
                }
                if rank == .corporal || rank == .staffSergeant {
                    Image(systemName: "chevron.down").font(.system(size: size * 0.22, weight: .black))
                }
            }
        case .lieutenant, .captain:
            HStack(spacing: size * 0.06) {
                ForEach(0..<(rank == .captain ? 2 : 1), id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2).frame(width: size * 0.12, height: size * 0.42)
                }
            }
        case .major:
            Image(systemName: "leaf.fill").font(.system(size: size * 0.4))
        case .colonel:
            Image(systemName: "bird.fill").font(.system(size: size * 0.4))
        case .general:
            Image(systemName: "star.fill").font(.system(size: size * 0.42))
        }
    }
}

/// Rank card: insignia, title, XP and progress to the next rank.
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
                    Text("Highest rank. Outstanding, General.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

public struct MedalTile: View {
    let medal: Medal
    let earned: Bool

    public init(medal: Medal, earned: Bool) {
        self.medal = medal
        self.earned = earned
    }

    public var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(earned ? AnyShapeStyle(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.4),
                                                                              Color(red: 0.85, green: 0.6, blue: 0.15)],
                                                                     startPoint: .top, endPoint: .bottom))
                                    : AnyShapeStyle(Color.secondary.opacity(0.15)))
                Image(systemName: earned ? medal.symbol : "lock.fill")
                    .font(.title2)
                    .foregroundStyle(earned ? Color.white : Color.secondary)
            }
            .frame(width: 54, height: 54)
            Text(medal.title).font(.caption.weight(.semibold)).multilineTextAlignment(.center)
            Text(medal.requirement).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .opacity(earned ? 1 : 0.75)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(medal.title), \(earned ? "earned" : "locked"). \(medal.requirement)")
    }
}
