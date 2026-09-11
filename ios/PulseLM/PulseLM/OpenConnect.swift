import Foundation
import Network

/// GSPro OpenConnect V1. Launch-monitor software connects here as if we were GSPro.
final class OpenConnectServer: ObservableObject {
    static let shared = OpenConnectServer()
    static let defaultPort: UInt16 = 921

    @Published var listening = false
    @Published var status = "Not listening"
    @Published var port: UInt16 = OpenConnectServer.defaultPort
    @Published var wifiAddress = "—"
    @Published var lastDevice = ""
    @Published var connectedClients = 0

    var onShot: ((ShotResult) -> Void)?

    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private let queue = DispatchQueue(label: "app.pulselm.openconnect")

    private init() {
        refreshAddress()
    }

    func start(port: UInt16 = OpenConnectServer.defaultPort) {
        stop()
        self.port = port
        refreshAddress()
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            listener.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.listening = true
                        self?.status = "Listening \(self?.wifiAddress ?? "—"):\(port)"
                    case .failed(let err):
                        self?.listening = false
                        self?.status = "Listen failed: \(err.localizedDescription)"
                    case .cancelled:
                        self?.listening = false
                        self?.status = "Stopped"
                    default:
                        break
                    }
                }
            }
            listener.newConnectionHandler = { [weak self] conn in
                self?.accept(conn)
            }
            listener.start(queue: queue)
            self.listener = listener
            status = "Starting OpenConnect :\(port)…"
        } catch {
            status = "Cannot bind :\(port) — \(error.localizedDescription)"
            listening = false
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        connections.values.forEach { $0.cancel() }
        connections.removeAll()
        DispatchQueue.main.async {
            self.listening = false
            self.connectedClients = 0
            self.status = "Stopped"
        }
    }

    func refreshAddress() {
        wifiAddress = Self.linkLocalIPv4() ?? "—"
    }

    private func accept(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        connections[id] = connection
        DispatchQueue.main.async {
            self.connectedClients = self.connections.count
            self.status = "Monitor connected (\(self.connectedClients))"
        }
        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state { self?.drop(id, connection) }
            if case .cancelled = state { self?.drop(id, connection) }
        }
        connection.start(queue: queue)
        send(OpenConnectParser.playerInfo(), on: connection)
        receive(connection, id: id, buffer: Data())
    }

    private func drop(_ id: ObjectIdentifier, _ connection: NWConnection) {
        connection.cancel()
        connections.removeValue(forKey: id)
        DispatchQueue.main.async {
            self.connectedClients = self.connections.count
            if self.listening {
                self.status = self.connections.isEmpty
                    ? "Listening \(self.wifiAddress):\(self.port)"
                    : "Monitor connected (\(self.connectedClients))"
            }
        }
    }

    private func receive(_ connection: NWConnection, id: ObjectIdentifier, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if error != nil || isComplete {
                self.drop(id, connection)
                return
            }
            var buf = buffer
            if let data { buf.append(data) }
            let (messages, rest) = OpenConnectParser.splitJSON(buf)
            for msg in messages {
                self.handle(msg, on: connection)
            }
            self.receive(connection, id: id, buffer: rest)
        }
    }

    private func handle(_ data: Data, on connection: NWConnection) {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        if OpenConnectParser.isHeartbeat(obj) {
            send(OpenConnectParser.ack("HeartBeat"), on: connection)
            return
        }
        if OpenConnectParser.isReadyOnly(obj) {
            send(OpenConnectParser.playerInfo(), on: connection)
            return
        }
        DispatchQueue.main.async {
            if let device = obj["DeviceID"] as? String, !device.isEmpty {
                self.lastDevice = device
            }
            if let shot = PhoneHub.shared.ingestOpenConnect(obj) {
                self.status = "Shot from \(self.lastDevice.isEmpty ? "monitor" : self.lastDevice)"
                self.onShot?(shot)
                NotificationCenter.default.post(name: .pulselmShotIngested, object: shot)
            }
        }
        send(OpenConnectParser.ack("Shot received successfully"), on: connection)
    }

    private func send(_ dict: [String: Any], on connection: NWConnection) {
        guard let body = try? JSONSerialization.data(withJSONObject: dict, options: []),
              var text = String(data: body, encoding: .utf8) else { return }
        text += "\n"
        connection.send(content: text.data(using: .utf8), completion: .contentProcessed { _ in })
    }

    static func linkLocalIPv4() -> String? {
        var addr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addr) == 0, let first = addr else { return nil }
        defer { freeifaddrs(first) }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let p = ptr {
            defer { ptr = p.pointee.ifa_next }
            guard let sa = p.pointee.ifa_addr, sa.pointee.sa_family == sa_family_t(AF_INET) else { continue }
            let name = String(cString: p.pointee.ifa_name)
            guard name.hasPrefix("en") || name == "bridge100" else { continue }
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(
                sa,
                socklen_t(sa.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            let ip = String(cString: hostname)
            if ip.hasPrefix("127.") { continue }
            return ip
        }
        return nil
    }
}

