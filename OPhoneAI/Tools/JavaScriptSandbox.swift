import Foundation
import WebKit

@MainActor final class JavaScriptSandbox {
    enum SandboxError: LocalizedError { case sourceTooLarge, timedOut, invalidResult; var errorDescription: String? { switch self { case .sourceTooLarge: return "The JavaScript program is too large."; case .timedOut: return "The JavaScript program exceeded its time limit."; case .invalidResult: return "The JavaScript result is not JSON-compatible." } } }

    func run(source: String, input: JSONValue, timeoutSeconds: Double = 5) async throws -> JSONValue {
        guard source.utf8.count <= 64 * 1_024 else { throw SandboxError.sourceTooLarge }
        let configuration = WKWebViewConfiguration(); configuration.websiteDataStore = .nonPersistent(); configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        return try await withThrowingTaskGroup(of: JSONValue.self) { group in
            group.addTask { @MainActor in
                let script = "return await (async function(input) { \(source) })(input);"
                let result = try await webView.callAsyncJavaScript(script, arguments: ["input": input.any], in: nil, contentWorld: .page)
                guard let result else { return .null }
                return try JSONValue(any: result)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(max(0.1, timeoutSeconds) * 1_000_000_000))
                throw SandboxError.timedOut
            }
            guard let result = try await group.next() else { throw SandboxError.invalidResult }
            group.cancelAll(); return result
        }
    }
}
