import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openURL) private var openURL
    @State private var updateStatus = ""

    var body: some View {
        Form {
            Section("Control platform") {
                Picker("Platform", selection: Binding(get: { settings.selectedPlatform ?? .deepSeek }, set: { value in Task { await environment.choosePlatform(value) } })) {
                    ForEach(ControlPlatform.allCases) { Text($0.title).tag($0) }
                }
                Button("Choose on start screen", role: .destructive) { environment.leavePlatform(); dismiss() }
            }
            if let platform = settings.selectedPlatform, platform.isAPI, let provider = environment.providers.first(where: { $0.id == platform.rawValue }) {
                Section("Model API") { NavigationLink("\(provider.name) model and API key") { ProviderSettingsView(provider: provider) } }
            }
            Section("Capabilities") { ForEach(AppCapability.allCases) { CapabilityToggle(capability: $0) } }
            Section("Appearance") {
                Picker("Theme", selection: $settings.colorScheme) { Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark") }
            }
            Section("Privacy") {
                Toggle("Anonymous app-open telemetry", isOn: $settings.telemetryEnabled)
                Text("Reports a random installation ID, Apple device identifier, iOS version, app version, language and region. It does not send conversation text or API keys.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Remote provider catalog") {
                TextField("Optional HTTPS JSON URL", text: $settings.remoteCatalogURL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Text("A remote catalog may change provider names, endpoints and model choices. Protocol adapters remain in the app.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Updates") {
                Button("Check for update") { Task { await checkUpdate() } }
                if !updateStatus.isEmpty { Text(updateStatus).font(.caption) }
            }
            Section("Transparency") {
                NavigationLink("AI memory") { MemoryView() }
                NavigationLink("Audit log") { AuditView() }
            }
            Section("About") { NavigationLink("About OPhone AI") { AboutView() } }
        }.navigationTitle("Settings").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
    private func checkUpdate() async { do { let update = try await UpdateChecker().latest(); updateStatus = "Found \(update.version ?? "an update") via \(update.source)."; openURL(update.url) } catch { updateStatus = error.localizedDescription } }
}

private struct CapabilityToggle: View {
    @EnvironmentObject private var environment: AppEnvironment
    let capability: AppCapability
    @State private var enabled = true
    var body: some View {
        Toggle(capability.title, isOn: $enabled).task { enabled = await environment.capabilityPolicy.enabled(capability) }.onChange(of: enabled) { value in Task { await environment.capabilityPolicy.set(capability, enabled: value) } }
    }
}
