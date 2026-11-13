import Coach
import Core
import SwiftData
import SwiftUI

/// Progress tab: streaks and the last two weeks of mornings, from `DayLog`.
struct StatsView: View {
    @Query(sort: \DayLog.day, order: .reverse) private var logs: [DayLog]

    private var completed: [Date] { logs.compactMap(\.missionCompletedAt) }
    private var history: [DaySummary] { logs.map(DaySummary.init(log:)) }
    private var current: Int { StreakCalculator.currentStreak(completedDays: completed, today: .now) }
    private var best: Int { StreakCalculator.bestStreak(completedDays: completed) }
    private var averageReRings: Double {
        let done = logs.filter { $0.missionCompletedAt != nil }
        guard !done.isEmpty else { return 0 }
        return Double(done.map(\.reArmCount).reduce(0, +)) / Double(done.count)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Rank") {
                    RankCard(progress: XPRules.progress(history))
                        .padding(.vertical, 4)
                }

                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.orange)
                            .symbolEffect(.bounce, value: current)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(current)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text(current == 1 ? "day streak" : "day streak").foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                }

                Section("Last 14 days") {
                    LastDaysStrip(logs: logs)
                        .padding(.vertical, 6)
                }

                Section {
                    let earned = MedalRules.earned(history)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12, alignment: .top)], spacing: 16) {
                        ForEach(Medal.allCases) { MedalTile(medal: $0, earned: earned.contains($0)) }
                    }
                    .padding(.vertical, 8)
                } header: {
                    let count = MedalRules.earned(history).count
                    Text("Medals · \(count)/\(Medal.allCases.count)")
                } footer: {
                    Text("XP per morning: \(XPRules.missionDone) for the mission, +\(XPRules.firstTryBonus) on the first ring, −\(XPRules.perReRing) per re-ring, +\(XPRules.perStreakDay) per streak day (up to \(XPRules.maxStreakBonusDays)).")
                }

                Section("All time") {
                    LabeledContent("Best streak", value: "\(best) day\(best == 1 ? "" : "s")")
                    LabeledContent("Mornings earned", value: "\(completed.count)")
                    LabeledContent("Avg. re-rings per morning", value: averageReRings.formatted(.number.precision(.fractionLength(1))))
                    LabeledContent("Fail-safe stops", value: "\(logs.filter(\.failSafeTriggered).count)")
                }

                if logs.isEmpty {
                    Section {
                        Text("Your first finished mission starts your streak.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Progress")
        }
    }
}

/// 14 circles, oldest → today: filled = mission done, ring = fail-safe, faint = no data.
private struct LastDaysStrip: View {
    let logs: [DayLog]

    private var days: [Date] {
        let today = Calendar.current.startOfDay(for: .now)
        return (0..<14).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: today) }
    }

    var body: some View {
        let byDay = Dictionary(logs.map { (Calendar.current.startOfDay(for: $0.day), $0) },
                               uniquingKeysWith: { first, _ in first })
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                let log = byDay[day]
                VStack(spacing: 4) {
                    Circle()
                        .fill(log?.missionCompletedAt != nil ? Color.orange : Color.secondary.opacity(0.15))
                        .overlay {
                            if log?.failSafeTriggered == true {
                                Circle().strokeBorder(.red, lineWidth: 2)
                            }
                        }
                        .frame(width: 16, height: 16)
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(day.formatted(date: .abbreviated, time: .omitted) + ", "
                                    + (log?.missionCompletedAt != nil ? "mission done" : "no mission"))
            }
        }
    }
}
