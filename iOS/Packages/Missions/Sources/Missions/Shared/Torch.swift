import Foundation
import ImageIO
import Localization
import SwiftUI
import Telemetry

// MARK: - Pure rules

/// Flashlight setting for the camera missions, cycled by the button like the iOS Camera app.
public enum TorchMode: String, CaseIterable, Sendable {
    case auto, on, off

    /// Auto → On → Off → Auto.
    public var next: TorchMode {
        switch self {
        case .auto: .on
        case .on: .off
        case .off: .auto
        }
    }

    var symbol: String {
        switch self {
        case .auto: "bolt.badge.automatic.fill"
        case .on: "bolt.fill"
        case .off: "bolt.slash.fill"
        }
    }

    var title: String {
        switch self {
        case .auto: L10n.tr("Auto")
        case .on: L10n.tr("On")
        case .off: L10n.tr("Off")
        }
    }
}

/// The chosen mode, shared by every camera mission (`gloop.camera.torch`, default Auto).
public struct TorchSettings: Sendable {
    nonisolated(unsafe) private let defaults: UserDefaults
    private let key = "gloop.camera.torch"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public var mode: TorchMode {
        get { defaults.string(forKey: key).flatMap(TorchMode.init(rawValue:)) ?? .auto }
        nonmutating set { defaults.set(newValue.rawValue, forKey: key) }
    }
}

/// Auto mode: turn the flashlight on after a few dark readings in a row, then keep it on.
/// Latching matters: once lit, the scene looks bright, and switching off again would flicker.
public struct AutoTorch: Equatable, Sendable {
    /// EXIF brightness below this counts as dark (a dim bedroom is around 0…1, a lit room 2+).
    public static let darkThreshold = 0.0
    /// About 1.5 s at two readings per second; one bright reading starts over.
    public static let requiredDarkReadings = 3

    public private(set) var darkStreak = 0
    public private(set) var latched = false

    public init() {}

    /// Returns whether the flashlight should be on now.
    public mutating func record(brightness: Double) -> Bool {
        guard !latched else { return true }
        darkStreak = brightness < Self.darkThreshold ? darkStreak + 1 : 0
        if darkStreak >= Self.requiredDarkReadings { latched = true }
        return latched
    }
}

/// Scene brightness from a camera frame's attachments (`{Exif}.BrightnessValue`).
public enum CameraBrightness {
    public static func value(fromAttachments attachments: [String: Any]) -> Double? {
        guard let exif = attachments[kCGImagePropertyExifDictionary as String] as? [String: Any] else { return nil }
        return (exif[kCGImagePropertyExifBrightnessValue as String] as? NSNumber)?.doubleValue
    }
}

// MARK: - Controller + button

/// Drives one screen's flashlight: the user's mode, auto decisions from brightness readings, and
/// the camera's torch. Off when the screen ends (`reset`).
@MainActor
@Observable
final class TorchController {
    private(set) var mode: TorchMode
    private(set) var isLit = false
    /// Auto just switched on (shows "It's dark: flashlight on" for a moment).
    private(set) var autoJustTurnedOn = false
    private(set) var lastBrightness: Double?
    @ObservationIgnored private var auto = AutoTorch()
    @ObservationIgnored private weak var camera: CameraFeed?
    @ObservationIgnored private let settings: TorchSettings
    @ObservationIgnored private let mission: String
    @ObservationIgnored private var active = false

    /// No button without a flashlight (iPad, Simulator).
    var isAvailable: Bool { CameraFeed.hasTorch }

    init(camera: CameraFeed, mission: String, settings: TorchSettings = TorchSettings()) {
        self.camera = camera
        self.mission = mission
        self.settings = settings
        mode = settings.mode
        camera.onBrightness = { [weak self] value in
            Task { @MainActor in self?.brightness(value) }
        }
    }

    /// The camera is running (again): light up if the mode says so.
    func activate() {
        active = true
        apply()
    }

    func cycle() {
        mode = mode.next
        settings.mode = mode
        Telemetry.shared.send(.action(.flashlight(mode: mode.rawValue, auto: false, mission: mission)))
        apply()
    }

    func brightness(_ value: Double) {
        lastBrightness = value
        guard active, mode == .auto, !auto.latched else { return }
        if auto.record(brightness: value) {
            Telemetry.shared.send(.action(.flashlight(mode: TorchMode.auto.rawValue, auto: true, mission: mission)))
            apply()
            withAnimation { autoJustTurnedOn = true }
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation { autoJustTurnedOn = false }
            }
        }
    }

    /// Screen done / gone: flashlight off. `activate()` brings it back.
    func reset() {
        active = false
        apply()
    }

    private func apply() {
        let on = active && (mode == .on || (mode == .auto && auto.latched))
        isLit = on
        camera?.setTorch(on)
    }
}

/// Round flashlight button for the top-right corner of a camera view, plus the auto notice.
struct TorchButton: View {
    let controller: TorchController

    var body: some View {
        if controller.isAvailable {
            VStack(alignment: .trailing, spacing: 8) {
                Button { controller.cycle() } label: {
                    Image(systemName: controller.mode.symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(controller.isLit ? Color.yellow : Color.white)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial.opacity(0.9), in: .circle)
                        .environment(\.colorScheme, .dark)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.tr("Flashlight: \(controller.mode.title)"))
                .sensoryFeedback(.selection, trigger: controller.mode)
                if controller.autoJustTurnedOn {
                    Text("It's dark: flashlight on")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: .capsule)
                        .environment(\.colorScheme, .dark)
                        .foregroundStyle(.white)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(12)
        }
    }
}
