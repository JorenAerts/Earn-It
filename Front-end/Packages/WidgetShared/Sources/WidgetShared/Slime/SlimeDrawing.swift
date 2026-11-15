import SwiftUI

// Dependency-free on purpose: also compiled by scripts/render_icons.swift on the Mac, so the app
// icons are drawn by exactly the same code as the character in the app.

public enum SlimeEyes: String, Sendable { case sparkly, open, sleepy, squint, teary }
public enum SlimeMouth: String, Sendable { case grin, smile, flat, frown, open }

/// What Gloop wears: one per evolution stage (see `Rank.accessory`).
public enum SlimeAccessory: String, CaseIterable, Sendable {
    case none, sprout, bow, sweatband, cap, headphones, sunglasses, scarf, halo, tiara, crown
}

/// Body colours. Each matches one of the alternate app icons.
public enum SlimeColor: String, CaseIterable, Codable, Sendable, Identifiable {
    case orange, mint, grape, midnight, gold

    public var id: String { rawValue }

    /// Top (light) and bottom (deep) body colour, as RGB 0…1.
    public var rgb: (top: SIMD3<Double>, bottom: SIMD3<Double>) {
        switch self {
        case .orange: ([1.00, 0.72, 0.30], [0.96, 0.42, 0.10])
        case .mint: ([0.55, 0.95, 0.78], [0.12, 0.70, 0.55])
        case .grape: ([0.80, 0.62, 1.00], [0.50, 0.28, 0.86])
        case .midnight: ([0.45, 0.62, 1.00], [0.18, 0.26, 0.72])
        case .gold: ([1.00, 0.90, 0.45], [0.88, 0.62, 0.10])
        }
    }
}

/// Everything the renderer needs. Built by `SlimeLook` in the app; set by hand for icons.
public struct SlimePose: Equatable, Sendable {
    public var droop: Double
    public var eyes: SlimeEyes
    public var mouth: SlimeMouth
    public var drips: Int
    public var blush: Bool
    public var sparkle: Bool
    public var steam: Bool
    public var sweat: Bool
    public var saturation: Double
    public var redness: Double
    public var accessory: SlimeAccessory

    public init(droop: Double, eyes: SlimeEyes = .open, mouth: SlimeMouth = .smile, drips: Int = 0,
                blush: Bool = false, sparkle: Bool = false, steam: Bool = false, sweat: Bool = false,
                saturation: Double = 1, redness: Double = 0, accessory: SlimeAccessory = .none) {
        self.droop = droop
        self.eyes = eyes
        self.mouth = mouth
        self.drips = drips
        self.blush = blush
        self.sparkle = sparkle
        self.steam = steam
        self.sweat = sweat
        self.saturation = saturation
        self.redness = redness
        self.accessory = accessory
    }
}

