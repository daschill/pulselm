import Combine
import Foundation

struct HealthResponse: Codable, Equatable, Sendable {
    var ok: Bool
    var service: String?
    var demo: Bool?
    var pulse_gap_s: Double?
    var schema: String?
}

struct ShotsListResponse: Codable, Equatable, Sendable {
    var ok: Bool
    var count: Int?
    var shots: [ShotResult]
}

struct PracticeTiles: Codable, Equatable, Sendable {
    var ball_speed_mph: Double?
    var vla_deg: Double?
    var hla_deg: Double?
    var spin_rpm: Double?
    var club_speed_mph: Double?
    var smash: Double?
    var carry_yd_est: Double?
    var total_yd_est: Double?
    var apex_yd: Double?
    var hang_time_s: Double?
    var land_angle_deg: Double?
    var dist_to_pin_yd: Double?
    var curve_yd: Double?
    var along_yd: Double?
    var offline_yd: Double?
}

struct PracticePayload: Codable, Equatable, Sendable {
    var ok: Bool
    var pin_yd: Double?
    var clubs: [String]?
    var games: [String]?
    var tiles: PracticeTiles?
    var shot_count: Int?
}

struct PlayHoleScore: Codable, Equatable, Sendable {
    var hole: Int
    var par: Int?
    var strokes: Int
    var to_par: Int
}

struct PlayRound: Codable, Equatable, Sendable {
    var ok: Bool
    var playing: Bool
    var course_id: String?
    var course_name: String?
    var city: String?
    var state: String?
    var par: Int?
    var hole: Int?
    var hole_par: Int?
    var pin_yd: Double?
    var remaining_yd: Double?
    var strokes: Int?
    var thru: Int?
    var to_par: Int?
    var scorecard: [PlayHoleScore]?
    var attribution: String?
}

struct CourseSummary: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var name: String?
    var city: String?
    var state: String?
    var par: Int?
    var type: String?
}

struct CourseListPayload: Codable, Equatable, Sendable {
    var ok: Bool?
    var courses: [CourseSummary]
}

struct SessionSummary: Codable, Equatable, Sendable {
    var ok: Bool
    var shot_count: Int
    var ball_speed_mph_mean: Double?
    var ball_speed_mph_sd: Double?
    var ball_speed_mph_max: Double?
    var vla_deg_mean: Double?
    var carry_yd_est_mean: Double?
    var carry_yd_est_max: Double?
}

/// HTTP client for the Pi launch monitor. iPhone is display-only (no camera / BLE / motion).
@MainActor
final class MonitorClient: ObservableObject {
    static let defaultBaseURLString = "http://192.168.0.139:8080"
    private static let baseURLDefaultsKey = "pulselm.baseURL"

    @Published var baseURLString: String {
        didSet { UserDefaults.standard.set(baseURLString, forKey: Self.baseURLDefaultsKey) }
    }
    @Published var latest: ShotResult?
    @Published var shots: [ShotResult] = []
    @Published var health: HealthResponse?
    @Published var sessionSummary: SessionSummary?
    @Published var practice: PracticePayload?
    @Published var selectedClub: String = "Dr"
    @Published var gameMode: String = "practice"
    @Published var play: PlayRound?
    @Published var courseResults: [CourseSummary] = []
    @Published var isBusy = false
    @Published var lastError: String?

    var baseURL: URL {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: trimmed) ?? URL(string: Self.defaultBaseURLString)!
    }

    init(baseURLString: String? = nil, session: URLSession = .shared) {
        if let baseURLString, !baseURLString.isEmpty {
            self.baseURLString = baseURLString
        } else if let stored = UserDefaults.standard.string(forKey: Self.baseURLDefaultsKey),
                  !stored.isEmpty {
            self.baseURLString = stored
        } else {
            self.baseURLString = Self.defaultBaseURLString
        }
        self.session = session
    }

    private let session: URLSession
    private let decoder = JSONDecoder()

    func endpoint(_ path: String) -> URL {
        let base = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let suffix = path.hasPrefix("/") ? path : "/" + path
        return URL(string: base + suffix)!
    }

    func fetchLatest() async throws -> ShotResult {
        let shot: ShotResult = try await get(path: "/shot/latest", allowHTTPErrorBody: true)
        latest = shot
        lastError = nil
        return shot
    }

    func arm() async throws -> ShotResult {
        isBusy = true
        defer { isBusy = false }
        let shot: ShotResult = try await post(path: "/arm")
        latest = shot
        lastError = nil
        return shot
    }

    func fetchHealth() async throws -> HealthResponse {
        let value: HealthResponse = try await get(path: "/api/v1/health")
        health = value
        lastError = nil
        return value
    }

    func fetchShots() async throws -> [ShotResult] {
        let list: ShotsListResponse = try await get(path: "/shots")
        shots = list.shots
        lastError = nil
        return list.shots
    }

    func fetchPlay() async throws -> PlayRound {
        let value: PlayRound = try await get(path: "/api/v1/play")
        play = value
        return value
    }

    func startPlay(courseId: String) async throws -> PlayRound {
        let value: PlayRound = try await post(path: "/api/v1/play/start", json: ["course_id": courseId])
        play = value
        if let pin = value.remaining_yd ?? value.pin_yd {
            _ = try? await fetchPractice(pin: pin)
        }
        return value
    }

    func gimmePlay() async throws -> PlayRound {
        let value: PlayRound = try await post(path: "/api/v1/play/gimme")
        play = value
        return value
    }

    func searchCourses(q: String = "") async throws -> [CourseSummary] {
        let path = q.isEmpty ? "/api/v1/courses" : "/api/v1/courses?q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)"
        let payload: CourseListPayload = try await get(path: path)
        // featured payload nests full courses; map name
        courseResults = payload.courses
        return payload.courses
    }

    func fetchPractice(pin: Double = 250) async throws -> PracticePayload {
        let value: PracticePayload = try await get(path: "/api/v1/practice?pin=\(Int(pin))")
        practice = value
        lastError = nil
        return value
    }

    func fetchSession() async throws -> SessionSummary {
        let value: SessionSummary = try await get(path: "/api/v1/session")
        sessionSummary = value
        lastError = nil
        return value
    }

    func refresh() async {
        do {
            _ = try await fetchHealth()
            _ = try await fetchLatest()
            _ = try? await fetchShots()
            _ = try? await fetchSession()
            _ = try? await fetchPractice()
            _ = try? await fetchPlay()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func get<T: Decodable>(path: String, allowHTTPErrorBody: Bool = false) async throws -> T {
        var request = URLRequest(url: endpoint(path))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await send(request, allowHTTPErrorBody: allowHTTPErrorBody)
    }

    private func post<T: Decodable>(path: String, json: [String: String]? = nil) async throws -> T {
        var request = URLRequest(url: endpoint(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let json {
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return try await send(request, allowHTTPErrorBody: true)
    }

    private func send<T: Decodable>(_ request: URLRequest, allowHTTPErrorBody: Bool) async throws -> T {
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode),
           !allowHTTPErrorBody {
            throw URLError(.badServerResponse)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
}
