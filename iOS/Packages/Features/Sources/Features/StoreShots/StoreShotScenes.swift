#if DEBUG
import Coach
import Core
import Missions
import Purchases
import SwiftUI
import WidgetShared

/// App Store screenshot scenes with fixed demo data. Launch with `-storeShot <scene>`
/// (driven by scripts/screenshots/make.sh). DEBUG only.
enum StoreShotScene: String, CaseIterable {
    case lockscreen, math, missions, health, itemScan, evolution, widgets, appearance
    /// Previews of the growth features (not App Store shots).
    case streakCard, whatsNew
}

struct StoreShotView: View {
    let scene: StoreShotScene
    let store: StoreService

    var body: some View {
        switch scene {
        case .lockscreen: LockScreenMock()
        case .math:
            MissionRunnerView(missions: [MissionConfig(kind: .math, difficulty: .medium, target: 3)],
                              reArmCount: 1, reArmMinutes: 2,
                              coachState: CoachState(mood: .suspicious, context: .reRing),
                              coachLine: "Ring 2. One more snooze and I'm melting.") {}
        case .missions: MissionPickerView(gate: FeatureGate(isPro: true)) { _ in }
        case .health: HealthShot()
        case .itemScan: ItemScanMock()
        case .evolution: EvolutionShot()
        case .widgets: WidgetsShot()
        case .appearance: NavigationStack { AppearanceView() }
        case .streakCard:
            ZStack {
                Color.black.ignoresSafeArea()
                StreakCardView(content: StreakCardContent(streak: 12, rank: .bouncer, stickers: 6, vitality: 0.9))
                    .clipShape(.rect(cornerRadius: 24))
            }
        case .whatsNew:
            WhatsNewSheet(release: HelpContent.load().releases.first ?? HelpContent.Release(version: "1.0", items: ["New"])) {}
        }
    }
}

/// The ringing alarm, as iOS shows it (title = alarm name + mission), over a dark wallpaper.
private struct LockScreenMock: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.06, green: 0.08, blue: 0.2), Color(red: 0.28, green: 0.18, blue: 0.4)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 10) {
                Spacer().frame(height: 40)
                Text("Friday 15 November").font(.title3.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                Text("7:00").font(.system(size: 104, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: "alarm.fill").foregroundStyle(.orange)
                        Text("Gloop - Math Problem").font(.headline)
                        Spacer()
                        Text("now").font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        Capsule().fill(.white.opacity(0.25)).frame(height: 64)
                            .overlay(alignment: .leading) {
                                Circle().fill(.white).frame(width: 56, height: 56).padding(4)
                                    .overlay(Image(systemName: "xmark").font(.title3.bold()).foregroundStyle(.black))
                            }
                            .overlay(Text("slide to stop").foregroundStyle(.white.opacity(0.8)))
                    }
                }
                .padding(18)
                .foregroundStyle(.white)
                .background(.ultraThinMaterial.opacity(0.9), in: .rect(cornerRadius: 28))
                .padding(.horizontal, 16)
                HStack(spacing: 10) {
                    CoachAvatarView(state: CoachState(mood: .suspicious, context: .ringing), size: 64, vitality: 0.75,
                                    accessory: .cap)
                    Text("Stop me with a mission, not a swipe.")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                }
                .padding(.vertical, 22)
            }
        }
        .environment(\.colorScheme, .dark)
        .statusBarHidden(true)  // the real Lock Screen shows no time in the status bar
    }
}

/// Bouncy vs droopy Gloop + health bar.
private struct HealthShot: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(alignment: .bottom, spacing: 18) {
                        VStack(spacing: 6) {
                            CoachAvatarView(state: CoachState(mood: .proud, context: .idle), size: 130, vitality: 1, accessory: .cap)
                            Text("First ring").font(.headline)
                            Text("Bouncing 🎉").font(.caption).foregroundStyle(.secondary)
                        }
                        VStack(spacing: 6) {
                            CoachAvatarView(state: CoachState(mood: .disappointed, context: .idle), size: 130, vitality: 0.1, accessory: .cap)
                            Text("Snoozed").font(.headline)
                            Text("Melting 🫠").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                Section("Gloop's health") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("This week").font(.headline); Spacer(); Text("86%").font(.headline).foregroundStyle(.orange) }
                        ProgressView(value: 0.86).tint(.orange)
                        Text("Gloop is bouncing. Keep getting up on the first ring.").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "flame.fill").font(.system(size: 40)).foregroundStyle(.orange)
                        VStack(alignment: .leading) {
                            Text("12").font(.system(size: 44, weight: .bold, design: .rounded))
                            Text("day streak").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Progress")
        }
    }
}

