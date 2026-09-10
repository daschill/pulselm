import Foundation

/// pulselm.shot.v1 — JSON keys are the product contract. Do not rename.
struct ShotResult: Codable, Equatable {
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
}
