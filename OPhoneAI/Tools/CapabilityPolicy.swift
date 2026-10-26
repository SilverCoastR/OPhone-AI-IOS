import Foundation

enum AppCapability: String, CaseIterable, Identifiable, Sendable {
    case browser, network, workspaceRead, workspaceWrite, javaScript, memory
    var id: String { rawValue }
    var title: String {
        switch self { case .browser: return "Built-in browser"; case .network: return "HTTPS requests"; case .workspaceRead: return "Read workspace"; case .workspaceWrite: return "Write workspace"; case .javaScript: return "Restricted JavaScript"; case .memory: return "AI memory" }
    }
}

actor CapabilityPolicy {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func enabled(_ capability: AppCapability) -> Bool {
        let key = "capability.\(capability.rawValue)"; return defaults.object(forKey: key) == nil ? true : defaults.bool(forKey: key)
    }
    func set(_ capability: AppCapability, enabled: Bool) { defaults.set(enabled, forKey: "capability.\(capability.rawValue)") }
}