/// Camera view while scanning the registered item (Simulator has no camera).
private struct ItemScanMock: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.86, green: 0.9, blue: 0.93), Color(red: 0.62, green: 0.7, blue: 0.76)],
                           startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            Image(systemName: "mug.fill")
                .font(.system(size: 200))
                .foregroundStyle(LinearGradient(colors: [Color(red: 0.95, green: 0.45, blue: 0.3), Color(red: 0.75, green: 0.25, blue: 0.2)],
                                                startPoint: .top, endPoint: .bottom))
                .shadow(radius: 12)
            RoundedRectangle(cornerRadius: 36).strokeBorder(.white, style: StrokeStyle(lineWidth: 5, dash: [40, 20]))
                .frame(width: 300, height: 380)
            VStack {
                HStack(spacing: 12) {
                    CoachAvatarView(state: CoachState(mood: .suspicious, context: .ringing), size: 54, vitality: 0.75, accessory: .cap)
                    VStack(alignment: .leading) {
                        Text("Find your Coffee mug").font(.headline)
                        Text("Hold it in the frame").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(.regularMaterial, in: .rect(cornerRadius: 22))
                .padding(.horizontal, 16)
                .padding(.top, 60)
                Spacer()
                HStack(spacing: 10) {
                    ForEach(0..<4) { i in Capsule().fill(i < 3 ? Color.green : .white.opacity(0.6)).frame(height: 10) }
                }
                .padding(.horizontal, 60)
                Text("Matching… 3 of 4").font(.headline).foregroundStyle(.white).padding(.top, 6).padding(.bottom, 60)
            }
        }
    }
}

/// Home Screen + Lock Screen widgets on a wallpaper (no developer controls).
private struct WidgetsShot: View {
    private let snapshot = WidgetSnapshot.placeholder

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.98, green: 0.62, blue: 0.4), Color(red: 0.55, green: 0.35, blue: 0.75)],
                           startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer().frame(height: 30)
                HStack(spacing: 22) {
                    widget(width: 170, height: 170) { StreakWidgetView(snapshot: snapshot, date: .now) }
                    VStack(spacing: 14) {
                        ForEach(["alarm.fill", "flame.fill"], id: \.self) { symbol in
                            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.35))
                                .frame(width: 70, height: 70)
                                .overlay(Image(systemName: symbol).font(.title).foregroundStyle(.white))
                        }
                    }
                }
                widget(width: 364, height: 170) { StreakRankWidgetView(snapshot: snapshot, date: .now) }
                widget(width: 364, height: 382) { ServiceRecordWidgetView(snapshot: snapshot, date: .now) }
                Spacer()
            }
        }
    }

    private func widget<V: View>(width: CGFloat, height: CGFloat, @ViewBuilder content: () -> V) -> some View {
        content()
            .padding(14)
            .frame(width: width, height: height)
            .background(Color(.systemBackground), in: .rect(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
    }
}

/// Stage ladder with accessories + stickers.
private struct EvolutionShot: View {
    private let stages: [Rank] = [.droplet, .blob, .jelly, .bouncer, .wobbler, .superGloop, .royalGloop, .kingGloop, .squisher]
    private let earned: Set<Medal> = [.firstMission, .firstTry, .streak3, .streak7, .earlyBird, .hatTrick]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Evolution").font(.title2.bold())
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                        ForEach(stages) { rank in
                            VStack(spacing: 4) {
                                CoachAvatarView(state: CoachState(mood: .calm, context: .idle), size: 92, vitality: 0.95,
                                                accessory: rank.accessory)
                                Text(rank.title).font(.caption.weight(.semibold))
                            }
                        }
                    }
                    Text("Stickers").font(.title2.bold())
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 14) {
                        ForEach(Medal.allCases.prefix(6)) { MedalTile(medal: $0, earned: earned.contains($0)) }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif
