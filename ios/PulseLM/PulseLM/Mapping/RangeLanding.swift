import Foundation

/// Landing in yards relative to the target line. Matches range_landing.py.
struct RangeLanding: Equatable, Sendable {
    var alongYd: Double?
    var offlineYd: Double?
    /// True when the ball is treated as on the target line (no HLA, or no carry).
    var onLine: Bool

    /// - If `carry` is nil: along/offline nil, onLine true.
    /// - If `hla` is nil: along = carry, offline = 0, onLine true.
    /// - Else: along = carry * cos(hla rad), offline = carry * sin(hla rad), onLine false.
    /// Positive offline is right of the target line.
    static func from(carry: Double?, hla: Double?) -> RangeLanding {
        guard let carry else {
            return RangeLanding(alongYd: nil, offlineYd: nil, onLine: true)
        }
        guard let hla else {
            return RangeLanding(alongYd: carry, offlineYd: 0, onLine: true)
        }
        let radians = hla * Double.pi / 180.0
        return RangeLanding(
            alongYd: carry * cos(radians),
            offlineYd: carry * sin(radians),
            onLine: false
        )
    }

    static func from(shot: ShotResult) -> RangeLanding {
        from(carry: shot.carry_yd_est, hla: shot.hla_deg)
    }
}
