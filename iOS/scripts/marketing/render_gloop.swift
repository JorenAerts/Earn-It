// Renders Gloop as transparent PNG stickers for social posts (TikTok, Reels, carousels, press kit),
// with the same slime drawing code as the app (Packages/WidgetShared/.../Slime/SlimeDrawing.swift).
//
//   cd iOS && scripts/marketing/render_gloop.sh
//
// Writes ../docs/marketing/gloop/<name>.png (1024×1024, transparent).
import AppKit
import SwiftUI

struct Sticker {
    let name: String
    let pose: SlimePose
    var color: SlimeColor = .orange
}

let baseStickers: [Sticker] = [
    // Moods (CoachMood in the app).
    .init(name: "proud", pose: SlimePose(droop: 0, eyes: .sparkly, mouth: .grin, blush: true, sparkle: true)),
    .init(name: "calm", pose: SlimePose(droop: 0.1, eyes: .open, mouth: .smile)),
    .init(name: "suspicious", pose: SlimePose(droop: 0.15, eyes: .squint, mouth: .flat)),
    .init(name: "angry", pose: SlimePose(droop: 0.35, eyes: .squint, mouth: .frown, steam: true, redness: 0.6)),
    .init(name: "disappointed", pose: SlimePose(droop: 0.6, eyes: .teary, mouth: .frown, drips: 2, saturation: 0.8)),
    .init(name: "sleepy", pose: SlimePose(droop: 0.75, eyes: .sleepy, mouth: .flat, drips: 1, saturation: 0.85)),
    .init(name: "shocked", pose: SlimePose(droop: 0.1, eyes: .open, mouth: .open, sweat: true)),
    // Melting stages: 1 → 4 snoozes.
    .init(name: "melt-1", pose: SlimePose(droop: 0.2, eyes: .open, mouth: .flat, sweat: true)),
    .init(name: "melt-2", pose: SlimePose(droop: 0.45, eyes: .squint, mouth: .frown, drips: 1, redness: 0.3)),
    .init(name: "melt-3", pose: SlimePose(droop: 0.7, eyes: .teary, mouth: .frown, drips: 2, saturation: 0.8, redness: 0.5)),
    .init(name: "melt-4-puddle", pose: SlimePose(droop: 1, eyes: .teary, mouth: .open, drips: 3, saturation: 0.6, redness: 0.6)),
    // Friend colours (app icons / Buddies).
    .init(name: "friend-mint", pose: SlimePose(droop: 0.05, eyes: .sparkly, mouth: .grin, sparkle: true, accessory: .cap), color: .mint),
    .init(name: "friend-grape", pose: SlimePose(droop: 0.05, eyes: .open, mouth: .grin, blush: true, accessory: .bow), color: .grape),
    .init(name: "friend-midnight", pose: SlimePose(droop: 0.1, eyes: .open, mouth: .smile, accessory: .headphones), color: .midnight),
    .init(name: "friend-gold", pose: SlimePose(droop: 0, eyes: .sparkly, mouth: .grin, sparkle: true, accessory: .crown), color: .gold),
]
// Every evolution accessory (Droplet … King Gloop).
let stickers = baseStickers + SlimeAccessory.allCases.filter { $0 != .none }.map { accessory in
    Sticker(name: "stage-\(accessory.rawValue)",
            pose: SlimePose(droop: 0.05, eyes: .sparkly, mouth: .grin, blush: true, accessory: accessory))
}

struct StickerView: View {
    let sticker: Sticker
    var body: some View {
        Canvas { ctx, size in
            SlimeRenderer.draw(ctx, size: size, pose: sticker.pose, color: sticker.color, time: 0.4)
        }
        .frame(width: 1024, height: 1024)
    }
}

@main
struct RenderGloop {
    @MainActor static func main() throws {
        let out = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        for sticker in stickers {
            let renderer = ImageRenderer(content: StickerView(sticker: sticker))
            renderer.scale = 1
            renderer.isOpaque = false
            guard let cg = renderer.cgImage else { fatalError("render failed: \(sticker.name)") }
            let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!
            try png.write(to: out.appending(path: "\(sticker.name).png"))
            print("wrote", sticker.name)
        }
    }
}
