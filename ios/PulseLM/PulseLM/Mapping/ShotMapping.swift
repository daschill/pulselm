import Foundation

enum ShotMapping {
    static let missing = "—"

    static var usesMetric: Bool {
        UserDefaults.standard.string(forKey: "pulselm.player.units") == UnitSystem.metric.rawValue
    }

    static var speedUnit: String { usesMetric ? "kph" : "mph" }
    static var distUnit: String { usesMetric ? "m" : "yd" }

    /// nil → "—", else converted to the player's unit system.
    static func speedString(_ mph: Double?) -> String {
        guard let mph else { return missing }
        let value = usesMetric ? mph * 1.60934 : mph
        return String(format: "%.1f", value)
    }

    /// nil → "—", else one decimal (shipped HUD).
    static func vlaString(_ vla: Double?) -> String {
        guard let vla else { return missing }
        return String(format: "%.1f", vla)
    }

    static func carryString(_ yards: Double?) -> String {
        guard let yards else { return missing }
        let value = usesMetric ? yards * 0.9144 : yards
        return format(value, decimals: 0)
    }

    static func metricString(_ value: Double?, decimals: Int) -> String {
        format(value, decimals: decimals)
    }

    private static func format(_ value: Double?, decimals: Int) -> String {
        guard let value else { return missing }
        return String(format: "%.\(decimals)f", value)
    }
}
