import Foundation

struct AppUpdate: Codable, Equatable, Sendable {
    var version: String?
    var url: URL
    var source: String
}

actor UpdateChecker {
    private let session: URLSession
    private let configured = URL(string: "https://ophone-telemetry-api.ooorrrt66.workers.dev/v1/app-update")!
    init(session: URLSession = .shared) { self.session = session }

    func latest() async throws -> AppUpdate {
        if let update = try? await configuredUpdate() { return update }
        let url = URL(string: "https://api.github.com/repos/SilverCoastR/OPhone-AI-IOS/releases/latest")!
        var request = URLRequest(url: url); request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept"); request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], let page = root["html_url"] as? String, let pageURL = URL(string: page) else { throw ModelTransportError.invalidResponse }
        return AppUpdate(version: root["tag_name"] as? String, url: pageURL, source: "github")
    }

    private func configuredUpdate() async throws -> AppUpdate {
        let (data, response) = try await session.data(from: configured)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ModelTransportError.invalidResponse }
        let raw = (root["url"] ?? root["download_url"] ?? root["update_url"]) as? String
        guard let raw, let url = URL(string: raw), url.scheme == "https" else { throw ModelTransportError.invalidURL }
        return AppUpdate(version: root["version"] as? String, url: url, source: "configured")
    }
}
