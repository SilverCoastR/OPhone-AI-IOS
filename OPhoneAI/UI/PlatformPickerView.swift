import SwiftUI

struct PlatformPickerView: View {
    @EnvironmentObject private var environment: AppEnvironment
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image("OPhoneLogo").resizable().scaledToFit().frame(width: 92, height: 92).clipShape(RoundedRectangle(cornerRadius: 22))
                    Text("OPhone AI").font(.largeTitle.bold())
                    Text("Choose the control platform. Your choice is saved and can be changed later in Settings.").foregroundStyle(.secondary)
                    ForEach(ControlPlatform.allCases) { platform in
                        Button { Task { await environment.choosePlatform(platform) } } label: {
                            HStack(spacing: 14) {
                                Image(systemName: icon(platform)).font(.title2).frame(width: 34)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(platform.title).font(.headline)
                                    Text(detail(platform)).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            }.padding(16).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain)
                    }
                    Text("API keys stay in this device's Keychain. API conversations remain available when you switch API providers. ChatGPT Web keeps its own website history.").font(.footnote).foregroundStyle(.secondary)
                }.padding()
            }.navigationTitle("Control platform")
        }
    }
    private func icon(_ platform: ControlPlatform) -> String { platform == .chatGPTWeb ? "globe" : platform == .claude ? "text.bubble" : "cpu" }
    private func detail(_ platform: ControlPlatform) -> String {
        switch platform { case .chatGPTWeb: return "Authenticated website in a private app view"; case .deepSeek: return "DeepSeek API with streaming and tools"; case .openAI: return "OpenAI or compatible Chat Completions API"; case .claude: return "Anthropic Messages API" }
    }
}
