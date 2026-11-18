import AVFoundation
import Core
import Foundation
import ImageIO
@testable import Missions
import Testing

private struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

struct ConsecutiveHitsTests {
    @Test func needsHitsInARow() {
        var hits = ConsecutiveHits(required: 3)
        hits.record(true); hits.record(true); hits.record(false)
        #expect(hits.streak == 0)
        #expect(hits.isComplete == false)
        hits.record(true); hits.record(true)
        #expect(abs(hits.progress - 2.0 / 3) < 0.001)
        hits.record(true)
        #expect(hits.isComplete && hits.progress == 1)
    }
}

struct SkyPolicyTests {
    @Test func anySkyCounts() {
        for label in ["sky", "cloudy", "night_sky", "sunset_sunrise", "rainbow", "Storm", "overcast"] {
            #expect(SkyPolicy.isSkyLabel(label), "\(label)")
        }
        for label in ["ceiling", "bedroom", "starfish", "rainforest", "lamp", "skyscraper"] {
            #expect(SkyPolicy.isSkyLabel(label) == false, "\(label)")
        }
    }

    @Test func scoreIsTheBestSkyLabel() {
        #expect(SkyPolicy.score([("wall", 0.9), ("cloudy", 0.4), ("sky", 0.7)]) == 0.7)
        #expect(SkyPolicy.score([("wall", 0.9), ("ceiling", 0.8)]) == 0)
        #expect(SkyPolicy.isSky(0.7))
        #expect(SkyPolicy.isSky(0.1) == false)
    }
}

struct ColorMatchTests {
    @Test func hueWrapsAroundRed() {
        #expect(ColorMatch.hueDistance(355, 5) == 10)
        #expect(ColorMatch.matches(hue: 356, saturation: 0.8, brightness: 0.7, target: .red))
        #expect(ColorMatch.matches(hue: 6, saturation: 0.8, brightness: 0.7, target: .red))
    }

    @Test func greyBlackAndWhiteNeverCount() {
        for target in ColorTarget.allCases {
            #expect(ColorMatch.matches(hue: target.hue.center, saturation: 0.05, brightness: 0.6, target: target) == false)  // grey
            #expect(ColorMatch.matches(hue: target.hue.center, saturation: 0.9, brightness: 0.05, target: target) == false)  // black
        }
    }

    @Test func colorsDontOverlap() {
        #expect(ColorMatch.matches(hue: 120, saturation: 0.7, brightness: 0.6, target: .green))
        #expect(ColorMatch.matches(hue: 120, saturation: 0.7, brightness: 0.6, target: .blue) == false)
        #expect(ColorMatch.matches(hue: 215, saturation: 0.7, brightness: 0.6, target: .purple) == false)
        for a in ColorTarget.allCases {
            for b in ColorTarget.allCases where a != b {
                #expect(ColorMatch.matches(hue: a.hue.center, saturation: 0.9, brightness: 0.9, target: b) == false, "\(a) vs \(b)")
            }
        }
    }

    @Test func targetsAreDifferentColors() {
        var rng = SeededRNG(state: 3)
        let picked = ColorMatch.targets(count: 3, rng: &rng)
        #expect(picked.count == 3 && Set(picked).count == 3)
        #expect(ColorMatch.targets(count: 99, rng: &rng).count == ColorTarget.allCases.count)
    }
}

struct BedPolicyTests {
    @Test func thresholdStaysInBounds() {
        #expect(BedMatchPolicy.threshold(pairwiseDistances: []) == BedMatchPolicy.minimumThreshold)
        #expect(BedMatchPolicy.threshold(pairwiseDistances: [0.01, 0.05]) == BedMatchPolicy.minimumThreshold)
        #expect(BedMatchPolicy.threshold(pairwiseDistances: [2]) == BedMatchPolicy.maximumThreshold)
        #expect(abs(BedMatchPolicy.threshold(pairwiseDistances: [0.3]) - 0.36) < 0.001)
    }
}

struct OutOfBedMetadataTests {
    @Test func newCameraMissions() {
        for kind in [MissionKind.sky, .bed, .colorHunt] {
            #expect(kind.category == .outOfBed && kind.needsCamera)
        }
        #expect(MissionKind.bed.needsPayload)
        #expect(MissionConfig(kind: .bed).isReady == false)
        #expect(MissionConfig(kind: .bed, payload: "x").isReady)
        #expect(MissionConfig(kind: .sky).isReady && MissionKind.sky.backupAfter == nil)
        #expect(MissionKind.colorHunt.backupAfter == 120 && MissionKind.colorHunt.targetRange == 1...3)
    }

    @MainActor @Test func everyKindIsRegistered() {
        for kind in MissionKind.allCases {
            #expect(type(of: MissionRegistry.make(MissionConfig(kind: kind))).kind == kind)
        }
    }
}

@Suite("Flashlight")
struct FlashlightTests {
    @Test func cyclesLikeTheCameraApp() {
        #expect(TorchMode.auto.next == .on)
        #expect(TorchMode.on.next == .off)
        #expect(TorchMode.off.next == .auto)
    }

    @Test func modeIsRememberedAndDefaultsToAuto() throws {
        let defaults = try #require(UserDefaults(suiteName: "torch-\(UUID().uuidString)"))
        let settings = TorchSettings(defaults: defaults)
        #expect(settings.mode == .auto)
        settings.mode = .off
        #expect(TorchSettings(defaults: defaults).mode == .off)
    }

    @Test func autoTurnsOnAfterAFewDarkReadingsAndStaysOn() {
        var auto = AutoTorch()
        let dark = AutoTorch.darkThreshold - 1, bright = AutoTorch.darkThreshold + 3
        for _ in 1..<AutoTorch.requiredDarkReadings {
            let on = auto.record(brightness: dark)
            #expect(on == false)
        }
        let lit = auto.record(brightness: dark)
        #expect(lit)
        let stillLit = auto.record(brightness: bright)
        #expect(stillLit, "latched: the lit scene must not switch it off again")
    }

    @Test func aPassingShadowDoesNotTriggerIt() {
        var auto = AutoTorch()
        let dark = AutoTorch.darkThreshold - 1, bright = AutoTorch.darkThreshold + 3
        for _ in 0..<10 {
            for _ in 1..<AutoTorch.requiredDarkReadings { _ = auto.record(brightness: dark) }
            let on = auto.record(brightness: bright)
            #expect(on == false)
        }
        #expect(auto.latched == false)
    }

    @Test func readsBrightnessFromFrameAttachments() {
        let attachments: [String: Any] = [kCGImagePropertyExifDictionary as String: [kCGImagePropertyExifBrightnessValue as String: NSNumber(value: -1.5)]]
        #expect(CameraBrightness.value(fromAttachments: attachments) == -1.5)
        #expect(CameraBrightness.value(fromAttachments: [:]) == nil)
    }

    @Test func qrScannerReadsQRCodesAndBarcodes() {
        #expect(CodeScannerView.codeTypes.contains(.qr))
        #expect(CodeScannerView.codeTypes.contains(.ean13))
    }

    @Test(arguments: MissionKind.allCases)
    func everyCameraMissionButTheSkyGetsAFlashlight(kind: MissionKind) {
        if [MissionKind.qr, .object, .bed, .colorHunt].contains(kind) {
            #expect(kind.usesTorch)
        } else if kind == .sky || kind.needsCamera == false {
            #expect(kind.usesTorch == false)
        }
    }
}
