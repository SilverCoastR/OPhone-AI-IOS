import SwiftUI

@main struct OPhoneAIApp: App {
    @StateObject private var environment = AppEnvironment()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
                .environmentObject(environment.settings)
                .preferredColorScheme(environment.settings.preferredColorScheme)
                .task { await environment.start() }
        }
    }
}
