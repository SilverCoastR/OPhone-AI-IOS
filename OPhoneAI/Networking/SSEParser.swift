import Foundation

struct SSEParser: Sendable {
    private(set) var event: String?
    private(set) var data: [String] = []

    mutating func consume(line: String) -> (event: String?, data: String)? {
        if line.isEmpty {
            guard !data.isEmpty else { event = nil; return nil }
            defer { event = nil; data.removeAll(keepingCapacity: true) }
            return (event, data.joined(separator: "\n"))
        }
        if line.hasPrefix(":") { return nil }
        let pair = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let field = String(pair[0])
        var value = pair.count > 1 ? String(pair[1]) : ""
        if value.hasPrefix(" ") { value.removeFirst() }
        if field == "event" { event = value }
        if field == "data" { data.append(value) }
        return nil
    }

    mutating func finish() -> (event: String?, data: String)? { consume(line: "") }
}
