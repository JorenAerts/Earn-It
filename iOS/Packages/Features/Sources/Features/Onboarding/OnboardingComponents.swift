import Coach
import Localization
import SwiftUI

// MARK: - Page layout

/// Shared step layout: title + optional subtitle, scrollable content, buttons pinned to the bottom.
struct OnboardingPage<Content: View, Footer: View>: View {
    var title: String? = nil
    var subtitle: String? = nil
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let title {
                        Text(title).font(.system(.largeTitle, weight: .bold))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                    }
                    if let subtitle {
                        Text(subtitle).font(.body).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, -10)
                    }
                    content
                }
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(spacing: 12) { footer }
                .frame(maxWidth: 560)
                .padding(.horizontal, 22)
                .padding(.bottom, 12)
                .padding(.top, 8)
        }
    }
}

struct PrimaryButton: View {
    let title: String
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(.orange)
        .disabled(disabled)
    }
}

// MARK: - Answer cards

/// One answer: icon in a circle, label, radio / checkbox.
struct ChoiceCard: View {
    let title: String
    var subtitle: String? = nil
    let symbol: String
    var tint: Color = .orange
    let selected: Bool
    var multiSelect = false
    var badge: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(selected ? .white : tint)
                    .frame(width: 46, height: 46)
                    .background(selected ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(tint.opacity(0.13)), in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title).font(.body.weight(.semibold)).foregroundStyle(.primary)
                        if let badge {
                            Text(badge).font(.caption2.weight(.heavy))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.orange, in: .capsule).foregroundStyle(.white)
                        }
                    }
                    if let subtitle {
                        Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: indicator)
                    .font(.title2)
                    .foregroundStyle(selected ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.tertiary))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(selected ? Color.orange : .clear, lineWidth: 2.5))
            .contentShape(.rect(cornerRadius: 22))
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    private var indicator: String {
        if multiSelect { return selected ? "checkmark.square.fill" : "square" }
        return selected ? "checkmark.circle.fill" : "circle"
    }
}

/// Slight shrink on press.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// A question with single-choice cards. Picking auto-advances after a short beat.
struct SingleChoiceStep<Option: Identifiable & Hashable>: View {
    let title: String
    var subtitle: String? = nil
    let options: [Option]
    @Binding var selection: Option?
    let label: (Option) -> String
    let symbol: (Option) -> String
    var coachLine: String? = nil
    let onNext: () -> Void

    var body: some View {
        OnboardingPage(title: title, subtitle: subtitle) {
            VStack(spacing: 12) {
                ForEach(options) { option in
                    ChoiceCard(title: label(option), symbol: symbol(option), selected: selection == option) {
                        withAnimation(.snappy) { selection = option }
                    }
                }
            }
            if let coachLine, selection != nil {
                CoachBubble(line: coachLine).transition(.move(edge: .bottom).combined(with: .opacity))
            }
        } footer: {
            PrimaryButton(title: L10n.tr("Continue"), disabled: selection == nil, action: onNext)
        }
        .animation(.snappy, value: selection)
    }
}

// MARK: - Coach

/// The coach commenting on the answers.
struct CoachBubble: View {
    let line: String
    var mood: CoachMood = .proud

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            CoachAvatarView(state: CoachState(mood: mood, context: .idle), size: 54)
            Text(line)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.orange.opacity(0.14), in: SpeechShape())
                .fixedSize(horizontal: false, vertical: true)
                .id(line)
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomLeading)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.snappy, value: line)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(CoachIdentity.name): \(line)")
    }
}

/// Rounded bubble with a little tail pointing at the coach.
struct SpeechShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerRadius: 16)
        path.move(to: CGPoint(x: 0, y: rect.maxY - 14))
        path.addLine(to: CGPoint(x: -8, y: rect.maxY - 4))
        path.addLine(to: CGPoint(x: 12, y: rect.maxY - 2))
        path.closeSubpath()
        return path
    }
}

// MARK: - Illustrations

