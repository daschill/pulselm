import Foundation

/// LAN client for the Pi 3 PulseLM service. iPhone is display only — no camera/BLE.
struct MonitorClient {
    var baseURL: URL

    static let defaultBase = URL(string: "http://192.168.0.139:8080")!

    init(baseURL: URL = MonitorClient.defaultBase) {
        self.baseURL = baseURL
    }

    func latest() async throws -> ShotResult {
        try await get("shot/latest")
    }

    func health() async throws -> Data {
        let url = baseURL.appendingPathComponent("api/v1/health")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.throwIfBad(response)
        return data
    }

    func arm() async throws -> ShotResult {
        var req = URLRequest(url: baseURL.appendingPathComponent("arm"))
        req.httpMethod = "POST"
        let (data, response) = try await URLSession.shared.data(for: req)
        try Self.throwIfBad(response)
        return try JSONDecoder().decode(ShotResult.self, from: data)
    }

    func rangeLanding() async throws -> Data {
        let url = baseURL.appendingPathComponent("api/v1/range")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.throwIfBad(response)
        return data
    }

    private func get(_ path: String) async throws -> ShotResult {
        let url = baseURL.appendingPathComponent(path)
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.throwIfBad(response)
        return try JSONDecoder().decode(ShotResult.self, from: data)
    }

    private static func throwIfBad(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
