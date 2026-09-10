import Foundation

/// ShotResult matching `pulselm.shot.v1`. JSON keys are the field names.
struct ShotResult: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: String { shot_id }

    var schema: String
    var shot_id: String
    var unix_ts: Double
    var ok: Bool
    var error: String?
    var ball_speed_mph: Double?
    var vla_deg: Double?
    var hla_deg: Double?
    var spin_rpm: Double?
    var spin_axis_deg: Double?
    var club_speed_mph: Double?
    var face_deg: Double?
    var path_deg: Double?
    var carry_yd_est: Double?
    var total_yd_est: Double?
    var confidence: Double?
    var ghost_px: Double?
    var pulse_gap_s: Double

    enum CodingKeys: String, CodingKey {
        case schema
        case shot_id
        case unix_ts
        case ok
        case error
        case ball_speed_mph
        case vla_deg
        case hla_deg
        case spin_rpm
        case spin_axis_deg
        case club_speed_mph
        case face_deg
        case path_deg
        case carry_yd_est
        case total_yd_est
        case confidence
        case ghost_px
        case pulse_gap_s
    }

    static let sample = ShotResult(
        schema: "pulselm.shot.v1",
        shot_id: "shot_00001",
        unix_ts: 1_730_000_000.0,
        ok: true,
        error: nil,
        ball_speed_mph: 159.1608,
        vla_deg: 18.4349,
        hla_deg: nil,
        spin_rpm: nil,
        spin_axis_deg: nil,
        club_speed_mph: nil,
        face_deg: nil,
        path_deg: nil,
        carry_yd_est: 265.75,
        total_yd_est: 284.35,
        confidence: 0.94,
        ghost_px: 79.0569,
        pulse_gap_s: 0.002
    )
}