/// Morning energy: snoozing (red zig-zag into a groggy zone) vs. one clean wake-up (orange).
struct EnergyChart: View {
    @State private var progress: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Morning energy").font(.headline)
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(Color.red.opacity(0.06))
                        .frame(height: h * 0.35).offset(y: h * 0.65)
                    Text("GROGGY ZONE").font(.caption2.weight(.heavy)).foregroundStyle(.red.opacity(0.6))
                        .position(x: w * 0.82, y: h * 0.9)
                    snoozePath(w, h).trim(from: 0, to: progress)
                        .stroke(Color.red.opacity(0.75), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    gloopPath(w, h).trim(from: 0, to: progress)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    Text("Snooze cycle").font(.caption.weight(.semibold)).foregroundStyle(.red)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color(.systemBackground), in: .capsule)
                        .position(x: w * 0.42, y: h * 0.97)
                        .opacity(progress)
                    Text("Gloop").font(.caption.weight(.bold)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.orange, in: .capsule)
                        .position(x: w * 0.72, y: h * 0.12)
                        .opacity(progress)
                }
            }
            .frame(height: 190)
            HStack(spacing: 16) {
                Label("Snoozing", systemImage: "circle.fill").foregroundStyle(.red)
                Label("One alarm + mission", systemImage: "circle.fill").foregroundStyle(.orange)
            }
            .font(.caption)
            .labelStyle(LegendLabelStyle())
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24))
        .onAppear { withAnimation(.easeInOut(duration: 1.8)) { progress = 1 } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Chart: snoozing keeps your energy in a groggy zone; getting up at the first alarm raises it steadily.")
    }

    private func snoozePath(_ w: CGFloat, _ h: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: h * 0.92))
        for i in 0..<3 {
            let x0 = w * (0.05 + CGFloat(i) * 0.2)
            p.addQuadCurve(to: CGPoint(x: x0 + w * 0.08, y: h * (0.45 + CGFloat(i) * 0.08)),
                           control: CGPoint(x: x0 + w * 0.03, y: h * 0.5))
            p.addQuadCurve(to: CGPoint(x: x0 + w * 0.17, y: h * 0.9),
                           control: CGPoint(x: x0 + w * 0.12, y: h * 0.9))
        }
        p.addCurve(to: CGPoint(x: w * 0.98, y: h * 0.6), control1: CGPoint(x: w * 0.75, y: h * 0.92),
                   control2: CGPoint(x: w * 0.85, y: h * 0.8))
        return p
    }

    private func gloopPath(_ w: CGFloat, _ h: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: h * 0.92))
        p.addCurve(to: CGPoint(x: w * 0.62, y: h * 0.18), control1: CGPoint(x: w * 0.25, y: h * 0.92),
                   control2: CGPoint(x: w * 0.4, y: h * 0.35))
        return p
    }
}

private struct LegendLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.font(.system(size: 8))
            configuration.title.foregroundStyle(.secondary)
        }
    }
}

/// "Normal alarm" (four alarms, all on) vs. Gloop (one alarm with a mission).
struct AlarmComparison: View {
    let hour: Int
    let minute: Int
    @State private var shown = 0

    private func time(plus minutes: Int) -> String {
        let total = (hour * 60 + minute + minutes) % (24 * 60)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            column(title: L10n.tr("Normal alarm"), tint: .red) {
                ForEach(0..<4, id: \.self) { i in
                    tile([L10n.tr("First alarm"), L10n.tr("Second alarm"), L10n.tr("Third alarm"), L10n.tr("Fourth alarm")][i], time(plus: i * 5), on: shown > i, tint: .red)
                }
            }
            column(title: "Gloop", tint: .orange) {
                tile(L10n.tr("With a mission"), time(plus: 0), on: shown > 0, tint: .orange)
                Label("Rings until you're up", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.orange)
                    .opacity(shown >= 4 ? 1 : 0)
                    .padding(.top, 4)
            }
        }
        .task {
            for i in 1...4 {
                try? await Task.sleep(for: .milliseconds(420))
                withAnimation(.snappy) { shown = i }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A normal alarm takes four alarms, five minutes apart. Gloop takes one alarm and a mission.")
    }

    private func column<C: View>(title: String, tint: Color, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
    }

    private func tile(_ label: String, _ time: String, on: Bool, tint: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
                Text(time).font(.title3.weight(.bold).monospacedDigit())
            }
            Spacer(minLength: 4)
            Capsule().fill(on ? tint : Color(.systemGray4))
                .frame(width: 40, height: 24)
                .overlay(alignment: on ? .trailing : .leading) {
                    Circle().fill(.white).padding(2)
                }
        }
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 14))
    }
}

