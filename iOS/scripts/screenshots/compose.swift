// Composes the App Store screenshots as ONE panoramic banner, cut into 4 shots:
// a sky that runs from night (1) through dawn (2) to morning (3–4), a tilted phone per shot with the
// raw capture, a bold headline, and Gloop (drawn by the app's own `SlimeRenderer`) jumping across the
// seams: sleepy on 1, rushing over 1|2 and 2|3, his friends cheering on 4.
//
//   compose <spec.json> <out dir> <size name> <width> <height>
//   spec: [{"id": "01-…", "raw": "/path.png", "headline": "Line\nline", "accent": "word"}, …] (4 entries)
//
// Compiled together with Packages/WidgetShared/Sources/WidgetShared/Slime/SlimeDrawing.swift (make.sh).
import AppKit
import SwiftUI

struct Shot: Decodable {
    let id: String
    let raw: String
    let headline: String
    let accent: String
    /// Mission cards that "pop out" of the phone (banner shot 2).
    var cards: [Card]? = nil

    struct Card: Decodable {
        let symbol: String
        let title: String
        let tint: String
    }
}

// MARK: - Palette

enum Palette {
    static let night = Color(red: 0.078, green: 0.071, blue: 0.220)
    static let dusk = Color(red: 0.255, green: 0.165, blue: 0.443)
    static let dawn = Color(red: 0.902, green: 0.443, blue: 0.541)
    static let sunrise = Color(red: 1.000, green: 0.659, blue: 0.392)
    static let morning = Color(red: 1.000, green: 0.937, blue: 0.835)
    static let ink = Color(red: 0.165, green: 0.102, blue: 0.071)
    static let orange = Color(red: 0.949, green: 0.416, blue: 0.106)
    static let gold = Color(red: 1.000, green: 0.784, blue: 0.341)
    static let bezel = Color(red: 0.067, green: 0.059, blue: 0.067)
}

// MARK: - Banner

struct Banner: View {
    let shots: [(Shot, NSImage)]
    let shotSize: CGSize

    var body: some View {
        let w = shotSize.width, h = shotSize.height
        let total = CGSize(width: w * CGFloat(shots.count), height: h)
        ZStack(alignment: .topLeading) {
            Sky(size: total)
            ForEach(Array(shots.enumerated()), id: \.offset) { index, item in
                Panel(shot: item.0, raw: item.1, index: index, size: shotSize)
                    .frame(width: w, height: h)
                    .offset(x: w * CGFloat(index))
            }
            Gloops(shotSize: shotSize, count: shots.count)
        }
        .frame(width: total.width, height: total.height, alignment: .topLeading)
        .clipped()
    }
}

/// Night → dawn → morning, stars and moon on the left, a rising sun on the right, soft hills below.
struct Sky: View {
    let size: CGSize

