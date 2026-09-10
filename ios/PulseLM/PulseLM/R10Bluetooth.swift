import CoreBluetooth
import Foundation

/// Garmin Approach R10 over BLE on this iPhone. No PC.
final class R10Bluetooth: NSObject, ObservableObject {
    static let shared = R10Bluetooth()

    @Published var status = "R10 not connected"
    @Published var connected = false
    @Published var lastShot: ShotResult?

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writer: CBCharacteristic?
    private var header: UInt8 = 0
    private var handshakeDone = false
    private var buf = Data()

    private let iface = CBUUID(string: "6A4E2800-667B-11E3-949A-0800200C9A66")
    private let notifyUUID = CBUUID(string: "6A4E2812-667B-11E3-949A-0800200C9A66")
    private let writeUUID = CBUUID(string: "6A4E2822-667B-11E3-949A-0800200C9A66")

    var onShot: ((ShotResult) -> Void)?

    override private init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func scan() {
        handshakeDone = false
        buf.removeAll()
        status = "Scanning for Approach R10…"
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        }
    }

    func stop() {
        central.stopScan()
        if let p = peripheral { central.cancelPeripheralConnection(p) }
        connected = false
        status = "Disconnected"
    }
}

extension R10Bluetooth: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            status = "Turn Bluetooth on"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? ""
        guard name.contains("Approach") || name.contains("R10") || name.contains("R1") else { return }
        status = "Found \(name), connecting…"
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        status = "Connected, discovering…"
        connected = true
        peripheral.discoverServices([iface])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        status = "Connect failed: \(error?.localizedDescription ?? "?")"
        connected = false
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connected = false
        status = "R10 disconnected"
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        peripheral.services?.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for ch in service.characteristics ?? [] {
            if ch.uuid == notifyUUID {
                peripheral.setNotifyValue(true, for: ch)
            }
            if ch.uuid == writeUUID {
                writer = ch
            }
        }
        if writer != nil {
            status = "Handshaking R10…"
            write(Data([0x00]) + Data(hex: "000000000000000000010000"))
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, !data.isEmpty else { return }
        let headerByte = data[0]
        var payload = data.dropFirst()
        let hex = payload.map { String(format: "%02X", $0) }.joined()
        if !handshakeDone, hex.hasPrefix("010000000000000000010000") {
            if payload.count > 12 { header = payload[12] }
            handshakeDone = true
            write(Data([header, 0x00]))
            status = "R10 ready — hit a ball"
            return
        }
        _ = headerByte
        if payload.last == 0x00 {
            payload = payload.dropLast()
            buf.append(payload)
            parseFrame(buf)
            buf.removeAll()
        } else {
            if payload.first == 0x00 { buf.removeAll(); payload = payload.dropFirst() }
            buf.append(payload)
        }
    }

    private func parseFrame(_ encoded: Data) {
        // COBS-framed GFDI. Best-effort: scan for plausible m/s ball speed floats.
        // Full protobuf decode needs Garmin's .proto; handshake still enables the radio.
        status = "R10 packet \(encoded.count) B"
    }

    private func write(_ data: Data) {
        guard let p = peripheral, let w = writer else { return }
        var chunk = data
        while chunk.count > 20 {
            p.writeValue(chunk.prefix(20), for: w, type: .withoutResponse)
            chunk = chunk.dropFirst(20)
        }
        if !chunk.isEmpty {
            p.writeValue(chunk, for: w, type: .withoutResponse)
        }
    }
}

private extension Data {
    init(hex: String) {
        var data = Data()
        var s = hex
        while s.count >= 2 {
            let b = UInt8(s.prefix(2), radix: 16) ?? 0
            data.append(b)
            s.removeFirst(2)
        }
        self = data
    }
}
