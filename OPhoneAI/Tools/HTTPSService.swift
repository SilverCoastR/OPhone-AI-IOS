import Foundation

actor HTTPSService {
    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func request(arguments: JSONObject) async throws -> JSONObject {
        let rawURL = arguments.string("url"), method = arguments.string("method", default: "GET").uppercased()
        guard let url = URL(string: rawURL), url.scheme == "https", let host = url.host, allowedHost(host), ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE"].contains(method) else { throw NetworkToolError.invalidRequest }
        var request = URLRequest(url: url); request.httpMethod = method; request.timeoutInterval = min(120, max(3, arguments.number("timeout_seconds", default: 30)))
        if let headers = arguments.object("headers") {
            for (name, value) in headers { guard let text = value.stringValue, safeHeader(name) else { continue }; request.setValue(text, forHTTPHeaderField: name) }
        }
        if let body = arguments["body"]?.stringValue { guard body.utf8.count <= 2 * 1_024 * 1_024 else { throw NetworkToolError.tooLarge }; request.httpBody = Data(body.utf8) }
        let (bytes, response) = try await session.bytes(for: request); guard let http = response as? HTTPURLResponse else { throw ModelTransportError.invalidResponse }
        let limit = min(5 * 1_024 * 1_024, max(1_024, Int(arguments.number("max_bytes", default: 1_048_576))))
        var data = Data(); for try await byte in bytes.prefix(limit + 1) { data.append(byte) }; guard data.count <= limit else { throw NetworkToolError.tooLarge }
        let headers = http.allHeaderFields.reduce(into: JSONObject()) { result, pair in
            let name = String(describing: pair.key).lowercased(); if !["set-cookie", "authorization", "proxy-authorization"].contains(name) { result[name] = .string(String(describing: pair.value)) }
        }
        return ["ok": .bool((200..<400).contains(http.statusCode)), "status": .number(Double(http.statusCode)), "url": .string(http.url?.absoluteString ?? rawURL), "headers": .object(headers), "body": .string(String(decoding: data, as: UTF8.self))]
    }

    private func safeHeader(_ name: String) -> Bool { name.range(of: #"^[A-Za-z0-9-]{1,80}$"#, options: .regularExpression) != nil && !["host", "content-length"].contains(name.lowercased()) }
    private func allowedHost(_ host: String) -> Bool {
        let value = host.lowercased(); if value == "localhost" || value.hasSuffix(".local") { return false }
        if let address = IPv4(value) { return !address.isPrivate }
        return true
    }
}

private struct IPv4 {
    let parts: [Int]
    init?(_ value: String) { let parts = value.split(separator: ".").compactMap { Int($0) }; guard parts.count == 4, parts.allSatisfy({ (0...255).contains($0) }) else { return nil }; self.parts = parts }
    var isPrivate: Bool { parts[0] == 10 || parts[0] == 127 || (parts[0] == 169 && parts[1] == 254) || (parts[0] == 172 && (16...31).contains(parts[1])) || (parts[0] == 192 && parts[1] == 168) || parts[0] == 0 }
}

enum NetworkToolError: LocalizedError {
    case invalidRequest, tooLarge
    var errorDescription: String? { switch self { case .invalidRequest: return "Only bounded HTTPS requests to public hosts are allowed."; case .tooLarge: return "The network payload is too large." } }
}