    var body: some View {
        Canvas { ctx, size in
            let rect = CGRect(origin: .zero, size: size)
            ctx.fill(Path(rect), with: .linearGradient(
                Gradient(stops: [.init(color: Palette.night, location: 0),
                                 .init(color: Palette.dusk, location: 0.22),
                                 .init(color: Palette.dawn, location: 0.46),
                                 .init(color: Palette.sunrise, location: 0.64),
                                 .init(color: Palette.morning, location: 0.92)]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)))
            // A darker top edge keeps the white headlines readable; fades out to the right.
            ctx.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [Palette.night.opacity(0.35), .clear]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height * 0.45)))

            let unit = size.height / 2868
            // Stars (deterministic) over the night part.
            var seed: UInt64 = 7
            func next() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 33) / Double(1 << 31) }
            for _ in 0..<140 {
                let x = next() * size.width * 0.42
                let y = next() * size.height * 0.75
                let r = (2 + next() * 5) * unit
                let fade = 1 - x / (size.width * 0.42)
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                         with: .color(.white.opacity(0.25 + 0.6 * fade * next())))
            }
            // Moon (crescent) in the top-right corner of shot 1, clear of the headline.
            let moon = CGPoint(x: size.width * 0.215, y: size.height * 0.065)
            let mr = 60 * unit
            var crescent = Path(ellipseIn: CGRect(x: moon.x - mr, y: moon.y - mr, width: mr * 2, height: mr * 2))
            crescent = crescent.subtracting(Path(ellipseIn: CGRect(x: moon.x - mr * 0.45, y: moon.y - mr * 1.15,
                                                                   width: mr * 2, height: mr * 2)))
            ctx.fill(crescent, with: .color(Color(red: 1, green: 0.93, blue: 0.75)))

            // Rising sun with glow behind shots 3–4.
            let sun = CGPoint(x: size.width * 0.70, y: size.height * 0.86)
            for (r, a) in [(900.0, 0.10), (620.0, 0.16), (420.0, 0.28)] {
                let rr = r * unit
                ctx.fill(Path(ellipseIn: CGRect(x: sun.x - rr, y: sun.y - rr, width: rr * 2, height: rr * 2)),
                         with: .color(Color(red: 1, green: 0.85, blue: 0.45).opacity(a)))
            }
            let sr = 260 * unit
            ctx.fill(Path(ellipseIn: CGRect(x: sun.x - sr, y: sun.y - sr, width: sr * 2, height: sr * 2)),
                     with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.95, blue: 0.7), Palette.gold]),
                                           center: sun, startRadius: 0, endRadius: sr))

            // Two layers of soft hills.
            for (layer, (base, amp, alpha)) in [(0.905, 55.0, 0.55), (0.945, 40.0, 1.0)].enumerated() {
                var hills = Path()
                hills.move(to: CGPoint(x: 0, y: size.height))
                let steps = 48
                for i in 0...steps {
                    let x = size.width * CGFloat(i) / CGFloat(steps)
                    let y = size.height * base - amp * unit * sin(Double(i) * (layer == 0 ? 0.55 : 0.8) + Double(layer))
                    hills.addLine(to: CGPoint(x: x, y: y))
                }
                hills.addLine(to: CGPoint(x: size.width, y: size.height))
                hills.closeSubpath()
                ctx.fill(hills, with: .linearGradient(
                    Gradient(colors: [Color(red: 0.16, green: 0.12, blue: 0.30).opacity(alpha),
                                      Color(red: 0.55, green: 0.30, blue: 0.35).opacity(alpha),
                                      Color(red: 1.0, green: 0.72, blue: 0.45).opacity(alpha)]),
                    startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)))
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

/// One shot: headline + tilted phone.
struct Panel: View {
    let shot: Shot
    let raw: NSImage
    let index: Int
    let size: CGSize

    private static let tilt: [Double] = [-4, 3, -3, 4]
    private var dark: Bool { index < 2 }