/// Mock system permission dialog with a tapping finger.
struct PermissionIllustration: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("\"Gloop\" Would Like to Use Alarms").font(.headline).multilineTextAlignment(.center)
                Text("So your alarm rings through silent mode and Focus.").font(.footnote)
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(18)
            Divider()
            HStack(spacing: 0) {
                Text("Don't Allow").frame(maxWidth: .infinity).padding(.vertical, 12).foregroundStyle(.secondary)
                Divider().frame(height: 44)
                Text("Allow").fontWeight(.semibold).frame(maxWidth: .infinity).padding(.vertical, 12)
                    .foregroundStyle(.blue)
                    .overlay {
                        Circle().strokeBorder(Color.blue.opacity(0.4), lineWidth: 3)
                            .frame(width: 70, height: 70)
                            .scaleEffect(pulse ? 1.1 : 0.85)
                            .opacity(pulse ? 0.2 : 0.9)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Text("👆").font(.system(size: 34)).offset(x: 6, y: 34)
                            .offset(y: pulse ? -4 : 4)
                    }
            }
        }
        .frame(maxWidth: 300)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
        .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever()) { pulse = true } }
        .accessibilityHidden(true)
    }
}

/// S M T W T F S circles, highlighted on alarm days (Monday-first in most locales).
struct WeekdayCircles: View {
    let weekdays: Set<Int>

    var body: some View {
        let cal = Calendar.current
        let order = (0..<7).map { (cal.firstWeekday - 1 + $0) % 7 + 1 }
        HStack(spacing: 8) {
            ForEach(order, id: \.self) { day in
                let on = weekdays.contains(day)
                Text(cal.veryShortWeekdaySymbols[day - 1])
                    .font(.subheadline.weight(.bold))
                    .frame(width: 38, height: 38)
                    .background(on ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.clear), in: .circle)
                    .overlay(Circle().strokeBorder(on ? Color.orange : Color.secondary.opacity(0.4), lineWidth: 2))
                    .foregroundStyle(on ? .white : .secondary)
                    .accessibilityLabel(on ? L10n.tr("\(cal.weekdaySymbols[day - 1]), alarm on") : cal.weekdaySymbols[day - 1])
            }
        }
    }
}

/// Real numbers / reviews from `Shared/Config/SocialProof.json`. Renders nothing while it's empty.
struct SocialProofView: View {
    let proof: SocialProof

    var body: some View {
        if !proof.stats.isEmpty {
            HStack(spacing: 12) {
                ForEach(proof.stats) { stat in
                    VStack(spacing: 2) {
                        Text(stat.value).font(.title2.bold())
                        Text(stat.label).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

/// Coach quotes, or real reviews when `SocialProof.json` has them, sliding by.
struct QuoteCarousel: View {
    let proof: SocialProof
    @State private var index = 0

    /// Gloop's own lines (already in a speech card next to Gloop, so no quote marks: those differ per language).
    static var coachQuotes: [String] {
        [L10n.tr("Every snooze makes me a little droopier. Just saying."),
         L10n.tr("Feet on the floor first. Thinking comes later."),
         L10n.tr("Nobody ever regretted getting up on time. Especially not me."),
         L10n.tr("One mission, then the morning is yours. And I get to bounce.")]
    }

    private var items: [(title: String, text: String, stars: Int)] {
        if !proof.reviews.isEmpty { return proof.reviews.map { ($0.name, $0.text, $0.stars) } }
        return Self.coachQuotes.map { (CoachIdentity.name, $0, 0) }
    }

    var body: some View {
        let item = items[index % items.count]
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if item.stars == 0 {
                    CoachAvatarView(state: CoachState(mood: .proud, context: .idle), size: 40)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.subheadline.weight(.semibold))
                    if item.stars > 0 {
                        Text(String(repeating: "★", count: item.stars)).foregroundStyle(.orange).font(.caption)
                    }
                }
            }
            Text(item.text).font(.body).fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
        .id(index)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)))
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.6))
                withAnimation(.snappy) { index += 1 }
            }
        }
    }
}
