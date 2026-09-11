import SwiftUI

@main
struct PulseLMApp: App {
    @StateObject private var client = MonitorClient()
    @StateObject private var settings = PlayerSettings.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if settings.completedOnboarding || ProcessInfo.processInfo.environment["PULSELM_AUTOHIT"] == "1" {
                    AppShell()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(client)
            .environmentObject(settings)
            .preferredColorScheme(.dark)
        }
    }
}
