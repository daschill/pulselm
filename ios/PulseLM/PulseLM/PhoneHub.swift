import Foundation

/// On-device hub: courses, 18-hole play, shots. No PC required.
@MainActor
final class PhoneHub {
    static let shared = PhoneHub()
    private init() {}

    var shots: [ShotResult] = []
    var play: PlayRound?
    private var holes: [PlayHoleDef] = []
    private var remaining: Double = 0
    private var holeStrokes: Int = 0
    private var scorecard: [PlayHoleScore] = []
    private var shotSerial = 1

    func ingest(_ shot: ShotResult) -> ShotResult {
        shots.append(shot)
        if play?.playing == true {
            apply(shot)
        }
        return shot
    }

    func demoShot() -> ShotResult {
        let carry = 240.0 + Double.random(in: -12...18)
        let vla = 12.0 + Double.random(in: -2...3)
        let speed = 145.0 + Double.random(in: -8...12)
        let shot = ShotResult(
            schema: "pulselm.shot.v1",
            shot_id: String(format: "shot_%05d", shotSerial),
            unix_ts: Date().timeIntervalSince1970,
            ok: true,
            error: nil,
            ball_speed_mph: speed,
            vla_deg: vla,
            hla_deg: Double.random(in: -4...4),
            spin_rpm: 2500,
            spin_axis_deg: Double.random(in: -8...8),
            club_speed_mph: speed / 1.45,
            face_deg: Double.random(in: -3...3),
            path_deg: Double.random(in: -3...3),
            carry_yd_est: carry,
            total_yd_est: carry * 1.08,
            confidence: 0.85,
            ghost_px: nil,
            pulse_gap_s: 0.002
        )
        shotSerial += 1
        return ingest(shot)
    }

    func ingestOpenConnect(_ payload: [String: Any]) -> ShotResult? {
        guard let fields = OpenConnectParser.mappedFields(payload) else { return nil }
        return ingestLaunch(
            ballMph: fields["ball_speed_mph"] ?? nil,
            vla: fields["vla_deg"] ?? nil,
            hla: fields["hla_deg"] ?? nil,
            spin: fields["spin_rpm"] ?? nil,
            axis: fields["spin_axis_deg"] ?? nil,
            clubMph: fields["club_speed_mph"] ?? nil,
            face: fields["face_deg"] ?? nil,
            path: fields["path_deg"] ?? nil,
            carry: fields["carry_yd_est"] ?? nil,
            total: fields["total_yd_est"] ?? nil
        )
    }

    func ingestLaunch(
        ballMph: Double?,
        vla: Double?,
        hla: Double?,
        spin: Double?,
        axis: Double?,
        clubMph: Double?,
        face: Double?,
        path: Double?,
        carry: Double?,
        total: Double?
    ) -> ShotResult? {
        guard let ballMph else { return nil }
        var carryYd = carry
        var totalYd = total
        if carryYd == nil, let vla {
            let est = OpenConnectParser.estimateCarry(speedMph: ballMph, vla: vla)
            carryYd = est.0
            totalYd = est.1
        }
        let shot = ShotResult(
            schema: "pulselm.shot.v1",
            shot_id: String(format: "shot_%05d", shotSerial),
            unix_ts: Date().timeIntervalSince1970,
            ok: true,
            error: nil,
            ball_speed_mph: ballMph,
            vla_deg: vla,
            hla_deg: hla,
            spin_rpm: spin,
            spin_axis_deg: axis,
            club_speed_mph: clubMph,
            face_deg: face,
            path_deg: path,
            carry_yd_est: carryYd,
            total_yd_est: totalYd ?? carryYd.map { $0 * 1.08 },
            confidence: 0.9,
            ghost_px: nil,
            pulse_gap_s: 0.002
        )
        shotSerial += 1
        return ingest(shot)
    }

