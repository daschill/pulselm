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

    private func post<T: Decodable>(path: String) async throws -> T {
        var request = URLRequest(url: endpoint(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
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
