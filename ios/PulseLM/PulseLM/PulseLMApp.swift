import SwiftUI

@main
struct PulseLMApp: App {
    @StateObject private var client = MonitorClient()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(client)
                .preferredColorScheme(.dark)
        }
    }
}
