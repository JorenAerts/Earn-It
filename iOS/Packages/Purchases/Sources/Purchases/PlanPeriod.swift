import Foundation
import Localization

/// Subscription length parsed from the ISO 8601 period in Pricing.json ("P1W", "P1M", "P3M", "P1Y").
public struct PlanPeriod: Equatable, Sendable {
    public enum Unit: String, Sendable { case day = "D", week = "W", month = "M", year = "Y" }

    public let value: Int
    public let unit: Unit

    public init(value: Int, unit: Unit) {
        self.value = value
        self.unit = unit
    }

    public init?(iso: String?) {
        guard let iso, iso.hasPrefix("P"), let last = iso.last,
              let unit = Unit(rawValue: String(last)),
              let value = Int(iso.dropFirst().dropLast()), value > 0
        else { return nil }
        self.init(value: value, unit: unit)
    }

    /// "/week", "/month", "/3 months", "/year".
    public var perLabel: String {
        switch unit {
        case .day: value == 1 ? L10n.tr("/day") : L10n.tr("/\(value) days")
        case .week: value == 1 ? L10n.tr("/week") : L10n.tr("/\(value) weeks")
        case .month: value == 1 ? L10n.tr("/month") : L10n.tr("/\(value) months")
        case .year: value == 1 ? L10n.tr("/year") : L10n.tr("/\(value) years")
        }
    }

    /// "per year", "every 3 months" — for legal disclosure text.
    public var everyLabel: String {
        switch unit {
        case .day: value == 1 ? L10n.tr("per day") : L10n.tr("every \(value) days")
        case .week: value == 1 ? L10n.tr("per week") : L10n.tr("every \(value) weeks")
        case .month: value == 1 ? L10n.tr("per month") : L10n.tr("every \(value) months")
        case .year: value == 1 ? L10n.tr("per year") : L10n.tr("every \(value) years")
        }
    }

    /// Length in months (weeks use 52/12 weeks per month).
    public var months: Decimal {
        switch unit {
        case .day: Decimal(value) / Decimal(30)
        case .week: Decimal(value) * 12 / 52
        case .month: Decimal(value)
        case .year: Decimal(value * 12)
        }
    }

    /// Monthly equivalent shown under longer plans ("≈ €2.50/month"); nil for plans of a month or less.
    public func monthlyEquivalent(of price: Decimal) -> Decimal? {
        guard months > 1 else { return nil }
        var result = price / months
        var rounded = Decimal()
        NSDecimalRound(&rounded, &result, 2, .down)
        return rounded
    }
}

/// "3 days free", "1 week free".
public func freeTrialText(value: Int, unit: PlanPeriod.Unit) -> String {
    switch unit {
    case .day: L10n.tr("\(value) days free")
    case .week: L10n.tr("\(value) weeks free")
    case .month: L10n.tr("\(value) months free")
    case .year: L10n.tr("\(value) years free")
    }
}