    func ingestR10(ballMph: Double, vla: Double, hla: Double, spin: Double, axis: Double, clubMph: Double?, face: Double?, path: Double?) -> ShotResult {
        let simCarry: Double = {
            let v = ballMph * 0.44704
            let th = vla * .pi / 180
            guard v > 0, th > 0 else { return 0 }
            let rangeM = (v * v * sin(2 * th)) / 12.5
            return max(0, rangeM * 1.0936)
        }()
        let shot = ShotResult(
            schema: "pulselm.shot.v1",
            shot_id: String(format: "shot_%05d", shotSerial),
            unix_ts: Date().timeIntervalSince1970,
            ok: true,
            error: nil,
            ball_speed_mph: ballMph,
            vla_deg: vla,
            hla_deg: hla,
            spin_rpm: spin,
            spin_axis_deg: axis,
            club_speed_mph: clubMph,
            face_deg: face,
            path_deg: path,
            carry_yd_est: simCarry,
            total_yd_est: simCarry * 1.08,
            confidence: 0.9,
            ghost_px: nil,
            pulse_gap_s: 0.002
        )
        shotSerial += 1
        return ingest(shot)
    }

    func searchCourses(q: String) async throws -> [CourseSummary] {
        let trimmed = q.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return MonitorClient.bundledCourses
        }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        guard let url = URL(string: "https://api.opengolfapi.org/v1/courses/search?q=\(encoded)&limit=20") else {
            return MonitorClient.bundledCourses
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        struct OG: Decodable {
            var courses: [Row]?
            struct Row: Decodable {
                var id: String?
                var name: String?
                var city: String?
                var state: String?
                var type: String?
                var par: Int?
            }
        }
        let og = try JSONDecoder().decode(OG.self, from: data)
        let rows = (og.courses ?? []).compactMap { r -> CourseSummary? in
            guard let id = r.id else { return nil }
            return CourseSummary(id: id, name: r.name, city: r.city, state: r.state, par: r.par, type: r.type)
        }
        return rows.isEmpty ? MonitorClient.bundledCourses : rows
    }

    func startRound(courseId: String) async throws -> PlayRound {
        var holesOut: [PlayHoleDef] = []
        if let url = URL(string: "https://api.opengolfapi.org/v1/courses/\(courseId)") {
            let (data, _) = try await URLSession.shared.data(from: url)
            struct Detail: Decodable {
                var id: String?
                var name: String?
                var city: String?
                var state: String?
                var par: Int?
                var scorecard: [Hole]?
                struct Hole: Decodable {
                    var hole: Int?
                    var number: Int?
                    var par: Int?
                }
            }
            if let d = try? JSONDecoder().decode(Detail.self, from: data) {
                for (i, h) in (d.scorecard ?? []).enumerated() {
                    let n = h.hole ?? h.number ?? (i + 1)
                    let p = h.par ?? 4
                    let pin = p == 3 ? 165 : p == 5 ? 520 : 385
                    holesOut.append(PlayHoleDef(hole: n, par: p, pin_yd: pin + ((n % 5) - 2) * 12))
                }
                if holesOut.count == 9 {
                    holesOut += holesOut.enumerated().map { PlayHoleDef(hole: $1.hole + 9, par: $1.par, pin_yd: $1.pin_yd) }
                }
                playName = d.name
                playCity = d.city
                playState = d.state
                playPar = d.par
            }
        }
        if holesOut.isEmpty {
            holesOut = (1...18).map { n in
                let p = [3, 8, 12].contains(n) ? 3 : n == 16 ? 5 : 4
                return PlayHoleDef(hole: n, par: p, pin_yd: p == 3 ? 160 : p == 5 ? 520 : 380)
            }
        }
        holesOut = Array(holesOut.prefix(18))
        holes = holesOut
        scorecard = []
        holeStrokes = 0
        remaining = Double(holesOut.first?.pin_yd ?? 380)
        self.courseId = courseId
        playName = playName ?? "Course"
        play = makeRound(playing: true)
        return play!
    }

    private var playName: String?
    private var playCity: String?
    private var playState: String?
    private var playPar: Int?
    private var courseId: String = ""

