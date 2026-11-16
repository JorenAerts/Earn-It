import Coach
import Localization
import SwiftUI
import WidgetKit

// Layouts for the Gloop widgets. Pure views of a `WidgetSnapshot` at a `date`, used by the
// widget extension and by the in-app preview screen (Settings › Developer › Widget previews).

private let flameGradient = LinearGradient(colors: [Color(red: 1, green: 0.78, blue: 0.25),
                                                    Color(red: 0.96, green: 0.38, blue: 0.13)],
                                           startPoint: .top, endPoint: .bottom)

// MARK: - Small: streak

public struct StreakWidgetView: View {
    let snapshot: WidgetSnapshot?
    let date: Date

    public init(snapshot: WidgetSnapshot?, date: Date) {
        self.snapshot = snapshot
        self.date = date
    }

    public var body: some View {
        if let snapshot {
            StreakBlock(streak: snapshot.streak(at: date), doneToday: snapshot.completedToday(at: date))
        } else {
            OpenAppView(compact: true)
        }
    }
}

struct StreakBlock: View {
    let streak: Int
    let doneToday: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(flameGradient)
                    .widgetAccentable()
                Spacer()
                Image(systemName: doneToday ? "checkmark.circle.fill" : "clock.fill")
                    .font(.headline)
                    .foregroundStyle(doneToday ? Color.green : Color.orange)
            }
            Spacer(minLength: 0)
            Text("\(streak)")
                .font(.system(size: 54, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())
                .widgetAccentable()
            Text("day streak")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(doneToday ? L10n.tr("Today earned") : L10n.tr("Today pending"))
                .font(.caption2.weight(.bold))
                .foregroundStyle(doneToday ? Color.green : Color.orange)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(doneToday ? "\(streak) day streak. Today earned." : "\(streak) day streak. Today still pending.")
    }
}

// MARK: - Medium: streak + stage

public struct StreakRankWidgetView: View {
    let snapshot: WidgetSnapshot?
    let date: Date

    public init(snapshot: WidgetSnapshot?, date: Date) {
        self.snapshot = snapshot
        self.date = date
    }

    public var body: some View {
        if let snapshot {
            if snapshot.isPro {
                HStack(spacing: 16) {
                    StreakBlock(streak: snapshot.streak(at: date), doneToday: snapshot.completedToday(at: date))
                        .frame(maxWidth: .infinity)
                    Rectangle().fill(.quaternary).frame(width: 1)
                    RankBlock(progress: snapshot.progress)
                        .frame(maxWidth: .infinity)
                }
            } else {
                ProLockedView(streak: snapshot.streak(at: date), feature: L10n.tr("Streak & Stage widget"))
            }
        } else {
            OpenAppView(compact: false)
        }
    }
}

