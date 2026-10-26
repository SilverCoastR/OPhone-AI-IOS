import Foundation

actor MemoryStore {
    private let files: FileStore
    private let name = "memory.json"
    init(files: FileStore) { self.files = files }

    func list() async throws -> [MemoryEntry] { try await files.load([MemoryEntry].self, from: name, fallback: []).sorted { $0.updatedAt > $1.updatedAt } }
    func search(_ query: String, limit: Int = 20) async throws -> [MemoryEntry] {
        let terms = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        return try await list().filter { entry in
            let haystack = ([entry.category, entry.text] + entry.tags).joined(separator: " ").lowercased()
            return terms.isEmpty || terms.allSatisfy(haystack.contains)
        }.prefix(max(1, min(50, limit))).map { $0 }
    }
    @discardableResult func save(category: String, text: String, tags: [String]) async throws -> MemoryEntry {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines); guard !clean.isEmpty, clean.count <= 4_000 else { throw StoreError.invalidValue }
        var all = try await list(); let normalizedTags = Array(Set(tags.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
        if let index = all.firstIndex(where: { $0.category == category && $0.text.caseInsensitiveCompare(clean) == .orderedSame }) {
            all[index].tags = normalizedTags; all[index].updatedAt = Date(); try await files.save(all, to: name); return all[index]
        }
        let entry = MemoryEntry(category: category, text: clean, tags: normalizedTags); all.append(entry)
        if all.count > 1_000 { all.sort { $0.updatedAt > $1.updatedAt }; all = Array(all.prefix(1_000)) }
        try await files.save(all, to: name); return entry
    }
    func delete(_ id: UUID) async throws { var all = try await list(); all.removeAll { $0.id == id }; try await files.save(all, to: name) }
    func removeAll() async throws { try await files.remove(name) }
}
