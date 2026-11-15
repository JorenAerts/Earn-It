// Renders Earn It's app icons with the same slime drawing code as the app
// (Packages/WidgetShared/Sources/WidgetShared/Slime/SlimeDrawing.swift).
//
//   cd Front-end && scripts/render_icons.sh
//
// Writes App/Assets.xcassets/AppIcon.appiconset (Classic, the default), AppIcon-<Name>.appiconset
// for the alternates, and IconPreview-<choice>.imageset (small previews for the picker).
import AppKit
import SwiftUI

struct IconSpec {
    let choice: String          // AppIconChoice raw value
    let set: String             // asset catalog icon set name
    let color: SlimeColor
    let background: (top: Color, bottom: Color)
}

let specs: [IconSpec] = [
    .init(choice: "slime", set: "AppIcon", color: .orange,
          background: (Color(red: 1, green: 0.96, blue: 0.86), Color(red: 1, green: 0.84, blue: 0.62))),
    .init(choice: "mint", set: "AppIcon-Mint", color: .mint,
          background: (Color(red: 0.92, green: 1, blue: 0.96), Color(red: 0.72, green: 0.94, blue: 0.86))),
    .init(choice: "grape", set: "AppIcon-Grape", color: .grape,
          background: (Color(red: 0.97, green: 0.93, blue: 1), Color(red: 0.84, green: 0.76, blue: 1))),
    .init(choice: "midnight", set: "AppIcon-Midnight", color: .midnight,
          background: (Color(red: 0.12, green: 0.14, blue: 0.28), Color(red: 0.04, green: 0.05, blue: 0.12))),
    .init(choice: "gold", set: "AppIcon-Gold", color: .gold,
          background: (Color(red: 1, green: 0.98, blue: 0.88), Color(red: 1, green: 0.88, blue: 0.55))),
]

let iconPose = SlimePose(droop: 0.08, eyes: .sparkly, mouth: .grin, blush: true, sparkle: true)

struct IconView: View {
    let spec: IconSpec
    var body: some View {
        ZStack {
            LinearGradient(colors: [spec.background.top, spec.background.bottom], startPoint: .top, endPoint: .bottom)
            Canvas { ctx, size in
                // Slightly smaller than the canvas and nudged down, so it sits centred inside the icon mask.
                let inset = size.width * 0.06
                var c = ctx
                c.translateBy(x: inset, y: inset * 1.4)
                SlimeRenderer.draw(c, size: CGSize(width: size.width - inset * 2, height: size.height - inset * 2),
                                   pose: iconPose, color: spec.color, time: 0.4)
            }
        }
        .frame(width: 1024, height: 1024)
    }
}

@MainActor
func png(_ view: some View, size: CGFloat) -> Data {
    let renderer = ImageRenderer(content: view.frame(width: 1024, height: 1024).scaleEffect(size / 1024)
        .frame(width: size, height: size))
    renderer.scale = 1
    guard let cg = renderer.cgImage else { fatalError("render failed") }
    // App icons must not have an alpha channel.
    let ctx = CGContext(data: nil, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

func write(_ data: Data, to dir: URL, file: String, contents: String) throws {
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try data.write(to: dir.appending(path: file))
    try contents.write(to: dir.appending(path: "Contents.json"), atomically: true, encoding: .utf8)
}

func iconContents(_ file: String) -> String {
    """
    {
      "images" : [
        { "filename" : "\(file)", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
      ],
      "info" : { "author" : "xcode", "version" : 1 }
    }
    """
}

func previewContents(_ file: String) -> String {
    """
    {
      "images" : [ { "filename" : "\(file)", "idiom" : "universal" } ],
      "info" : { "author" : "xcode", "version" : 1 }
    }
    """
}

@main
struct RenderIcons {
    @MainActor static func main() throws {
        let assets = URL(filePath: FileManager.default.currentDirectoryPath).appending(path: "App/Assets.xcassets")
        for spec in specs {
            let file = "\(spec.set).png"
            try write(png(IconView(spec: spec), size: 1024), to: assets.appending(path: "\(spec.set).appiconset"),
                      file: file, contents: iconContents(file))
            let preview = "IconPreview-\(spec.choice).png"
            try write(png(IconView(spec: spec), size: 180), to: assets.appending(path: "IconPreview-\(spec.choice).imageset"),
                      file: preview, contents: previewContents(preview))
            print("wrote \(spec.set)")
        }
    }
}