struct RankBlock: View {
    let progress: RankProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                RankInsignia(rank: progress.rank, size: 42)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Stage").font(.caption2.weight(.bold)).textCase(.uppercase).foregroundStyle(.secondary)
                    Text(progress.rank.title)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
            }
            Spacer(minLength: 0)
            ProgressView(value: progress.fraction)
                .tint(.orange)
                .widgetAccentable()
            Group {
                if let next = progress.next, let toGo = progress.xpToNext {
                    Text("\(toGo) XP to \(next.title)")
                } else {
                    Text("\(progress.xp) XP · fully evolved")
                }
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Large: service record

public struct ServiceRecordWidgetView: View {
    let snapshot: WidgetSnapshot?
    let date: Date

    public init(snapshot: WidgetSnapshot?, date: Date) {
        self.snapshot = snapshot
        self.date = date
    }

    public var body: some View {
        if let snapshot {
            if snapshot.isPro {
                content(snapshot)
            } else {
                ProLockedView(streak: snapshot.streak(at: date), feature: L10n.tr("Gloop's Diary widget"))
            }
        } else {
            OpenAppView(compact: false)
        }
    }

    private func content(_ s: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                SlimeView(look: SlimeLook.make(vitality: s.vitality, state: CoachState(mood: s.mood, context: .idle),
                                               accessory: s.progress.rank.accessory),
                          color: SlimeColor(rawValue: s.slimeColor) ?? .orange, size: 62, animated: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(CoachIdentity.name).font(.caption2.weight(.heavy)).textCase(.uppercase).foregroundStyle(.secondary)
                    Text(s.coachLine)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                }
            }
            RankCard(progress: s.progress)
            HStack(spacing: 10) {
                StatTile(symbol: "flame.fill", value: s.streak(at: date), label: L10n.tr("Day streak"))
                StatTile(symbol: "trophy.fill", value: s.bestStreak, label: L10n.tr("Best streak"))
            }
            DayStrip(days: s.days(at: date))
            if !s.medals.isEmpty {
                HStack(spacing: 8) {
                    ForEach(s.medals) { medal in
                        HStack(spacing: 6) {
                            Image(systemName: medal.symbol)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Color(red: 0.88, green: 0.66, blue: 0.2)))
                                .widgetAccentable()
                            Text(medal.title).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct StatTile: View {
    let symbol: String
    let value: Int
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(flameGradient).widgetAccentable()
            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)").font(.title3.weight(.heavy)).monospacedDigit()
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

/// 14 dots, oldest → today: filled = mission done, red ring = fail-safe, faint = no data.
struct DayStrip: View {
    let days: [WidgetSnapshot.DayMark]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last 14 days").font(.caption2.weight(.bold)).textCase(.uppercase).foregroundStyle(.secondary)
            HStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, mark in
                    Circle()
                        .fill(mark == .done ? AnyShapeStyle(flameGradient) : AnyShapeStyle(Color.secondary.opacity(0.18)))
                        .overlay { if mark == .failed { Circle().strokeBorder(.red, lineWidth: 2) } }
                        .frame(width: 13, height: 13)
                        .frame(maxWidth: .infinity)
                        .widgetAccentable(mark == .done)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(days.filter { $0 == .done }.count) of the last 14 mornings earned")
    }
}

// MARK: - Lock Screen

public struct LockStreakView: View {
    let snapshot: WidgetSnapshot?
    let date: Date

    public init(snapshot: WidgetSnapshot?, date: Date) {
        self.snapshot = snapshot
        self.date = date
    }

    public var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: -2) {
                Image(systemName: "flame.fill").font(.caption)
                Text(snapshot.map { "\($0.streak(at: date))" } ?? "–")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
            }
        }
        .accessibilityLabel(snapshot.map { "\($0.streak(at: date)) day streak" } ?? "Open Gloop")
    }
}

public struct LockStreakRankView: View {
    let snapshot: WidgetSnapshot?
    let date: Date

    public init(snapshot: WidgetSnapshot?, date: Date) {
        self.snapshot = snapshot
        self.date = date
    }

    public var body: some View {
        if let snapshot {
            VStack(alignment: .leading, spacing: 2) {
                Label("\(snapshot.streak(at: date)) day streak", systemImage: "flame.fill")
                    .font(.headline)
                    .widgetAccentable()
                Text(snapshot.progress.rank.title).font(.caption.weight(.semibold))
                ProgressView(value: snapshot.progress.fraction)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        } else {
            Label("Open Gloop", systemImage: "flame")
        }
    }
}

// MARK: - States

/// No data yet (app never opened, or no App Group on this build).
struct OpenAppView: View {
    let compact: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "flame").font(compact ? .title2 : .title).foregroundStyle(flameGradient)
            Text("Open Gloop").font(.headline)
            if !compact {
                Text("Your streak and Gloop's stage appear here after your first visit.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Medium / Large for free users: tap opens the paywall.
struct ProLockedView: View {
    let streak: Int
    let feature: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                Text("GLOOP PRO").font(.caption.weight(.heavy))
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(.orange, in: .capsule)
            .foregroundStyle(.white)
            .widgetAccentable()
            Text("Unlock the \(feature)").font(.headline).multilineTextAlignment(.center)
            Label("\(streak) day streak", systemImage: "flame.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Tap to upgrade").font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
