import Foundation

/// JSON → HUD strings. Matches Python shot_ui.py (shipped mapping).
enum ShotMapping {
    static let missing = "—"

    /// 159.1608 → "159.16"; null → "—"
    static func speedString(_ ball_speed_mph: Double?) -> String {
        guard let ball_speed_mph else { return missing }
        return String(format: "%.2f", ball_speed_mph)
    }

    static func vlaString(_ vla_deg: Double?) -> String {
        guard let vla_deg else { return missing }
        return String(format: "%.1f", vla_deg)
    }

    static func carryString(_ carry_yd_est: Double?) -> String {
        guard let carry_yd_est else { return missing }
        return String(format: "%.0f", carry_yd_est)
    }

    static func optionalMetric(_ value: Double?) -> String {
        guard let value else { return missing }
        return String(format: "%.1f", value)
    }
}
