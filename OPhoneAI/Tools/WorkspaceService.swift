import Foundation

actor WorkspaceService {
    enum WorkspaceError: LocalizedError { case invalidPath, tooLarge, notText; var errorDescription: String? { switch self { case .invalidPath: return "The workspace path is invalid."; case .tooLarge: return "The workspace item exceeds the size limit."; case .notText: return "The file is not UTF-8 text." } } }
    let root: URL

    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("OPhoneAIWorkspace", isDirectory: true)
    }

    func list(path: String = "", recursive: Bool = false) throws -> [JSONObject] {
        let url = try resolve(path); try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        let urls: [URL]
        if recursive { urls = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys)?.allObjects as? [URL] ?? [] }
        else { urls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: keys) }
        return try urls.prefix(500).map { item in
            let values = try item.resourceValues(forKeys: Set(keys)); return [
                "path": .string(relative(item)), "directory": .bool(values.isDirectory ?? false),
                "size": .number(Double(values.fileSize ?? 0)), "modified_at": .number((values.contentModificationDate ?? .distantPast).timeIntervalSince1970)
            ]
        }
    }

    func read(path: String, maxBytes: Int = 1_048_576) throws -> String {
        let data = try Data(contentsOf: resolve(path)); guard data.count <= maxBytes else { throw WorkspaceError.tooLarge }
        guard let text = String(data: data, encoding: .utf8) else { throw WorkspaceError.notText }; return text
    }

    func write(path: String, text: String, append: Bool = false) throws -> JSONObject {
        let data = Data(text.utf8); guard data.count <= 10 * 1_024 * 1_024 else { throw WorkspaceError.tooLarge }
        let url = try resolve(path); try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if append, FileManager.default.fileExists(atPath: url.path) { let handle = try FileHandle(forWritingTo: url); defer { try? handle.close() }; try handle.seekToEnd(); try handle.write(contentsOf: data) }
        else { try data.write(to: url, options: [.atomic, .completeFileProtection]) }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? data.count
        return ["ok": .bool(true), "path": .string(relative(url)), "size": .number(Double(size))]
    }

    func writeData(path: String, data: Data) throws -> JSONObject {
        guard data.count <= 20 * 1_024 * 1_024 else { throw WorkspaceError.tooLarge }
        let url = try resolve(path); try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return ["ok": .bool(true), "path": .string(relative(url)), "size": .number(Double(data.count))]
    }

    func delete(path: String) throws {
        let url = try resolve(path); guard url.standardizedFileURL != root.standardizedFileURL else { throw WorkspaceError.invalidPath }
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    private func resolve(_ path: String) throws -> URL {
        let clean = path.replacingOccurrences(of: "\\", with: "/")
        guard !clean.hasPrefix("/"), !clean.split(separator: "/").contains("..") else { throw WorkspaceError.invalidPath }
        let candidate = root.appendingPathComponent(clean).standardizedFileURL, base = root.standardizedFileURL
        guard candidate.path == base.path || candidate.path.hasPrefix(base.path + "/") else { throw WorkspaceError.invalidPath }
        return candidate
    }
    private func relative(_ url: URL) -> String { String(url.standardizedFileURL.path.dropFirst(root.standardizedFileURL.path.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/")) }
}
