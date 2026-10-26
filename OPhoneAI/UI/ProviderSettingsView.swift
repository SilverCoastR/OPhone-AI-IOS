import SwiftUI

struct ProviderSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    let provider: ProviderDescriptor
    @State private var configuration: ProviderConfiguration
    @State private var key = ""
    @State private var models: [String] = []
    @State private var status = ""
    @State private var busy = false

    init(provider: ProviderDescriptor) {
        self.provider = provider
        _configuration = State(initialValue: ProviderConfiguration(providerID: provider.id, model: provider.models.first ?? "", baseURL: provider.baseURL, thinking: provider.id == "deepseek"))
    }
    var body: some View {
        Form {
            Section("Credentials") {
                SecureField("API key (leave blank to keep saved key)", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled()
                Text("The key is stored in iOS Keychain and never written to conversation files.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Endpoint") {
                TextField("HTTPS base URL", text: $configuration.baseURL).disabled(!provider.editableBaseURL).textInputAutocapitalization(.never).autocorrectionDisabled()
                if models.isEmpty { TextField("Model ID", text: $configuration.model).textInputAutocapitalization(.never).autocorrectionDisabled() }
                else { Picker("Model", selection: $configuration.model) { ForEach(models, id: \.self) { Text($0).tag($0) } } }
                Stepper("Maximum output: \(configuration.maxTokens)", value: $configuration.maxTokens, in: 256...65_536, step: 256)
            }
            if provider.supportsThinking {
                Section("Reasoning") {
                    Toggle("Enable reasoning", isOn: $configuration.thinking)
                    Picker("Effort", selection: $configuration.reasoningEffort) { ForEach(["low", "medium", "high", "max"], id: \.self) { Text($0.capitalized).tag($0) } }
                }
            }
            Section("Advanced") {
                OptionalNumberField(title: "Temperature", value: $configuration.temperature)
                OptionalNumberField(title: "Top P", value: $configuration.topP)
                TextEditor(text: $configuration.customInstructions).frame(minHeight: 90).overlay(alignment: .topLeading) { if configuration.customInstructions.isEmpty { Text("Custom instructions").foregroundStyle(.tertiary).padding(8).allowsHitTesting(false) } }
            }
            Section {
                Button("Save and test") { Task { await saveAndTest() } }.disabled(busy)
                if busy { ProgressView() }
                if !status.isEmpty { Text(status).font(.caption).textSelection(.enabled) }
            }
        }.navigationTitle(provider.name).task { await load() }
    }
    private func load() async { if let saved = try? await environment.providerSettings.configuration(for: provider) { configuration = saved }; models = provider.models }
    private func saveAndTest() async {
        busy = true; defer { busy = false }
        do {
            if !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { try await environment.providerSettings.saveKey(key, providerID: provider.id); key = "" }
            try await environment.providerSettings.save(configuration)
            let apiKey = try await environment.providerSettings.apiKey(for: provider.id)
            let transport: any ModelTransport = provider.protocolKind == .anthropicMessages ? AnthropicTransport() : OpenAICompatibleTransport()
            let available = try await transport.listModels(apiKey: apiKey, config: configuration)
            models = available; if configuration.model.isEmpty, let first = available.first { configuration.model = first; try await environment.providerSettings.save(configuration) }
            status = "Connected. \(available.count) models are available."
        } catch { status = error.localizedDescription }
    }
}

private struct OptionalNumberField: View {
    let title: String
    @Binding var value: Double?
    var body: some View { TextField(title, text: Binding(get: { value.map { String($0) } ?? "" }, set: { value = Double($0) })).keyboardType(.decimalPad) }
}
