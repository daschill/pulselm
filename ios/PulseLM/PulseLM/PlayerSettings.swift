import Combine
import Foundation

enum UnitSystem: String, CaseIterable, Identifiable {
    case imperial
    case metric
    var id: String { rawValue }
    var label: String { self == .imperial ? "Yards / mph" : "Meters / kph" }
    var speedUnit: String { self == .imperial ? "mph" : "kph" }
    var distUnit: String { self == .imperial ? "yd" : "m" }
}

enum Handedness: String, CaseIterable, Identifiable {
    case right
    case left
    var id: String { rawValue }
    var label: String { self == .right ? "Right-handed" : "Left-handed" }
}

@MainActor
final class PlayerSettings: ObservableObject {
    static let shared = PlayerSettings()

    private enum Key {
        static let name = "pulselm.player.name"
        static let units = "pulselm.player.units"
        static let club = "pulselm.player.club"
        static let pin = "pulselm.player.pin"
        static let hand = "pulselm.player.hand"
        static let onboarded = "pulselm.onboarding.v1"
        static let monitor = "pulselm.player.monitor"
    }

    @Published var playerName: String {
        didSet { UserDefaults.standard.set(playerName, forKey: Key.name) }
    }
    @Published var units: UnitSystem {
        didSet { UserDefaults.standard.set(units.rawValue, forKey: Key.units) }
    }
    @Published var defaultClub: String {
        didSet { UserDefaults.standard.set(defaultClub, forKey: Key.club) }
    }
    @Published var defaultPinYd: Double {
        didSet { UserDefaults.standard.set(defaultPinYd, forKey: Key.pin) }
    }
    @Published var handedness: Handedness {
        didSet { UserDefaults.standard.set(handedness.rawValue, forKey: Key.hand) }
    }
    @Published var completedOnboarding: Bool {
        didSet { UserDefaults.standard.set(completedOnboarding, forKey: Key.onboarded) }
    }
    @Published var monitorId: String {
        didSet { UserDefaults.standard.set(monitorId, forKey: Key.monitor) }
    }

    private init() {
        let d = UserDefaults.standard
        playerName = d.string(forKey: Key.name) ?? ""
        units = UnitSystem(rawValue: d.string(forKey: Key.units) ?? "") ?? .imperial
        defaultClub = d.string(forKey: Key.club) ?? "Dr"
        let pin = d.double(forKey: Key.pin)
        defaultPinYd = pin > 0 ? pin : 250
        handedness = Handedness(rawValue: d.string(forKey: Key.hand) ?? "") ?? .right
        completedOnboarding = d.bool(forKey: Key.onboarded)
        monitorId = d.string(forKey: Key.monitor) ?? "garmin_r10"
    }

    func resetOnboarding() {
        completedOnboarding = false
    }
}
