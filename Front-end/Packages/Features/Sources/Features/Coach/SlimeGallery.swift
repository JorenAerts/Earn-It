import Coach
import SwiftUI
import WidgetShared

/// Developer tools / screenshots (`-slimeGallery`): Gloop at several vitality levels × moods.
struct SlimeGallery: View {
    var color: SlimeColor = AppearanceSettings.shared.slimeColor
    static let vitalities: [Double] = [1, 0.7, 0.4, 0.1]

    var body: some View {
        ScrollView {
            Text("Evolution stages").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 86))], spacing: 14) {
                ForEach(Rank.allCases) { rank in
                    VStack(spacing: 4) {
                        CoachAvatarView(state: CoachState(mood: .calm, context: .idle), size: 78, vitality: 0.9,
                                        accessory: rank.accessory)
                        RankInsignia(rank: rank, size: 30)
                        Text(rank.title).font(.caption2.weight(.semibold))
                    }
                }
            }
            .padding()
            Grid(horizontalSpacing: 8, verticalSpacing: 14) {
                GridRow {
                    Text("")
                    ForEach(Self.vitalities, id: \.self) { Text("\(Int($0 * 100))%").font(.caption.bold()) }
                }
                ForEach(CoachMood.allCases) { mood in
                    GridRow {
                        Text(mood.displayName).font(.caption2).frame(width: 64, alignment: .leading)
                        ForEach(Self.vitalities, id: \.self) { v in
                            CoachAvatarView(state: CoachState(mood: mood, context: .idle, anger: 0.8), size: 76, vitality: v)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("\(CoachIdentity.name) gallery")
    }
}
