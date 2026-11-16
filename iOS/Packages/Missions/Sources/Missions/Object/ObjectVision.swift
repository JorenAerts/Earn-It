import CoreImage
import CoreVideo
import Foundation
import ImageIO
import Vision

/// One analysed camera frame: the item cut out of its background + its feature print.
struct AnalysedFrame: @unchecked Sendable {
    let print: VNFeaturePrintObservation
    let cutout: CGImage?
    /// Share of the frame covered by the detected object (0…1).
    let coverage: Double
}

/// Thin wrapper around Apple's Vision requests. Synchronous: call it off the main thread.
enum ObjectVision {
    /// Portrait back camera frames arrive rotated; Vision needs to know.
    static let orientation: CGImagePropertyOrientation = .right
    /// Ignore "objects" that cover less than this share of the frame (too far / noise).
    static let minimumCoverage = 0.02

    private static let context = CIContext()

    /// Isolates the prominent object(s) and fingerprints them. nil = nothing usable in view.
    static func analyse(_ buffer: CVPixelBuffer, keepCutout: Bool = false) -> AnalysedFrame? {
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: orientation)
        let mask = VNGenerateForegroundInstanceMaskRequest()
        do {
            try handler.perform([mask])
            guard let observation = mask.results?.first, !observation.allInstances.isEmpty else { return nil }
            let cutoutBuffer = try observation.generateMaskedImage(ofInstances: observation.allInstances,
                                                                    from: handler, croppedToInstancesExtent: true)
            let frameArea = Double(CVPixelBufferGetWidth(buffer) * CVPixelBufferGetHeight(buffer))
            let cutArea = Double(CVPixelBufferGetWidth(cutoutBuffer) * CVPixelBufferGetHeight(cutoutBuffer))
            let coverage = frameArea > 0 ? cutArea / frameArea : 0
            guard coverage >= minimumCoverage else { return nil }

            let printRequest = VNGenerateImageFeaturePrintRequest()
            try VNImageRequestHandler(cvPixelBuffer: cutoutBuffer, orientation: .up).perform([printRequest])
            guard let print = printRequest.results?.first else { return nil }

            var cutout: CGImage?
            if keepCutout {
                let image = CIImage(cvPixelBuffer: cutoutBuffer)
                cutout = context.createCGImage(image, from: image.extent)
            }
            return AnalysedFrame(print: print, cutout: cutout, coverage: coverage)
        } catch {
            return nil
        }
    }

    static func distance(_ a: VNFeaturePrintObservation, _ b: VNFeaturePrintObservation) -> Float? {
        var d: Float = 0
        do {
            try a.computeDistance(&d, to: b)
            return d
        } catch {
            return nil
        }
    }

    /// Smallest distance from `print` to any reference.
    static func distance(_ print: VNFeaturePrintObservation, toAnyOf references: [VNFeaturePrintObservation]) -> Float? {
        references.compactMap { distance(print, $0) }.min()
    }

    static func pairwiseDistances(_ prints: [VNFeaturePrintObservation]) -> [Float] {
        var result: [Float] = []
        for i in prints.indices {
            for j in prints.indices where j > i {
                if let d = distance(prints[i], prints[j]) { result.append(d) }
            }
        }
        return result
    }
}
