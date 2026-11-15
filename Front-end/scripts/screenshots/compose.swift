// Composes an App Store screenshot: cream→orange gradient, bold headline (accent word in orange)
// and the raw capture inside an iPhone-shaped frame.
//
//   compose <raw.png> <out.png> <width> <height> <headline with \n> <accent>
import AppKit
import SwiftUI

struct Shot: View {
    let raw: NSImage
    let headline: String
    let accent: String
    let size: CGSize

    var body: some View {
        let w = size.width, h = size.height
        let deviceW = w * 0.78
        let deviceH = deviceW * raw.size.height / raw.size.width
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(red: 1, green: 0.957, blue: 0.878), Color(red: 1, green: 0.761, blue: 0.478)],
                           startPoint: .top, endPoint: .bottom)
            VStack(spacing: h * 0.035) {
                title
                    .font(.system(size: w * 0.088, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineSpacing(-w * 0.01)
                    .padding(.top, h * 0.06)
                    .padding(.horizontal, w * 0.06)
                Image(nsImage: raw)
                    .resizable()
                    .frame(width: deviceW, height: deviceH)
                    .clipShape(.rect(cornerRadius: deviceW * 0.11, style: .continuous))
                    .padding(deviceW * 0.028)
                    .background(Color(red: 0.08, green: 0.07, blue: 0.07),
                                in: .rect(cornerRadius: deviceW * 0.135, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: w * 0.03, y: w * 0.02)
            }
        }
        .frame(width: w, height: h, alignment: .top)
        .clipped()
    }

    /// Headline with the accent part in orange.
    private var title: Text {
        let ink = Color(red: 0.165, green: 0.102, blue: 0.071)
        let orange = Color(red: 0.949, green: 0.416, blue: 0.106)
        guard !accent.isEmpty, let range = headline.range(of: accent) else { return Text(headline).foregroundColor(ink) }
        let before = Text(headline[..<range.lowerBound]).foregroundColor(ink)
        let middle = Text(headline[range]).foregroundColor(orange)
        let after = Text(headline[range.upperBound...]).foregroundColor(ink)
        return Text("\(before)\(middle)\(after)")
    }
}

@main
struct Compose {
    @MainActor static func main() throws {
        let a = CommandLine.arguments
        guard a.count == 7, let raw = NSImage(contentsOfFile: a[1]), let w = Double(a[3]), let h = Double(a[4]) else {
            fatalError("usage: compose <raw.png> <out.png> <width> <height> <headline> <accent>")
        }
        let headline = a[5].replacingOccurrences(of: "\\n", with: "\n")
        let renderer = ImageRenderer(content: Shot(raw: raw, headline: headline, accent: a[6], size: CGSize(width: w, height: h)))
        renderer.scale = 1
        guard let cg = renderer.cgImage else { fatalError("render failed") }
        // App Store screenshots: RGB, no alpha.
        let ctx = CGContext(data: nil, width: Int(w), height: Int(h), bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        let png = NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
        try png.write(to: URL(fileURLWithPath: a[2]))
    }
}
