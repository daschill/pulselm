import Foundation

/// Driving-range landing from ShotResult. Matches Python range_landing.py.
struct RangeLanding: Equatable {
    var along_yd: Double?
    var offline_yd: Double?
    var on_line: Bool
    var hla_deg: Double?
    var carry_yd_est: Double?
    var shot_id: String?

    static func from(carry_yd_est: Double?, hla_deg: Double?) -> RangeLanding {
        guard let carry = carry_yd_est else {
            return RangeLanding(
                along_yd: nil,
                offline_yd: nil,
                on_line: true,
                hla_deg: hla_deg,
                carry_yd_est: nil,
                shot_id: nil
            )
        }
        guard let hla = hla_deg else {
            return RangeLanding(
                along_yd: carry,
                offline_yd: 0,
                on_line: true,
                hla_deg: nil,
                carry_yd_est: carry,
                shot_id: nil
            )
        }
        let rad = hla * Double.pi / 180
        return RangeLanding(
            along_yd: carry * cos(rad),
            offline_yd: carry * sin(rad),
            on_line: false,
            hla_deg: hla,
            carry_yd_est: carry,
            shot_id: nil
        )
    }

    static func from(shot: ShotResult) -> RangeLanding {
        var land = from(carry_yd_est: shot.carry_yd_est, hla_deg: shot.hla_deg)
        land.shot_id = shot.shot_id
        return land
    }
}
