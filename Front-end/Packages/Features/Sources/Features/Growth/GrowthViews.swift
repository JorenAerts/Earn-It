import Coach
import Core
import Localization
import SwiftData
import SwiftUI
import Telemetry
import WidgetShared

// MARK: - Streak card (share image, 1080×1920 Stories size)

/// What's on the card.
public struct StreakCardContent: Equatable, Sendable {
    public var streak: Int
    public var rank: Rank
    public var stickers: Int
    public var vitality: Double

    public init(streak: Int, rank: Rank, stickers: Int, vitality: Double) {
        self.streak = streak
        self.rank = rank
        self.stickers = stickers
        self.vitality = vitality
    }
}

/// The card itself, laid out at 360×640 points (rendered at 3× = 1080×1920 px).
struct StreakCardView: View {
    let content: StreakCardContent
    var color: SlimeColor = .orange

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 1, green: 0.96, blue: 0.88), Color(red: 1, green: 0.76, blue: 0.48)],
                           startPoint: .top, endPoint: .bottom)
            VStack(spacing: 14) {
                Spacer(minLength: 40)
                Text(content.streak == 1 ? L10n.tr("Day 1") : L10n.tr("\(content.streak)-day streak"))
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.16, green: 0.1, blue: 0.07))
                Text("Up on time, every morning")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.95, green: 0.42, blue: 0.1))
                SlimeView(look: SlimeLook.make(vitality: max(0.8, content.vitality),
                                               state: CoachState(mood: .proud, context: .missionSuccess),
                                               accessory: content.rank.accessory),
                          color: color, size: 230, animated: false)
                    .padding(.vertical, 6)
                HStack(spacing: 10) {
                    pill(content.rank.title, symbol: "sparkles")
                    pill(L10n.tr("\(content.stickers) stickers"), symbol: "seal.fill")
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("Gloop").font(.system(size: 26, weight: .heavy, design: .rounded))
                    Text("Your wake-up buddy").font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(Color(red: 0.16, green: 0.1, blue: 0.07))
                .padding(.bottom, 34)
            }
            .padding(.horizontal, 24)
        }
        .frame(width: 360, height: 640)
        .environment(\.colorScheme, .light)
    }

    private func pill(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.white.opacity(0.8), in: .capsule)
            .foregroundStyle(Color(red: 0.95, green: 0.42, blue: 0.1))
    }

    /// 1080×1920 image for sharing.
    @MainActor
    static func render(_ content: StreakCardContent, color: SlimeColor) -> UIImage? {
        let renderer = ImageRenderer(content: StreakCardView(content: content, color: color))
        renderer.scale = 3
        return renderer.uiImage
    }
}

/// Image that `ShareLink` can share.
struct StreakCardImage: Transferable {
    let image: UIImage
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { card in card.image.pngData() ?? Data() }
    }
}

/// "Share my streak" button: renders the card from the user's history and opens the share sheet.
struct ShareStreakButton: View {
    var style: Style = .prominent
    enum Style { case prominent, plain }
    @Query private var logs: [DayLog]

    var body: some View {
        let content = Self.content(logs: logs)
        if content.streak > 0, let image = StreakCardView.render(content, color: AppearanceSettings.shared.slimeColor) {
            ShareLink(item: StreakCardImage(image: image),
                      message: Text(Self.message(content)),
                      preview: SharePreview("My \(content.streak)-day streak", image: Image(uiImage: image))) {
                Label("Share my streak", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: style == .prominent ? 360 : nil)
                    .padding(.vertical, style == .prominent ? 6 : 0)
            }
            .modifier(ShareButtonStyle(style: style))
            .simultaneousGesture(TapGesture().onEnded {
                Telemetry.shared.send(.action(.shareStreak(streak: content.streak)))
            })
        }
    }

    static func content(logs: [DayLog]) -> StreakCardContent {
        let history = logs.map(DaySummary.init(log:))
        return StreakCardContent(
            streak: StreakCalculator.currentStreak(completedDays: logs.compactMap(\.missionCompletedAt), today: .now),
            rank: XPRules.progress(history).rank,
            stickers: MedalRules.earned(history).count,
            vitality: CoachModel.shared.vitality)
    }

    static func message(_ content: StreakCardContent) -> String {
        L10n.tr("\(content.streak) mornings in a row up on time with my wake-up buddy Gloop 🟠")
    }
}

private struct ShareButtonStyle: ViewModifier {
    let style: ShareStreakButton.Style
    func body(content: Content) -> some View {
        switch style {
        case .prominent: content.buttonStyle(.bordered).controlSize(.large).tint(.orange)
        case .plain: content
        }
    }
}

// MARK: - What's New

/// Shown once after an update (see `WhatsNewPolicy`).
struct WhatsNewSheet: View {
    let release: HelpContent.Release
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            CoachAvatarView(state: CoachState(mood: .proud, context: .idle), size: 120)
                .padding(.top, 28)
            VStack(spacing: 6) {
                Text("What's new").font(.largeTitle.bold())
                Text("Version \(release.version)").foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(release.items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: "sparkle").foregroundStyle(.orange)
                        Text(item).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
            Spacer(minLength: 0)
            PrimaryButton(title: L10n.tr("Got it"), action: onDone)
        }
        .padding(24)
        .frame(maxWidth: 560)
        .background(Color(.systemGroupedBackground))
        .presentationDetents([.large])
        .trackScreen("WhatsNew")
    }
}