    var body: some View {
        let w = size.width, h = size.height
        let deviceW = w * 0.70
        let deviceH = deviceW * raw.size.height / raw.size.width
        VStack(spacing: h * 0.03) {
            title
                .font(.system(size: w * 0.092, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .lineSpacing(-w * 0.012)
                .minimumScaleFactor(0.6)
                .shadow(color: dark ? .black.opacity(0.35) : .white.opacity(0.4), radius: w * 0.01)
                .padding(.top, h * 0.055)
                .padding(.horizontal, w * 0.07)
                .frame(height: h * 0.20, alignment: .bottom)
            Image(nsImage: raw)
                .resizable()
                .frame(width: deviceW, height: deviceH)
                .clipShape(.rect(cornerRadius: deviceW * 0.115, style: .continuous))
                .padding(deviceW * 0.026)
                .background(Palette.bezel, in: .rect(cornerRadius: deviceW * 0.14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: deviceW * 0.14, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: deviceW * 0.004)
                }
                .shadow(color: .black.opacity(dark ? 0.55 : 0.28), radius: w * 0.045, y: w * 0.03)
                .rotationEffect(.degrees(Self.tilt[index % Self.tilt.count]))
        }
        .frame(width: w, height: h, alignment: .top)
        .overlay(alignment: .topLeading) { PopOutCards(cards: shot.cards ?? [], size: size) }
    }

    /// Headline with the accent part highlighted.
    private var title: Text {
        let ink = dark ? Color.white : Palette.ink
        let accent = dark ? Palette.gold : Palette.orange
        let text = shot.headline
        guard !shot.accent.isEmpty, let range = text.range(of: shot.accent) else { return Text(text).foregroundColor(ink) }
        let before = Text(text[..<range.lowerBound]).foregroundColor(ink)
        let middle = Text(text[range]).foregroundColor(accent)
        let after = Text(text[range.upperBound...]).foregroundColor(ink)
        return Text("\(before)\(middle)\(after)")
    }
}

/// Up to 3 mission cards jumping out of the phone: top-right, middle-left, lower-right.
struct PopOutCards: View {
    let cards: [Shot.Card]
    let size: CGSize

    private static let spots: [(x: Double, y: Double, angle: Double)] = [(0.74, 0.475, 7), (0.30, 0.64, -6), (0.70, 0.865, 5)]

    var body: some View {
        let w = size.width
        ZStack(alignment: .topLeading) {
            ForEach(Array(cards.prefix(Self.spots.count).enumerated()), id: \.offset) { index, card in
                let spot = Self.spots[index]
                HStack(spacing: w * 0.03) {
                    Image(systemName: card.symbol)
                        .font(.system(size: w * 0.06, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: w * 0.12, height: w * 0.12)
                        .background(LinearGradient(colors: [Color(red: 1, green: 0.62, blue: 0.25), Color(red: 0.95, green: 0.33, blue: 0.16)],
                                                   startPoint: .top, endPoint: .bottom),
                                    in: .rect(cornerRadius: w * 0.035, style: .continuous))
                    Text(card.title)
                        .font(.system(size: w * 0.048, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: w * 0.36, alignment: .leading)
                }
                .padding(.vertical, w * 0.028)
                .padding(.leading, w * 0.028)
                .padding(.trailing, w * 0.045)
                .background(.white, in: .rect(cornerRadius: w * 0.05, style: .continuous))
                .shadow(color: .black.opacity(0.30), radius: w * 0.035, y: w * 0.02)
                .rotationEffect(.degrees(spot.angle))
                .position(x: w * spot.x, y: size.height * spot.y)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// Gloop's story across the banner.
struct Gloops: View {
    let shotSize: CGSize
    let count: Int

    var body: some View {
        let w = shotSize.width, h = shotSize.height
        ZStack(alignment: .topLeading) {
            // Dotted jump trail: sleepy (1) → over the seams → friends (4).
            Canvas { ctx, _ in
                var trail = Path()
                // Bounces along the hills, under the phones (never across a screen).
                trail.move(to: CGPoint(x: w * 0.26, y: h * 0.975))
                trail.addQuadCurve(to: CGPoint(x: w * 1.0, y: h * 0.80), control: CGPoint(x: w * 0.78, y: h * 1.02))
                trail.addQuadCurve(to: CGPoint(x: w * 2.0, y: h * 0.74), control: CGPoint(x: w * 1.5, y: h * 1.04))
                trail.addQuadCurve(to: CGPoint(x: w * 2.97, y: h * 0.90), control: CGPoint(x: w * 2.5, y: h * 1.04))
                ctx.stroke(trail, with: .color(.white.opacity(0.75)),
                           style: StrokeStyle(lineWidth: w * 0.008, lineCap: .round, dash: [w * 0.004, w * 0.03]))
            }
            .frame(width: w * CGFloat(count), height: h)

            // 1: asleep in the corner.
            slime(.init(droop: 0.75, eyes: .sleepy, mouth: .flat, drips: 1, saturation: 0.85), .orange, size: w * 0.34,
                  at: CGPoint(x: w * 0.13, y: h * 0.995))
            zzz(at: CGPoint(x: w * 0.09, y: h * 0.885), size: w * 0.045)
            // 1|2: woken up, rushing.
            slime(.init(droop: 0.15, eyes: .open, mouth: .open, sweat: true), .orange, size: w * 0.30,
                  at: CGPoint(x: w * 1.0, y: h * 0.80))
            // 2|3: mission done, flying high.
            slime(.init(droop: 0, eyes: .sparkly, mouth: .grin, blush: true, sparkle: true), .orange, size: w * 0.30,
                  at: CGPoint(x: w * 2.0, y: h * 0.74))
            // 4: the buddies.
            slime(.init(droop: 0.05, eyes: .sparkly, mouth: .grin, sparkle: true, accessory: .cap), .mint, size: w * 0.22,
                  at: CGPoint(x: w * 3.08, y: h * 0.985))
            slime(.init(droop: 0.05, eyes: .open, mouth: .grin, blush: true, accessory: .bow), .grape, size: w * 0.21,
                  at: CGPoint(x: w * 3.92, y: h * 0.985))
            slime(.init(droop: 0, eyes: .sparkly, mouth: .grin, blush: true, sparkle: true, accessory: .crown), .orange,
                  size: w * 0.30, at: CGPoint(x: w * 2.97, y: h * 0.94))
        }
        .frame(width: w * CGFloat(count), height: h, alignment: .topLeading)
    }

    /// A slime of `size` whose ground point sits at `at`.
    private func slime(_ pose: SlimePose, _ color: SlimeColor, size: CGFloat, at p: CGPoint) -> some View {
        Canvas { ctx, s in SlimeRenderer.draw(ctx, size: s, pose: pose, color: color) }
            .frame(width: size, height: size)
            .position(x: p.x, y: p.y - size * 0.38)
    }

    private func zzz(at p: CGPoint, size: CGFloat) -> some View {
        Text("z Z z")
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(.white.opacity(0.85))
            .rotationEffect(.degrees(-12))
            .position(p)
    }
}

// MARK: - Product page header (App Store Connect › Header, landscape)

struct HeaderSpec: Decodable {
    let headline: String
    let accent: String
    /// 3 raw captures: left, centre, right phone.
    let raws: [String]
}

/// One wide hero image: sky, headline, three fanned phones, sleepy Gloop left and proud Gloop right.
/// Everything important sits within ±0.95 H of the centre, so Apple's crops keep it.
struct HeaderBanner: View {
    let headline: String
    let accent: String
    let phones: [NSImage]
    let size: CGSize

    var body: some View {
        let w = size.width, h = size.height, cx = w / 2
        let phoneH = h * 0.60
        let side = min(h * 0.80, w / 2 - h * 0.19)  // Gloops stay fully inside narrower formats
        ZStack(alignment: .topLeading) {
            Sky(size: size)
            // Headline.
            title
                .font(.system(size: h * 0.082, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .lineSpacing(-h * 0.01)
                .shadow(color: .black.opacity(0.35), radius: h * 0.012)
                .frame(width: h * 1.6)
                .position(x: cx, y: h * 0.17)
            // Phones: side ones first (behind), centre last.
            ForEach([0, 2, 1], id: \.self) { index in
                let offset: CGFloat = index == 1 ? 0 : (index == 0 ? -1 : 1)
                phone(phones[index], height: index == 1 ? phoneH : phoneH * 0.9)
                    .rotationEffect(.degrees(Double(offset) * 9))
                    .position(x: cx + offset * h * 0.40, y: h * (index == 1 ? 0.66 : 0.70))
            }
            slime(SlimePose(droop: 0.75, eyes: .sleepy, mouth: .flat, drips: 1, saturation: 0.85), .orange,
                  size: h * 0.30, at: CGPoint(x: cx - side, y: h * 0.97))
            Text("z Z z").font(.system(size: h * 0.04, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.85)).rotationEffect(.degrees(-12))
                .position(x: cx - side - h * 0.06, y: h * 0.80)
            slime(SlimePose(droop: 0, eyes: .sparkly, mouth: .grin, blush: true, sparkle: true, accessory: .crown), .orange,
                  size: h * 0.30, at: CGPoint(x: cx + side, y: h * 0.97))
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .clipped()
    }

    private func phone(_ raw: NSImage, height: CGFloat) -> some View {
        let width = height * raw.size.width / raw.size.height
        return Image(nsImage: raw)
            .resizable()
            .frame(width: width, height: height)
            .clipShape(.rect(cornerRadius: width * 0.115, style: .continuous))
            .padding(width * 0.026)
            .background(Palette.bezel, in: .rect(cornerRadius: width * 0.14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: width * 0.14, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: width * 0.004)
            }
            .shadow(color: .black.opacity(0.45), radius: width * 0.08, y: width * 0.05)
    }

    private func slime(_ pose: SlimePose, _ color: SlimeColor, size: CGFloat, at p: CGPoint) -> some View {
        Canvas { ctx, s in SlimeRenderer.draw(ctx, size: s, pose: pose, color: color) }
            .frame(width: size, height: size)
            .position(x: p.x, y: p.y - size * 0.38)
    }

    private var title: Text {
        guard !accent.isEmpty, let range = headline.range(of: accent) else { return Text(headline).foregroundColor(.white) }
        return Text("\(Text(headline[..<range.lowerBound]).foregroundColor(.white))\(Text(headline[range]).foregroundColor(Palette.gold))\(Text(headline[range.upperBound...]).foregroundColor(.white))")
    }
}

/// `compose header <spec.json> <out.png> <width> <height>`
@MainActor func composeHeader(_ a: [String]) throws {
    guard a.count == 6, let w = Double(a[4]), let h = Double(a[5]) else {
        fatalError("usage: compose header <spec.json> <out.png> <width> <height>")
    }
    let spec = try JSONDecoder().decode(HeaderSpec.self, from: Data(contentsOf: URL(fileURLWithPath: a[2])))
    let phones = spec.raws.map { path -> NSImage in
        guard let image = NSImage(contentsOfFile: path) else { fatalError("missing \(path)") }
        return image
    }
    let view = HeaderBanner(headline: spec.headline.replacingOccurrences(of: "\\n", with: "\n"), accent: spec.accent,
                            phones: phones, size: CGSize(width: w, height: h))
    let renderer = ImageRenderer(content: view)
    renderer.scale = 1
    guard let cg = renderer.cgImage else { fatalError("render failed") }
    let ctx = CGContext(data: nil, width: Int(w), height: Int(h), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    // PNG: App Store Connect's header upload refuses .jpg ("invalid extension").
    let png = NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
    try png.write(to: URL(fileURLWithPath: a[3]))
}

// MARK: - CLI

@main
struct Compose {
    @MainActor static func main() throws {
        let a = CommandLine.arguments
        if a.count > 1, a[1] == "header" { return try composeHeader(a) }
        guard a.count == 6, let spec = try? Data(contentsOf: URL(fileURLWithPath: a[1])),
              let w = Double(a[4]), let h = Double(a[5]) else {
            fatalError("usage: compose <spec.json> <out dir> <size name> <width> <height>")
        }
        let shots = try JSONDecoder().decode([Shot].self, from: spec).map { shot -> (Shot, NSImage) in
            guard let image = NSImage(contentsOfFile: shot.raw) else { fatalError("missing \(shot.raw)") }
            let fixed = Shot(id: shot.id, raw: shot.raw, headline: shot.headline.replacingOccurrences(of: "\\n", with: "\n"),
                             accent: shot.accent, cards: shot.cards)
            return (fixed, image)
        }
        let renderer = ImageRenderer(content: Banner(shots: shots, shotSize: CGSize(width: w, height: h)))
        renderer.scale = 1
        guard let wide = renderer.cgImage else { fatalError("render failed") }
        for (index, item) in shots.enumerated() {
            // App Store screenshots: RGB, no alpha, exact size.
            let ctx = CGContext(data: nil, width: Int(w), height: Int(h), bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            ctx.draw(wide, in: CGRect(x: -w * Double(index), y: 0, width: Double(wide.width), height: Double(wide.height)))
            // PNG (lossless). Generated locally, not in git (fastlane/screenshots is ignored).
            let png = NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
            try png.write(to: URL(fileURLWithPath: a[2]).appending(path: "\(item.0.id)-\(a[3]).png"))
        }
    }
}
