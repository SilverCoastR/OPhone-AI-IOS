import Foundation

actor RemoteProviderCatalog {
    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func load(remoteURL: URL?) async -> [ProviderDescriptor] {
        guard let remoteURL, remoteURL.scheme == "https" else { return ProviderDescriptor.bundled }
        do {
            var request = URLRequest(url: remoteURL); request.timeoutInterval = 12; request.cachePolicy = .reloadRevalidatingCacheData
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), data.count <= 512 * 1_024 else { return ProviderDescriptor.bundled }
            let decoded = try JSONDecoder().decode([ProviderDescriptor].self, from: data)
            let valid = decoded.filter { descriptor in
                guard descriptor.id.range(of: #"^[a-z0-9_-]{1,40}$"#, options: .regularExpression) != nil,
                      let url = URL(string: descriptor.baseURL), url.scheme == "https", url.host != nil else { return false }
                return descriptor.models.allSatisfy { $0.range(of: #"^[A-Za-z0-9._:/@-]{1,120}$"#, options: .regularExpression) != nil }
            }
            return valid.isEmpty ? ProviderDescriptor.bundled : valid
        } catch { return ProviderDescriptor.bundled }
    }
}