    private func apply(_ shot: ShotResult) {
        guard play?.playing == true, let cur = holes.first(where: { $0.hole == play?.hole }) ?? holes.first else { return }
        let land = RangeLanding.from(shot: shot)
        let along = land.alongYd ?? shot.carry_yd_est ?? 0
        let off = abs(land.offlineYd ?? 0)
        holeStrokes += 1
        let leftover = max(0, remaining - along)
        remaining = (leftover * leftover + (off * 0.35) * (off * 0.35)).squareRoot()
        if remaining <= 3 || holeStrokes >= 8 {
            if remaining <= 3 { holeStrokes += 1 }
            let par = cur.par ?? 4
            scorecard.append(PlayHoleScore(hole: cur.hole, par: par, strokes: holeStrokes, to_par: holeStrokes - par))
            if let idx = holes.firstIndex(where: { $0.hole == cur.hole }), idx + 1 < holes.count {
                let nxt = holes[idx + 1]
                remaining = Double(nxt.pin_yd ?? 380)
                holeStrokes = 0
            } else {
                remaining = 0
                holeStrokes = 0
                play = makeRound(playing: false)
                play?.round_complete = true
                return
            }
        }
        play = makeRound(playing: true)
    }

    private func makeRound(playing: Bool) -> PlayRound {
        let cur = holes.first(where: { $0.hole == (scorecard.last.map { $0.hole + 1 } ?? holes.first?.hole) }) ?? holes.last
        let holeNum: Int
        if let last = scorecard.last, last.hole < (holes.last?.hole ?? 18) {
            holeNum = last.hole + 1
        } else if scorecard.isEmpty {
            holeNum = holes.first?.hole ?? 1
        } else {
            holeNum = holes.last?.hole ?? 18
        }
        let def = holes.first { $0.hole == holeNum } ?? cur
        let toPar = scorecard.reduce(0) { $0 + $1.to_par }
        return PlayRound(
            ok: true,
            playing: playing && scorecard.count < holes.count,
            course_id: courseId.isEmpty ? "phone" : courseId,
            course_name: playName,
            city: playCity,
            state: playState,
            par: playPar,
            hole: def?.hole,
            hole_par: def?.par,
            pin_yd: def.flatMap { $0.pin_yd.map(Double.init) },
            remaining_yd: remaining,
            strokes: holeStrokes,
            thru: scorecard.count,
            to_par: toPar,
            scorecard: scorecard,
            holes: holes,
            attribution: "OpenGolfAPI / OSM ODbL",
            round_complete: !playing || scorecard.count >= holes.count
        )
    }

    func gimme() -> PlayRound {
        holeStrokes += 1
        remaining = 0
        if let cur = holes.first(where: { $0.hole == play?.hole }) {
            let par = cur.par ?? 4
            scorecard.append(PlayHoleScore(hole: cur.hole, par: par, strokes: holeStrokes, to_par: holeStrokes - par))
            if let idx = holes.firstIndex(where: { $0.hole == cur.hole }), idx + 1 < holes.count {
                remaining = Double(holes[idx + 1].pin_yd ?? 380)
                holeStrokes = 0
                play = makeRound(playing: true)
            } else {
                play = makeRound(playing: false)
                play?.round_complete = true
            }
        }
        return play ?? makeRound(playing: false)
    }

    func syntheticMap(hole: Int) -> CourseHoleMap {
        let def = holes.first { $0.hole == hole } ?? holes.first
        let pin = Double(def?.pin_yd ?? 380)
        let par = def?.par ?? 4
        var green: [[Double]] = []
        for i in 0..<16 {
            let a = Double(i) / 16 * 2 * Double.pi
            green.append([12 * cos(a), pin + 8 * sin(a)])
        }
        green.append(green[0])
        var trees: [[Double]] = []
        stride(from: 20.0, through: pin, by: 22).forEach {
            trees.append([-42, $0])
            trees.append([44, $0 + 10])
        }
        let half = par == 3 ? 18.0 : 28.0
        return CourseHoleMap(
            ok: true,
            source: "phone",
            hole: hole,
            par: par,
            fairways: [[[-half * 0.45, 8], [half * 0.45, 8], [half, pin * 0.92], [half * 0.5, pin + 8], [-half * 0.5, pin + 8], [-half, pin * 0.92]]],
            greens: [green],
            bunkers: [
                [[-22, pin - 12], [-8, pin - 18], [-6, pin - 6], [-20, pin - 2]],
                [[14, pin - 8], [26, pin - 14], [28, pin - 2], [16, pin + 2]],
            ],
            water: par == 5 ? [[[-40, pin * 0.4], [-20, pin * 0.45], [-18, pin * 0.55], [-42, pin * 0.5]]] : nil,
            rough: nil,
            trees: trees,
            hole_line: [[0, 0], [0, pin]],
            max_along_yd: pin + 30
        )
    }
}
