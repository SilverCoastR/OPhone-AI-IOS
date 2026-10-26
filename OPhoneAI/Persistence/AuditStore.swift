import Foundation

actor AuditStore {
    private let files: FileStore
    private let name = "audit.json"
    init(files: FileStore) { self.files = files }

    func record(taskID: String?, tool: String, success: Bool, detail: String) async {
        do {
            var all = try await list()
            all.insert(AuditEntry(taskID: taskID, tool: tool, success: success, detail: String(detail.prefix(1_000))), at: 0)
            if all.count > 2_000 { all = Array(all.prefix(2_000)) }
            try await files.save(all, to: name)
        } catch { }
    }
    func list() async throws -> [AuditEntry] { try await files.load([AuditEntry].self, from: name, fallback: []) }
    func removeAll() async throws { try await files.remove(name) }
}
