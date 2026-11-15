import Foundation
import Observation
import SwiftUI
import UIKit
import WidgetShared

/// Light / Dark / Match iPhone. New installs start in light mode.
public enum AppearancePreference: String, CaseIterable, Codable, Sendable, Identifiable {
    case light, dark, system

    public var id: String { rawValue }
    public static let `default`: AppearancePreference = .light

    public var title: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .system: "Match iPhone"
        }
    }

    /// nil = follow the system.
    public var colorScheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }
}

/// The app icons users can pick (Settings › Appearance). Asset names must match the
/// `AppIcon-*.appiconset`s in `App/Assets.xcassets` (rendered by `scripts/render_icons.swift`).
public enum AppIconChoice: String, CaseIterable, Codable, Sendable, Identifiable {
    case slime, mint, grape, midnight, gold

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .slime: "Classic"
        case .mint: "Mint"
        case .grape: "Grape"
        case .midnight: "Midnight"
        case .gold: "Gold"
        }
    }

    /// `nil` = the primary icon (`AppIcon`).
    public var alternateIconName: String? {
        switch self {
        case .slime: nil
        case .mint: "AppIcon-Mint"
        case .grape: "AppIcon-Grape"
        case .midnight: "AppIcon-Midnight"
        case .gold: "AppIcon-Gold"
        }
    }

    /// Small preview image in the picker (`IconPreview-<raw>` in Assets.xcassets).
    public var previewImageName: String { "IconPreview-\(rawValue)" }

    /// The slime colour that goes with this icon.
    public var slimeColor: SlimeColor {
        switch self {
        case .slime: .orange
        case .mint: .mint
        case .grape: .grape
        case .midnight: .midnight
        case .gold: .gold
        }
    }

    public static func from(alternateIconName name: String?) -> AppIconChoice {
        allCases.first { $0.alternateIconName == name } ?? .slime
    }
}

/// Appearance preferences: colour scheme, app icon, and Gloop's colour.
@MainActor
@Observable
public final class AppearanceSettings {
    public static let shared = AppearanceSettings()

    @ObservationIgnored private let defaults: UserDefaults
    private static let schemeKey = "gloop.appearance"
    private static let matchKey = "gloop.appearance.matchSlimeToIcon"
    private static let colorKey = "gloop.appearance.slimeColor"

    public var preference: AppearancePreference {
        didSet { defaults.set(preference.rawValue, forKey: Self.schemeKey) }
    }

    /// Recolour Gloop to match the chosen app icon.
    public var matchSlimeToIcon: Bool {
        didSet { defaults.set(matchSlimeToIcon, forKey: Self.matchKey) }
    }

    /// Gloop's colour when not matching the icon.
    public var customSlimeColor: SlimeColor {
        didSet { defaults.set(customSlimeColor.rawValue, forKey: Self.colorKey) }
    }

    /// The icon currently set on the home screen.
    public private(set) var icon: AppIconChoice

    public init(defaults: UserDefaults = .standard, currentIconName: String? = nil) {
        self.defaults = defaults
        preference = defaults.string(forKey: Self.schemeKey).flatMap(AppearancePreference.init(rawValue:)) ?? .default
        matchSlimeToIcon = defaults.object(forKey: Self.matchKey) as? Bool ?? true
        customSlimeColor = defaults.string(forKey: Self.colorKey).flatMap(SlimeColor.init(rawValue:)) ?? .orange
        icon = AppIconChoice.from(alternateIconName: currentIconName)
    }

    private convenience init() {
        self.init(defaults: .standard, currentIconName: UIApplication.shared.alternateIconName)
    }

    public var slimeColor: SlimeColor { matchSlimeToIcon ? icon.slimeColor : customSlimeColor }

    /// Changes the home-screen icon. iOS shows its own confirmation alert.
    public func setIcon(_ choice: AppIconChoice) async -> String? {
        guard UIApplication.shared.supportsAlternateIcons else { return "This device can't change app icons." }
        do {
            try await UIApplication.shared.setAlternateIconName(choice.alternateIconName)
            icon = choice
            return nil
        } catch {
            return "Couldn't change the icon: \(error.localizedDescription)"
        }
    }
}