extension Notification.Name {
    static let pulselmShotIngested = Notification.Name("pulselm.shot.ingested")
}

enum OpenConnectParser {
    static func isHeartbeat(_ obj: [String: Any]) -> Bool {
        if let opts = obj["ShotDataOptions"] as? [String: Any], opts["IsHeartBeat"] as? Bool == true {
            return true
        }
        if let t = obj["Type"] as? String, t == "Heartbeat" || t == "HeartBeat" { return true }
        return false
    }

    static func isReadyOnly(_ obj: [String: Any]) -> Bool {
        let opts = obj["ShotDataOptions"] as? [String: Any] ?? [:]
        let ball = obj["BallData"] as? [String: Any] ?? [:]
        let contains = opts["ContainsBallData"] as? Bool ?? false
        let speed = number(ball["Speed"])
        return !contains && speed == nil && !isHeartbeat(obj)
    }

    static func mappedFields(_ obj: [String: Any]) -> [String: Double?]? {
        if let t = obj["Type"] as? String, t == "SetBallData", let ball = obj["BallData"] as? [String: Any] {
            return e6Ball(ball, club: obj["ClubData"] as? [String: Any])
        }
        if let ball = obj["BallData"] as? [String: Any] {
            if ball["BallSpeed"] != nil || ball["LaunchAngle"] != nil {
                return e6Ball(ball, club: obj["ClubData"] as? [String: Any])
            }
            return openConnectBall(obj)
        }
        return openConnectBall(obj)
    }

    static func ack(_ message: String) -> [String: Any] {
        ["Code": 200, "Message": message]
    }

    static func playerInfo() -> [String: Any] {
        ["Code": 201, "Message": "GSPro Player Information", "Player": ["Handed": "RH", "Club": "DR"]]
    }

    static func splitJSON(_ data: Data) -> ([Data], Data) {
        var out: [Data] = []
        var start: Int?
        var depth = 0
        var inString = false
        var escape = false
        let bytes = [UInt8](data)
        for (i, b) in bytes.enumerated() {
            if inString {
                if escape { escape = false; continue }
                if b == 0x5C { escape = true; continue }
                if b == 0x22 { inString = false }
                continue
            }
            if b == 0x22 { inString = true; continue }
            if b == 0x7B {
                if depth == 0 { start = i }
                depth += 1
            } else if b == 0x7D {
                depth -= 1
                if depth == 0, let s = start {
                    out.append(Data(bytes[s...i]))
                    start = nil
                }
            }
        }
        let rest: Data
        if let s = start {
            rest = Data(bytes[s...])
        } else {
            rest = Data()
        }
        return (out, rest)
    }

    private static func openConnectBall(_ obj: [String: Any]) -> [String: Double?]? {
        let opts = obj["ShotDataOptions"] as? [String: Any] ?? [:]
        let ball = obj["BallData"] as? [String: Any] ?? [:]
        if opts["ContainsBallData"] as? Bool == false, number(ball["Speed"]) == nil {
            return nil
        }
        guard let speed = number(ball["Speed"]) else { return nil }
        let vla = number(ball["VLA"]) ?? number(ball["LaunchAngle"])
        let hla = number(ball["HLA"]) ?? number(ball["LaunchDirection"])
        let spin = number(ball["TotalSpin"]) ?? number(ball["BackSpin"])
        let axis = spinAxis(number(ball["SpinAxis"]))
        var carry = number(ball["CarryDistance"])
        let hasClub = opts["ContainsClubData"] as? Bool == true
        var club = hasClub ? (number(ballClub(obj, "Speed")) ?? number(ballClub(obj, "SpeedAtImpact"))) : nil
        if club == 0 { club = nil }
        let face = hasClub ? (number(ballClub(obj, "FaceToTarget")) ?? number(ballClub(obj, "Face"))) : nil
        let path = hasClub ? number(ballClub(obj, "Path")) : nil
        var total: Double?
        if let vla, carry == nil {
            let est = estimateCarry(speedMph: speed, vla: vla)
            carry = est.0
            total = est.1
        } else if let carry, let vla {
            total = estimateCarry(speedMph: speed, vla: vla).1 ?? carry
        } else {
            total = carry
        }
        return [
            "ball_speed_mph": speed,
            "vla_deg": vla,
            "hla_deg": hla,
            "spin_rpm": spin,
            "spin_axis_deg": axis,
            "club_speed_mph": club,
            "face_deg": face,
            "path_deg": path,
            "carry_yd_est": carry,
            "total_yd_est": total,
        ]
    }

