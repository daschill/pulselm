import Foundation

enum ShotMapping {
    static let missing = "—"

    /// nil → "—", else two decimal places (159.1608 → "159.16").
    static func speedString(_ mph: Double?) -> String {
        format(mph, decimals: 2)
    }

    /// nil → "—", else one decimal (shipped HUD).
    static func vlaString(_ vla: Double?) -> String {
        format(vla, decimals: 1)
    }

    static func carryString(_ yards: Double?) -> String {
        format(yards, decimals: 0)
    }

    static func metricString(_ value: Double?, decimals: Int) -> String {
        format(value, decimals: decimals)
    }

    private static func format(_ value: Double?, decimals: Int) -> String {
        guard let value else { return missing }
        return String(format: "%.\(decimals)f", value)
    }
}
