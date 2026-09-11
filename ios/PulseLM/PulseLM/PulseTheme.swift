import SwiftUI

enum PulseTheme {
    static let lime = Color(red: 0.30, green: 0.98, blue: 0.58)
    static let ink = Color(red: 0.04, green: 0.05, blue: 0.07)
    static let panel = Color.black.opacity(0.52)
    static let panelStrong = Color.black.opacity(0.72)
    static let stroke = Color.white.opacity(0.14)
    static let mute = Color.white.opacity(0.55)
    static let clubs = ["Dr", "3W", "5W", "4i", "5i", "6i", "7i", "8i", "9i", "PW", "GW", "SW", "LW"]
    static let pins: [Double] = [100, 150, 200, 250, 300, 350, 400, 450, 500]
}
