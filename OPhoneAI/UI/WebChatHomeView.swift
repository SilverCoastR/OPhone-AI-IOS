import SwiftUI

struct WebChatHomeView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var showSettings = false
    private let url = URL(string: "https://chatgpt.com")!
    var body: some View {
        NavigationStack {
            WebContainer(initialURL: url, persistent: true)
                .navigationTitle("ChatGPT Web").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Platforms") { environment.leavePlatform() } }
                    ToolbarItem(placement: .topBarTrailing) { Button { showSettings = true } label: { Image(systemName: "gearshape") } }
                }
        }.sheet(isPresented: $showSettings) { NavigationStack { SettingsView() } }
    }
}
