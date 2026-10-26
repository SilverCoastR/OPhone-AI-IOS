import Foundation

final class OpenAICompatibleTransport: ModelTransport, @unchecked Sendable {
    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func listModels(apiKey: String, config: ProviderConfiguration) async throws -> [String] {
        let base = config.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + "/models") else { throw ModelTransportError.invalidURL }
        var request = URLRequest(url: url); request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization"); request.timeoutInterval = 30
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], let values = root["data"] as? [[String: Any]] else { throw ModelTransportError.invalidResponse }
        return values.compactMap { $0["id"] as? String }.sorted()
    }

    func stream(apiKey: String, config: ProviderConfiguration, messages: [ChatMessage], tools: [ToolDefinition], onEvent: @escaping @Sendable (ModelStreamEvent) -> Void) async throws -> ModelResponse {
        guard !config.model.isEmpty else { throw ModelTransportError.missingModel }
        let base = config.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + "/chat/completions") else { throw ModelTransportError.invalidURL }
        var body: [String: Any] = ["model": config.model, "messages": ModelRequestBuilder.openAIMessages(messages), "stream": true, "stream_options": ["include_usage": true]]
        if config.providerID == "deepseek" {
            body["max_tokens"] = config.maxTokens
            body["thinking"] = ["type": config.thinking ? "enabled" : "disabled"]
            if config.thinking { body["reasoning_effort"] = config.reasoningEffort }
        } else {
            body["max_completion_tokens"] = config.maxTokens
            if config.thinking { body["reasoning_effort"] = config.reasoningEffort }
        }
        if let temperature = config.temperature { body["temperature"] = temperature }
        if let topP = config.topP { body["top_p"] = topP }
        if !tools.isEmpty { body["tools"] = tools.map(\.openAIDictionary); if !(config.providerID == "deepseek" && config.thinking) { body["tool_choice"] = "auto" } }

        var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 300
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw ModelTransportError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            var data = Data(); for try await byte in bytes.prefix(131_072) { data.append(byte) }
            throw ModelTransportError.http(http.statusCode, String(decoding: data, as: UTF8.self))
        }

        var text = "", reasoning = "", finish = "", usage: JSONObject = [:]
        var calls: [Int: (id: String, name: String, arguments: String)] = [:]
        var didReportThinking = false
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload.isEmpty || payload == "[DONE]" { continue }
            guard let data = payload.data(using: .utf8), let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let rawUsage = root["usage"] as? [String: Any], let value = try? JSONValue(any: rawUsage).objectValue { usage = value }
            for choice in root["choices"] as? [[String: Any]] ?? [] {
                if let reason = choice["finish_reason"] as? String { finish = reason }
                guard let delta = choice["delta"] as? [String: Any] else { continue }
                if let part = delta["reasoning_content"] as? String, !part.isEmpty { reasoning += part; if !didReportThinking { didReportThinking = true; onEvent(.thinking) } }
                if let part = delta["content"] as? String, !part.isEmpty { text += part; onEvent(.text(part)) }
                for chunk in delta["tool_calls"] as? [[String: Any]] ?? [] {
                    let index = chunk["index"] as? Int ?? 0; var item = calls[index] ?? ("", "", "")
                    if let id = chunk["id"] as? String { item.id += id }
                    if let function = chunk["function"] as? [String: Any] {
                        item.name += function["name"] as? String ?? ""; item.arguments += function["arguments"] as? String ?? ""
                    }
                    calls[index] = item
                }
            }
        }
        let toolCalls = calls.sorted { $0.key < $1.key }.map { _, item -> ToolCall in
            let raw = (try? JSONSerialization.jsonObject(with: Data(item.arguments.utf8))) as? [String: Any] ?? [:]
            return ToolCall(id: item.id.isEmpty ? "call-\(UUID().uuidString)" : item.id, name: item.name, arguments: (try? JSONValue(any: raw).objectValue) ?? [:])
        }
        return ModelResponse(content: text, reasoning: reasoning, toolCalls: toolCalls, finishReason: finish, usage: usage)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw ModelTransportError.invalidResponse }
        if !(200..<300).contains(http.statusCode) { throw ModelTransportError.http(http.statusCode, String(decoding: data.prefix(2_048), as: UTF8.self)) }
    }
}
