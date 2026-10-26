import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack(spacing: 16) { Image("OPhoneLogo").resizable().frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 16)); VStack(alignment: .leading) { Text("OPhone AI").font(.title2.bold()); Text("iOS \(version)").foregroundStyle(.secondary) } }
            }
            Section("Purpose") { Text("An open-source, app-scoped AI agent runtime for iPhone and iPad. It combines model APIs with durable tasks, a built-in browser, HTTPS, private files, memory, events and transparent audit records.") }
            Section("iOS boundaries") { Text("This edition does not include cross-app accessibility control, root access, arbitrary shell commands, or silent app installation. Those Android-specific capabilities are deliberately absent from the code and UI.") }
            Section("Source") { Link("github.com/SilverCoastR/OPhone-AI-IOS", destination: URL(string: "https://github.com/SilverCoastR/OPhone-AI-IOS")!) }
            Section("License") { Text("Apache License 2.0") }
        }.navigationTitle("About")
    }
    private var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0" }
}