    private static func e6Ball(_ ball: [String: Any], club: [String: Any]?) -> [String: Double?]? {
        let mps = number(ball["BallSpeed"]) ?? number(ball["Speed"])
        guard let mps else { return nil }
        let speed = mps * 2.2369362920544
        let vla = number(ball["LaunchAngle"]) ?? number(ball["VLA"])
        let hla = number(ball["LaunchDirection"]) ?? number(ball["HLA"])
        let spin = number(ball["TotalSpin"])
        let axis = spinAxis(number(ball["SpinAxis"]))
        var clubMph: Double?
        var face: Double?
        var path: Double?
        if let club {
            if let cmps = number(club["ClubHeadSpeed"]) ?? number(club["Speed"]) {
                clubMph = cmps * 2.2369362920544
            }
            face = number(club["ClubAngleFace"]) ?? number(club["FaceToTarget"])
            path = number(club["ClubAnglePath"]) ?? number(club["Path"])
        }
        var carry: Double?
        var total: Double?
        if let vla {
            let est = estimateCarry(speedMph: speed, vla: vla)
            carry = est.0
            total = est.1
        }
        return [
            "ball_speed_mph": speed,
            "vla_deg": vla,
            "hla_deg": hla,
            "spin_rpm": spin,
            "spin_axis_deg": axis,
            "club_speed_mph": clubMph,
            "face_deg": face,
            "path_deg": path,
            "carry_yd_est": carry,
            "total_yd_est": total,
        ]
    }

    private static func ballClub(_ obj: [String: Any], _ key: String) -> Any? {
        (obj["ClubData"] as? [String: Any])?[key]
    }

    private static func number(_ raw: Any?) -> Double? {
        if let d = raw as? Double { return d.isFinite ? d : nil }
        if let i = raw as? Int { return Double(i) }
        if let s = raw as? String { return Double(s) }
        return nil
    }

    private static func spinAxis(_ raw: Double?) -> Double? {
        guard var a = raw else { return nil }
        if a > 180 { a -= 360 }
        if a <= -180 { a += 360 }
        return a
    }

    static func estimateCarry(speedMph: Double, vla: Double) -> (Double?, Double?) {
        let v = speedMph * 0.44704
        let th = vla * .pi / 180
        guard v > 0, th > 0 else { return (nil, nil) }
        let rangeM = (v * v * sin(2 * th)) / 12.5
        let carry = max(0, rangeM * 1.0936)
        return (carry, carry * 1.08)
    }
}

struct LaunchMonitorKind: Identifiable, Hashable {
    var id: String
    var brand: String
    var name: String
    var ble: Bool
    var setup: String

    static let all: [LaunchMonitorKind] = [
        .init(id: "garmin_r10", brand: "Garmin", name: "Approach R10", ble: true,
              setup: "Bluetooth on this iPhone, or in Garmin Golf choose GSPro and set IP to this phone, port 921."),
        .init(id: "garmin_r50", brand: "Garmin", name: "Approach R50", ble: false,
              setup: "In Garmin Golf / R50 sim output choose GSPro / OpenConnect. IP = this phone, port 921."),
        .init(id: "rapsodo_mlm2", brand: "Rapsodo", name: "MLM2PRO", ble: false,
              setup: "MLM2PRO app or GSPro connector → GSPro / OpenAPI. IP = this phone, port 921."),
        .init(id: "foresight_gc", brand: "Foresight", name: "GC3 / GCQuad / GC2", ble: false,
              setup: "FSX Play or FSX 2020 → Connect / OpenAPI. Point GSPro OpenConnect at this phone:921."),
        .init(id: "bushnell_lp", brand: "Bushnell", name: "Launch Pro", ble: false,
              setup: "Same as Foresight. FSX / OpenAPI → this phone IP, port 921."),
        .init(id: "uneekor", brand: "Uneekor", name: "EYE XO / MINI / QED", ble: false,
              setup: "Uneekor View → GSPro. Connector IP = this phone, port 921."),
        .init(id: "skytrak", brand: "SkyTrak", name: "SkyTrak / SkyTrak+", ble: false,
              setup: "OpenSkyPlus or SkyTrak GSPro connector. Server = this phone:921."),
        .init(id: "mevo", brand: "FlightScope", name: "Mevo / Mevo+", ble: false,
              setup: "Mevo app or GSPro Connect (FlightScope). OpenConnect IP = this phone, port 921."),
        .init(id: "square", brand: "Square", name: "Square / Omni", ble: false,
              setup: "Square software → GSPro. IP = this phone, port 921."),
        .init(id: "fullswing", brand: "Full Swing", name: "KIT", ble: false,
              setup: "KIT / GSPro Connect. OpenConnect to this phone:921."),
        .init(id: "trackman", brand: "Trackman", name: "Trackman (sim)", ble: false,
              setup: "If the unit offers GSPro / OpenConnect, set server to this phone IP port 921."),
        .init(id: "protee", brand: "ProTee", name: "VX", ble: false,
              setup: "ProTee connector → GSPro OpenConnect → this phone:921."),
        .init(id: "golfjoy", brand: "GolfJoy", name: "GolfJoy", ble: false,
              setup: "GolfJoy GSPro output. IP = this phone, port 921."),
        .init(id: "other", brand: "Other", name: "Any OpenConnect device", ble: false,
              setup: "In the monitor app pick GSPro / OpenAPI / OpenConnect. Server = this phone’s Wi-Fi IP, port 921."),
    ]
}
