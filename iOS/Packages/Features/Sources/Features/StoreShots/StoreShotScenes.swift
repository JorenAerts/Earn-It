#if DEBUG
import Coach
import Localization
import Core
import Missions
import Purchases
import SwiftUI
import WidgetShared

/// App Store screenshot scenes with fixed demo data. Launch with `-storeShot <scene>`
/// (driven by scripts/screenshots/make.sh). DEBUG only.
enum StoreShotScene: String, CaseIterable {
    case lockscreen, math, missions, health, itemScan, evolution, widgets, appearance, success, missionGrid
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
                              coachLine: CoachModel.shared.lines.line(for: .reRing, intensity: .toughLove, day: .now,
                                                                    values: ["rings": "2"])) {}
        case .missions: MissionPickerView(gate: FeatureGate(isPro: true)) { _ in }
        case .health: HealthShot()
        case .itemScan: ItemScanMock()
        case .evolution: EvolutionShot()
        case .success: SuccessShot()
        case .missionGrid: MissionGridShot()
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
                Text(StoreShotText.lockScreenDate).font(.title3.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                Text("7:00").font(.system(size: 104, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Spacer()
                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: "alarm.fill").foregroundStyle(.orange)
                        Text("Gloop - " + L10n.tr("Math Problem")).font(.headline)
                        Spacer()
                        Text(StoreShotText.t("now")).font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        Capsule().fill(.white.opacity(0.25)).frame(height: 64)
                            .overlay(alignment: .leading) {
                                Circle().fill(.white).frame(width: 56, height: 56).padding(4)
                                    .overlay(Image(systemName: "xmark").font(.title3.bold()).foregroundStyle(.black))
                            }
                            .overlay(Text(StoreShotText.t("slide to stop")).foregroundStyle(.white.opacity(0.8)))
                    }
                }
                .padding(18)
                .foregroundStyle(.white)
                .background(.ultraThinMaterial.opacity(0.9), in: .rect(cornerRadius: 28))
                .padding(.horizontal, 16)
                HStack(spacing: 10) {
                    CoachAvatarView(state: CoachState(mood: .suspicious, context: .ringing), size: 64, vitality: 0.75,
                                    accessory: .cap)
                    Text(StoreShotText.t("Stop me with a mission, not a swipe."))
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
/// The success screen after a first-ring morning: Gloop evolves, XP, a new sticker, a 7-day streak.
/// Same texts as `SuccessView` (so translations apply), fixed demo numbers.
private struct SuccessShot: View {
    private let state = CoachState(mood: .proud, context: .firstTry)
    private let streak = 7

    var body: some View {
        VStack(spacing: 20) {
            CoachAvatarView(state: state, size: 170, vitality: 1, accessory: Rank.jelly.accessory)
                .padding(.top, 56)
            // A first-try line without {name} (no demo name on a store screenshot).
            Text(CoachModel.shared.lines.lines(for: .firstTry, intensity: .toughLove)
                    .first { !$0.contains("{name}") } ?? "")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            VStack(spacing: 6) {
                RankInsignia(rank: .jelly, size: 64)
                Text("\(CoachIdentity.name) evolved into \(Rank.jelly.title)!").font(.title2.bold()).multilineTextAlignment(.center)
            }
            VStack(spacing: 6) {
                Text("+\(95) XP").font(.headline).foregroundStyle(.orange).monospacedDigit()
                ProgressView(value: 0.35).tint(.orange).frame(maxWidth: 240)
                Text("\(160) XP to \(Rank.gloopling.title)").font(.caption).foregroundStyle(.secondary)
            }
            VStack(spacing: 8) {
                Text(L10n.tr("New sticker!"))
                    .font(.caption.weight(.heavy)).textCase(.uppercase).foregroundStyle(.secondary)
                MedalTile(medal: .streak7, earned: true).frame(width: 110)
            }
            Text("Streak: \(streak) days").font(.title2.weight(.semibold))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .overlay { ConfettiBurst().ignoresSafeArea() }
    }
}

/// The premium missions as a colourful 3×3 grid (banner shot 2; Math, the free one, isn't shown).
private struct MissionGridShot: View {
    private let kinds: [MissionKind] = [.object, .sky, .bed, .colorHunt, .qr, .shake, .quiz, .memory, .typing]

    private func tint(_ category: MissionCategory) -> [Color] {
        switch category {
        case .outOfBed: [Color(red: 1, green: 0.62, blue: 0.25), Color(red: 0.95, green: 0.33, blue: 0.16)]
        case .brain: [Color(red: 0.70, green: 0.50, blue: 1), Color(red: 0.45, green: 0.25, blue: 0.85)]
        case .body: [Color(red: 0.30, green: 0.85, blue: 0.75), Color(red: 0.08, green: 0.60, blue: 0.55)]
        case .mindset: [Color(red: 0.45, green: 0.65, blue: 1), Color(red: 0.20, green: 0.35, blue: 0.85)]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(StoreShotText.t("Pick your mission")).font(.largeTitle.bold())
                .padding(.top, 70)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(kinds, id: \.self) { kind in
                    VStack(spacing: 10) {
                        Image(systemName: kind.symbol)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .background(LinearGradient(colors: tint(kind.category), startPoint: .top, endPoint: .bottom),
                                        in: .rect(cornerRadius: 18, style: .continuous))
                            .shadow(color: tint(kind.category)[1].opacity(0.35), radius: 6, y: 3)
                        Text(kind.displayName).font(.footnote.weight(.semibold))
                            .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.6)
                            .padding(.horizontal, 4)
                            .frame(height: 40, alignment: .top)
                        Text(kind.estimatedDuration).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.background, in: .rect(cornerRadius: 22, style: .continuous))
                }
            }
            HStack(spacing: 14) {
                ForEach([MissionCategory.outOfBed, .brain, .body], id: \.self) { category in
                    Label(category.title, systemImage: category.symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint(category)[1])
                }
            }
            .frame(maxWidth: .infinity)
            Spacer()
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

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
