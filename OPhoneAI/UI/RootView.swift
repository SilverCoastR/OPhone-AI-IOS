import SwiftUI

struct RootView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Group {
            if let platform = settings.selectedPlatform {
                if platform == .chatGPTWeb { WebChatHomeView() } else { APIChatHomeView() }
            } else { PlatformPickerView() }
        }
        .sheet(isPresented: $environment.browser.isPresented) { NavigationStack { BrowserView().environmentObject(environment.browser) } }
        .alert("OPhone AI", isPresented: Binding(get: { environment.lastError != nil }, set: { if !$0 { environment.lastError = nil } })) {
            Button("OK") { environment.lastError = nil }
        } message: { Text(environment.lastError ?? "") }
    }
}
