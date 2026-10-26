import Foundation

struct SavedProgram: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var name: String
    var summary: String
    var source: String
    var createdAt = Date()
    var updatedAt = Date()
}

actor ProgramStore {
    private let files: FileStore
    private let name = "programs.json"
    init(files: FileStore) { self.files = files }
    func list() async throws -> [SavedProgram] { try await files.load([SavedProgram].self, from: name, fallback: []).sorted { $0.updatedAt > $1.updatedAt } }
    @discardableResult func save(name programName: String, summary: String, source: String) async throws -> SavedProgram {
        let id = programName.lowercased().replacingOccurrences(of: #"[^a-z0-9_-]+"#, with: "-", options: .regularExpression).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        guard !id.isEmpty, id.count <= 64, source.utf8.count <= 64 * 1_024 else { throw StoreError.invalidValue }
        var all = try await list(); let now = Date()
        let program = SavedProgram(id: id, name: String(programName.prefix(80)), summary: String(summary.prefix(500)), source: source, createdAt: all.first(where: { $0.id == id })?.createdAt ?? now, updatedAt: now)
        all.removeAll { $0.id == id }; all.append(program); try await files.save(all, to: name); return program
    }
    func program(_ id: String) async throws -> SavedProgram { guard let value = try await list().first(where: { $0.id == id }) else { throw StoreError.notFound }; return value }
    func delete(_ id: String) async throws { var all = try await list(); all.removeAll { $0.id == id }; try await files.save(all, to: name) }
}
