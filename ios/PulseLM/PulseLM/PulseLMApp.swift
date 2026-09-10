import SwiftUI

@main
struct PulseLMApp: App {
    @StateObject private var client = MonitorClient()

    var body: some Scene {
        WindowGroup {
            AppShell()
                .environmentObject(client)
                .preferredColorScheme(.dark)
        }
    }
}