/// Draws the slime into a square `GraphicsContext`.
public enum SlimeRenderer {
    /// - Parameters:
    ///   - squash: breathing, −1…1 (taller / wider).
    ///   - time: seconds, for steam and sparkle twinkle.
    public static func draw(_ ctx: GraphicsContext, size: CGSize, pose: SlimePose, color: SlimeColor,
                            squash: Double = 0, time: Double = 0, shadow: Bool = true) {
        let s = min(size.width, size.height)
        let ox = (size.width - s) / 2, oy = (size.height - s) / 2
        let d = min(1, max(0, pose.droop))
        let c = ox + s * 0.5
        let ground = oy + s * 0.88
        let w = s * (0.70 + 0.26 * d) * (1 - 0.035 * squash)
        let h = s * (0.62 - 0.38 * d) * (1 + 0.05 * squash)
        let top = ground - h

        let (topRGB, bottomRGB) = color.rgb
        let light = adjust(topRGB, saturation: pose.saturation, redness: pose.redness)
        let deep = adjust(bottomRGB, saturation: pose.saturation, redness: pose.redness)

        // Contact shadow.
        if shadow {
            var shadowCtx = ctx
            shadowCtx.addFilter(.blur(radius: s * 0.02))
            shadowCtx.fill(Path(ellipseIn: CGRect(x: c - w * 0.55, y: ground - s * 0.025, width: w * 1.1, height: s * 0.06)),
                           with: .color(.black.opacity(0.18)))
        }

        // Puddle skirt when droopy.
        if d > 0.45 {
            let spread = (d - 0.45) / 0.55
            let pw = w * (1.0 + 0.25 * spread)
            ctx.fill(Path(ellipseIn: CGRect(x: c - pw / 2, y: ground - s * 0.045, width: pw, height: s * 0.07)),
                     with: .color(swatch(deep)))
        }

        let body = bodyPath(c: c, ground: ground, w: w, h: h, d: d, s: s)

        // Body gradient + inner shading.
        ctx.fill(body, with: .linearGradient(Gradient(colors: [swatch(light), swatch(deep)]),
                                             startPoint: CGPoint(x: c, y: top), endPoint: CGPoint(x: c, y: ground)))
        var inner = ctx
        inner.clip(to: body)
        inner.fill(body, with: .radialGradient(Gradient(colors: [.clear, swatch(deep).opacity(0.55)]),
                                               center: CGPoint(x: c - w * 0.08, y: top + h * 0.35),
                                               startRadius: w * 0.25, endRadius: w * 0.75))
        // Gloss.
        var gloss = inner
        gloss.addFilter(.blur(radius: s * 0.012))
        gloss.fill(Path(ellipseIn: CGRect(x: c - w * 0.34, y: top + h * 0.12, width: w * 0.24, height: h * 0.16))
                    .applying(rotation(-0.45, around: CGPoint(x: c - w * 0.22, y: top + h * 0.2))),
                   with: .color(.white.opacity(0.75)))
        inner.fill(Path(ellipseIn: CGRect(x: c - w * 0.08, y: top + h * 0.09, width: s * 0.035, height: s * 0.035)),
                   with: .color(.white.opacity(0.8)))
        // Rim.
        ctx.stroke(body, with: .color(swatch(deep).opacity(0.6)), lineWidth: s * 0.01)

        // Drips sliding down / pooled at the base.
        for i in 0..<min(3, pose.drips) {
            let side: CGFloat = i % 2 == 0 ? -1 : 1
            let x = c + side * w * (0.36 + 0.06 * CGFloat(i / 2))
            let r = s * (0.03 - 0.005 * CGFloat(i))
            let y = ground - s * 0.01
            var drop = Path()
            drop.move(to: CGPoint(x: x, y: y - r * 2.6))
            drop.addQuadCurve(to: CGPoint(x: x + r, y: y), control: CGPoint(x: x + r * 1.1, y: y - r * 1.2))
            drop.addArc(center: CGPoint(x: x, y: y), radius: r, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            drop.addQuadCurve(to: CGPoint(x: x, y: y - r * 2.6), control: CGPoint(x: x - r * 1.1, y: y - r * 1.2))
            ctx.fill(drop, with: .color(swatch(deep)))
        }

        drawFace(ctx, pose: pose, c: c, top: top, w: w, h: h, d: d, s: s, time: time)
        drawAccessory(ctx, pose.accessory, body: body, c: c, top: top, ground: ground, w: w, h: h, d: d, s: s)

        if pose.sweat {
            let x = c + w * 0.36, y = top + h * 0.22, r = s * 0.035
            var drop = Path()
            drop.move(to: CGPoint(x: x, y: y - r * 1.8))
            drop.addQuadCurve(to: CGPoint(x: x + r, y: y), control: CGPoint(x: x + r, y: y - r))
            drop.addArc(center: CGPoint(x: x, y: y), radius: r, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            drop.addQuadCurve(to: CGPoint(x: x, y: y - r * 1.8), control: CGPoint(x: x - r, y: y - r))
            ctx.fill(drop, with: .color(Color(red: 0.55, green: 0.8, blue: 1).opacity(0.9)))
        }
        if pose.sparkle {
            for (i, spot) in [(-0.42, 0.05), (0.40, 0.0), (0.30, -0.12)].enumerated() {
                let twinkle = 0.75 + 0.25 * sin(time * 3 + Double(i) * 2)
                star(ctx, at: CGPoint(x: c + w * spot.0, y: top + h * spot.1 - s * 0.02),
                     r: s * (0.045 - 0.01 * CGFloat(i)) * twinkle, color: Color(red: 1, green: 0.85, blue: 0.3))
            }
        }
        if pose.steam {
            for i in 0..<3 {
                let phase = (time * 0.7 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                let x = c + w * CGFloat(-0.25 + 0.25 * Double(i))
                let y = top - s * 0.04 - s * 0.14 * phase
                let r = s * (0.035 + 0.03 * phase)
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                         with: .color(Color(white: 0.85).opacity(0.85 * (1 - phase))))
            }
        }
    }

    // MARK: Body

    static func bodyPath(c: CGFloat, ground: CGFloat, w: CGFloat, h: CGFloat, d: Double, s: CGFloat) -> Path {
        let top = ground - h
        let k = s * 0.06                         // base corner
        let tip = s * 0.035 * CGFloat(max(0, 0.45 - d) / 0.45)  // little peak when perky
        let belly = s * (0.05 + 0.03 * CGFloat(d))  // sides bulge out near the base
        var p = Path()
        p.move(to: CGPoint(x: c, y: ground))
        p.addLine(to: CGPoint(x: c - w / 2 + k, y: ground))
        p.addQuadCurve(to: CGPoint(x: c - w / 2, y: ground - k), control: CGPoint(x: c - w / 2 - s * 0.01, y: ground))
        p.addCurve(to: CGPoint(x: c, y: top - tip),
                   control1: CGPoint(x: c - w / 2 - belly, y: ground - h * 0.55),
                   control2: CGPoint(x: c - w * 0.36, y: top - tip * 0.3))
        p.addCurve(to: CGPoint(x: c + w / 2, y: ground - k),
                   control1: CGPoint(x: c + w * 0.36, y: top - tip * 0.3),
                   control2: CGPoint(x: c + w / 2 + belly, y: ground - h * 0.55))
        p.addQuadCurve(to: CGPoint(x: c + w / 2 - k, y: ground), control: CGPoint(x: c + w / 2 + s * 0.01, y: ground))
        p.closeSubpath()
        return p
    }

    // MARK: Face

    static func drawFace(_ ctx: GraphicsContext, pose: SlimePose, c: CGFloat, top: CGFloat, w: CGFloat, h: CGFloat,
                         d: Double, s: CGFloat, time: Double) {
        let ink = Color(red: 0.16, green: 0.09, blue: 0.14)
        let (eyeY, dx, e) = eyeGeometry(top: top, w: w, h: h, d: d, s: s)
        for side in [-1.0, 1.0] {
            let x = c + CGFloat(side) * dx
            switch pose.eyes {
            case .sparkly, .open:
                let big: CGFloat = pose.eyes == .sparkly ? 1.12 : 1
                let rect = CGRect(x: x - e * 0.42 * big, y: eyeY - e * 0.5 * big, width: e * 0.84 * big, height: e * big)
                ctx.fill(Path(ellipseIn: rect), with: .color(ink))
                circle(ctx, CGPoint(x: x - e * 0.13, y: eyeY - e * 0.2), e * 0.17, .white)
                if pose.eyes == .sparkly { circle(ctx, CGPoint(x: x + e * 0.14, y: eyeY + e * 0.18), e * 0.08, .white) }
            case .sleepy, .teary:
                var lid = Path()
                lid.move(to: CGPoint(x: x - e * 0.42, y: eyeY))
                lid.addQuadCurve(to: CGPoint(x: x + e * 0.42, y: eyeY), control: CGPoint(x: x, y: eyeY + e * 0.55))
                lid.closeSubpath()
                ctx.fill(lid, with: .color(ink))
                var line = Path()
                line.move(to: CGPoint(x: x - e * 0.48, y: eyeY - e * 0.02))
                line.addLine(to: CGPoint(x: x + e * 0.48, y: eyeY - e * 0.02))
                ctx.stroke(line, with: .color(ink), style: StrokeStyle(lineWidth: s * 0.012, lineCap: .round))
                if pose.eyes == .teary {
                    let tx = x + CGFloat(side) * e * 0.35, ty = eyeY + e * 0.55
                    var tear = Path()
                    tear.move(to: CGPoint(x: tx, y: ty - e * 0.25))
                    tear.addQuadCurve(to: CGPoint(x: tx, y: ty + e * 0.25), control: CGPoint(x: tx + e * 0.3, y: ty + e * 0.2))
                    tear.addQuadCurve(to: CGPoint(x: tx, y: ty - e * 0.25), control: CGPoint(x: tx - e * 0.3, y: ty + e * 0.2))
                    ctx.fill(tear, with: .color(Color(red: 0.5, green: 0.78, blue: 1)))
                }
            case .squint:
                ctx.fill(Path(ellipseIn: CGRect(x: x - e * 0.4, y: eyeY - e * 0.12, width: e * 0.8, height: e * 0.36)),
                         with: .color(ink))
                var brow = Path()
                brow.move(to: CGPoint(x: x - CGFloat(side) * e * 0.5, y: eyeY - e * 0.62))
                brow.addLine(to: CGPoint(x: x + CGFloat(side) * e * 0.45, y: eyeY - e * 0.32))
                ctx.stroke(brow, with: .color(ink), style: StrokeStyle(lineWidth: s * 0.016, lineCap: .round))
            }
        }
        if pose.blush {
            for side in [-1.0, 1.0] {
                let x = c + CGFloat(side) * (dx + e * 0.45)
                ctx.fill(Path(ellipseIn: CGRect(x: x - e * 0.35, y: eyeY + e * 0.42, width: e * 0.7, height: e * 0.32)),
                         with: .color(Color(red: 1, green: 0.45, blue: 0.5).opacity(0.45)))
            }
        }
        let my = eyeY + e * 0.8
        let mw = min(w * 0.2, s * 0.14)
        var mouth = Path()
        switch pose.mouth {
        case .grin:
            mouth.move(to: CGPoint(x: c - mw / 2, y: my - e * 0.05))
            mouth.addQuadCurve(to: CGPoint(x: c + mw / 2, y: my - e * 0.05), control: CGPoint(x: c, y: my + e * 0.75))
            mouth.closeSubpath()
            ctx.fill(mouth, with: .color(ink))
            var clipped = ctx
            clipped.clip(to: mouth)
            clipped.fill(Path(ellipseIn: CGRect(x: c - mw * 0.25, y: my + e * 0.2, width: mw * 0.5, height: e * 0.4)),
                         with: .color(Color(red: 1, green: 0.45, blue: 0.5)))
        case .smile:
            mouth.move(to: CGPoint(x: c - mw * 0.4, y: my))
            mouth.addQuadCurve(to: CGPoint(x: c + mw * 0.4, y: my), control: CGPoint(x: c, y: my + e * 0.45))
            ctx.stroke(mouth, with: .color(ink), style: StrokeStyle(lineWidth: s * 0.014, lineCap: .round))
        case .flat:
            mouth.move(to: CGPoint(x: c - mw * 0.28, y: my + e * 0.1))
            mouth.addLine(to: CGPoint(x: c + mw * 0.28, y: my + e * 0.1))
            ctx.stroke(mouth, with: .color(ink), style: StrokeStyle(lineWidth: s * 0.014, lineCap: .round))
        case .frown:
            mouth.move(to: CGPoint(x: c - mw * 0.35, y: my + e * 0.3))
            mouth.addQuadCurve(to: CGPoint(x: c + mw * 0.35, y: my + e * 0.3), control: CGPoint(x: c, y: my - e * 0.15))
            ctx.stroke(mouth, with: .color(ink), style: StrokeStyle(lineWidth: s * 0.014, lineCap: .round))
        case .open:
            ctx.fill(Path(ellipseIn: CGRect(x: c - mw * 0.22, y: my - e * 0.05, width: mw * 0.44, height: e * 0.55)),
                     with: .color(ink))
        }
    }

    // MARK: Accessories

    /// Eye placement, shared by the face and accessories that sit on it (sunglasses, headphones).
    static func eyeGeometry(top: CGFloat, w: CGFloat, h: CGFloat, d: Double, s: CGFloat) -> (y: CGFloat, dx: CGFloat, e: CGFloat) {
        (top + h * (0.45 + 0.05 * CGFloat(d)), min(w * 0.2, s * 0.15), s * 0.12 * CGFloat(1 - 0.25 * d))
    }

    static func drawAccessory(_ ctx: GraphicsContext, _ accessory: SlimeAccessory, body: Path, c: CGFloat, top: CGFloat,
                              ground: CGFloat, w: CGFloat, h: CGFloat, d: Double, s: CGFloat) {
        let (eyeY, dx, e) = eyeGeometry(top: top, w: w, h: h, d: d, s: s)
        let ink = Color(red: 0.16, green: 0.09, blue: 0.14)
        let gold = Color(red: 1, green: 0.8, blue: 0.2)
        let goldDeep = Color(red: 0.85, green: 0.55, blue: 0.08)
        switch accessory {
        case .none:
            break
        case .sprout:
            var stem = Path()
            stem.move(to: CGPoint(x: c, y: top + s * 0.01))
            stem.addQuadCurve(to: CGPoint(x: c + s * 0.01, y: top - s * 0.09), control: CGPoint(x: c - s * 0.02, y: top - s * 0.05))
            ctx.stroke(stem, with: .color(Color(red: 0.25, green: 0.6, blue: 0.2)), style: StrokeStyle(lineWidth: s * 0.014, lineCap: .round))
            for side in [-1.0, 1.0] {
                let leaf = Path(ellipseIn: CGRect(x: -s * 0.05, y: -s * 0.022, width: s * 0.1, height: s * 0.044))
                    .applying(CGAffineTransform(rotationAngle: CGFloat(side) * -0.5)
                        .concatenating(CGAffineTransform(translationX: c + s * 0.01 + CGFloat(side) * s * 0.045, y: top - s * 0.095)))
                ctx.fill(leaf, with: .color(Color(red: 0.4, green: 0.8, blue: 0.3)))
            }
        case .bow:
            let bx = c + w * 0.24, by = top + h * 0.1
            let pink = Color(red: 1, green: 0.42, blue: 0.62)
            for side in [-1.0, 1.0] {
                var wing = Path()
                wing.move(to: CGPoint(x: bx, y: by))
                wing.addLine(to: CGPoint(x: bx + CGFloat(side) * s * 0.1, y: by - s * 0.06))
                wing.addLine(to: CGPoint(x: bx + CGFloat(side) * s * 0.1, y: by + s * 0.06))
                wing.closeSubpath()
                ctx.fill(wing, with: .color(pink))
            }
            circle(ctx, CGPoint(x: bx, y: by), s * 0.03, Color(red: 0.9, green: 0.25, blue: 0.45))
        case .sweatband:
            var band = ctx
            band.clip(to: body)
            let y = top + h * 0.17
            band.fill(Path(CGRect(x: c - w, y: y, width: w * 2, height: s * 0.05)), with: .color(Color(red: 0.95, green: 0.25, blue: 0.3)))
            band.fill(Path(CGRect(x: c - w, y: y + s * 0.018, width: w * 2, height: s * 0.012)), with: .color(.white.opacity(0.9)))
        case .cap:
            let blue = Color(red: 0.2, green: 0.45, blue: 0.95)
            let capW = w * 0.62, capH = s * 0.11
            var dome = Path()
            dome.move(to: CGPoint(x: c - capW / 2, y: top + s * 0.03))
            dome.addQuadCurve(to: CGPoint(x: c + capW / 2, y: top + s * 0.03), control: CGPoint(x: c, y: top - capH * 1.5))
            dome.closeSubpath()
            ctx.fill(dome, with: .color(blue))
            ctx.fill(Path(ellipseIn: CGRect(x: c + capW * 0.1, y: top + s * 0.01, width: capW * 0.75, height: s * 0.045)),
                     with: .color(Color(red: 0.12, green: 0.3, blue: 0.75)))
            circle(ctx, CGPoint(x: c, y: top - capH * 0.68), s * 0.012, .white)
        case .headphones:
            var band = Path()
            band.move(to: CGPoint(x: c - w * 0.46, y: eyeY))
            band.addQuadCurve(to: CGPoint(x: c + w * 0.46, y: eyeY), control: CGPoint(x: c, y: top - h * 0.55))
            ctx.stroke(band, with: .color(ink), style: StrokeStyle(lineWidth: s * 0.022, lineCap: .round))
            for side in [-1.0, 1.0] {
                let x = c + CGFloat(side) * w * 0.47
                ctx.fill(Path(roundedRect: CGRect(x: x - s * 0.035, y: eyeY - s * 0.06, width: s * 0.07, height: s * 0.12), cornerRadius: s * 0.03),
                         with: .color(Color(red: 0.95, green: 0.3, blue: 0.35)))
            }
        case .sunglasses:
            for side in [-1.0, 1.0] {
                let x = c + CGFloat(side) * dx
                ctx.fill(Path(roundedRect: CGRect(x: x - e * 0.62, y: eyeY - e * 0.42, width: e * 1.24, height: e * 0.8), cornerRadius: e * 0.3),
                         with: .color(ink))
                ctx.fill(Path(roundedRect: CGRect(x: x - e * 0.4, y: eyeY - e * 0.3, width: e * 0.35, height: e * 0.14), cornerRadius: e * 0.07),
                         with: .color(.white.opacity(0.55)))
            }
            var bridge = Path()
            bridge.move(to: CGPoint(x: c - dx + e * 0.6, y: eyeY - e * 0.15))
            bridge.addLine(to: CGPoint(x: c + dx - e * 0.6, y: eyeY - e * 0.15))
            ctx.stroke(bridge, with: .color(ink), lineWidth: s * 0.012)
        case .scarf:
            var wrap = ctx
            wrap.clip(to: body)
            let y = ground - h * 0.32
            let red = Color(red: 0.9, green: 0.22, blue: 0.25)
            wrap.fill(Path(CGRect(x: c - w, y: y, width: w * 2, height: s * 0.065)), with: .color(red))
            for i in 0..<6 {
                wrap.fill(Path(CGRect(x: c - w * 0.5 + CGFloat(i) * w * 0.2, y: y, width: w * 0.06, height: s * 0.065)),
                          with: .color(.white.opacity(0.7)))
            }
            ctx.fill(Path(roundedRect: CGRect(x: c + w * 0.18, y: y + s * 0.03, width: s * 0.06, height: s * 0.13), cornerRadius: s * 0.015),
                     with: .color(red))
        case .halo:
            let ring = Path(ellipseIn: CGRect(x: c - w * 0.28, y: top - s * 0.1, width: w * 0.56, height: s * 0.07))
            ctx.stroke(ring, with: .color(gold), lineWidth: s * 0.022)
            var glow = ctx
            glow.addFilter(.blur(radius: s * 0.015))
            glow.stroke(ring, with: .color(gold.opacity(0.6)), lineWidth: s * 0.03)
        case .tiara:
            var t = Path()
            let tw = w * 0.56, base = top + s * 0.03
            t.move(to: CGPoint(x: c - tw / 2, y: base))
            for i in 0...4 {
                let x = c - tw / 2 + tw * CGFloat(i) / 4
                t.addLine(to: CGPoint(x: x, y: base - (i % 2 == 0 ? s * 0.07 : s * 0.03) - (i == 2 ? s * 0.04 : 0)))
            }
            t.addLine(to: CGPoint(x: c + tw / 2, y: base))
            t.closeSubpath()
            ctx.fill(t, with: .linearGradient(Gradient(colors: [Color(white: 0.97), Color(white: 0.72)]),
                                              startPoint: CGPoint(x: c, y: base - s * 0.08), endPoint: CGPoint(x: c, y: base)))
            circle(ctx, CGPoint(x: c, y: base - s * 0.055), s * 0.024, Color(red: 1, green: 0.35, blue: 0.6))
        case .crown:
            var cr = Path()
            let cw = w * 0.62, base = top + s * 0.04, tall = s * 0.17
            cr.move(to: CGPoint(x: c - cw / 2, y: base))
            cr.addLine(to: CGPoint(x: c - cw / 2, y: base - tall))
            cr.addLine(to: CGPoint(x: c - cw / 4, y: base - tall * 0.55))
            cr.addLine(to: CGPoint(x: c, y: base - tall * 1.15))
            cr.addLine(to: CGPoint(x: c + cw / 4, y: base - tall * 0.55))
            cr.addLine(to: CGPoint(x: c + cw / 2, y: base - tall))
            cr.addLine(to: CGPoint(x: c + cw / 2, y: base))
            cr.closeSubpath()
            ctx.fill(cr, with: .linearGradient(Gradient(colors: [gold, goldDeep]),
                                               startPoint: CGPoint(x: c, y: base - tall), endPoint: CGPoint(x: c, y: base)))
            for (i, color) in [Color(red: 0.9, green: 0.15, blue: 0.3), Color(red: 0.2, green: 0.5, blue: 1),
                               Color(red: 0.9, green: 0.15, blue: 0.3)].enumerated() {
                circle(ctx, CGPoint(x: c - cw * 0.28 + cw * 0.28 * CGFloat(i), y: base - tall * 0.25), s * 0.02, color)
            }
        }
    }

    // MARK: Helpers

    static func adjust(_ rgb: SIMD3<Double>, saturation: Double, redness: Double) -> SIMD3<Double> {
        let gray = 0.3 * rgb.x + 0.59 * rgb.y + 0.11 * rgb.z
        var out = SIMD3(repeating: gray) + (rgb - SIMD3(repeating: gray)) * min(1, max(0, saturation))
        let red = SIMD3<Double>(0.93, 0.22, 0.18)
        out += (red - out) * min(1, max(0, redness))
        return out
    }

    static func swatch(_ rgb: SIMD3<Double>) -> Color { Color(red: rgb.x, green: rgb.y, blue: rgb.z) }

    static func circle(_ ctx: GraphicsContext, _ center: CGPoint, _ r: CGFloat, _ color: Color) {
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)), with: .color(color))
    }

    static func rotation(_ angle: CGFloat, around p: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: p.x, y: p.y).rotated(by: angle).translatedBy(x: -p.x, y: -p.y)
    }

    static func star(_ ctx: GraphicsContext, at p: CGPoint, r: CGFloat, color: Color) {
        var path = Path()
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4 - .pi / 2
            let radius = i % 2 == 0 ? r : r * 0.32
            let point = CGPoint(x: p.x + cos(angle) * radius, y: p.y + sin(angle) * radius)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        ctx.fill(path, with: .color(color))
    }
}
