import Foundation

actor ProviderSettingsStore {
    private struct State: Codable { var configurations: [String: ProviderConfiguration] = [:] }
    private let files: FileStore
    private let keychain: KeychainStore
    private let name = "provider-settings.json"

    init(files: FileStore, keychain: KeychainStore) { self.files = files; self.keychain = keychain }

    func configuration(for provider: ProviderDescriptor) async throws -> ProviderConfiguration {
        let state = try await files.load(State.self, from: name, fallback: State())
        if let existing = state.configurations[provider.id] { return existing }
        return ProviderConfiguration(providerID: provider.id, model: provider.models.first ?? "", baseURL: provider.baseURL, thinking: provider.id == "deepseek")
    }

    func save(_ configuration: ProviderConfiguration) async throws {
        guard let url = URL(string: configuration.baseURL), url.scheme == "https", url.host != nil else { throw ModelTransportError.invalidURL }
        guard configuration.model.range(of: #"^[A-Za-z0-9._:/@-]{1,120}$"#, options: .regularExpression) != nil else { throw ModelTransportError.missingModel }
        guard (256...65_536).contains(configuration.maxTokens) else { throw StoreError.invalidValue }
        var state = try await files.load(State.self, from: name, fallback: State())
        state.configurations[configuration.providerID] = configuration
        try await files.save(state, to: name)
    }

    func hasKey(for providerID: String) async -> Bool { (try? await keychain.get("provider.\(providerID)")) != nil }
    func apiKey(for providerID: String) async throws -> String {
        guard let key = try await keychain.get("provider.\(providerID)"), !key.isEmpty else { throw StoreError.notFound }
        return key
    }
    func saveKey(_ value: String, providerID: String) async throws {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (8...4_096).contains(clean.count) else { throw StoreError.invalidValue }
        try await keychain.set(clean, for: "provider.\(providerID)")
    }
    func removeKey(providerID: String) async throws { try await keychain.remove("provider.\(providerID)") }
}
