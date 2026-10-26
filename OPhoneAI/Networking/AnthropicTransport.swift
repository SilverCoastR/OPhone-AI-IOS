import Foundation

final class AnthropicTransport: ModelTransport, @unchecked Sendable {
    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func listModels(apiKey: String, config: ProviderConfiguration) async throws -> [String] {
        let base = config.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + "/models?limit=100") else { throw ModelTransportError.invalidURL }
        var request = URLRequest(url: url); headers(&request, apiKey: apiKey)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ModelTransportError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw ModelTransportError.http(http.statusCode, String(decoding: data.prefix(2_048), as: UTF8.self)) }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], let values = root["data"] as? [[String: Any]] else { throw ModelTransportError.invalidResponse }
        return values.compactMap { $0["id"] as? String }.sorted()
    }

    func stream(apiKey: String, config: ProviderConfiguration, messages: [ChatMessage], tools: [ToolDefinition], onEvent: @escaping @Sendable (ModelStreamEvent) -> Void) async throws -> ModelResponse {
        guard !config.model.isEmpty else { throw ModelTransportError.missingModel }
        let base = config.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + "/messages") else { throw ModelTransportError.invalidURL }
        let converted = ModelRequestBuilder.anthropicMessages(messages)
        var body: [String: Any] = ["model": config.model, "messages": converted.messages, "max_tokens": config.maxTokens, "stream": true]
        if !converted.system.isEmpty { body["system"] = converted.system }
        if let temperature = config.temperature { body["temperature"] = temperature }
        if let topP = config.topP { body["top_p"] = topP }
        if !tools.isEmpty { body["tools"] = tools.map { ["name": $0.name, "description": $0.summary, "input_schema": JSONValue.object($0.parameters).any] } }
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 300; headers(&request, apiKey: apiKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw ModelTransportError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            var data = Data(); for try await byte in bytes.prefix(131_072) { data.append(byte) }
            throw ModelTransportError.http(http.statusCode, String(decoding: data, as: UTF8.self))
        }
        var parser = SSEParser(), text = "", finish = "", usage: JSONObject = [:], didThink = false
        var calls: [Int: (id: String, name: String, arguments: String)] = [:]
        func consume(_ data: String) {
            guard let bytes = data.data(using: .utf8), let root = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { return }
            let type = root["type"] as? String ?? ""
            if type == "content_block_start", let block = root["content_block"] as? [String: Any] {
                let index = root["index"] as? Int ?? 0
                if block["type"] as? String == "tool_use" { calls[index] = (block["id"] as? String ?? "", block["name"] as? String ?? "", "") }
                if block["type"] as? String == "thinking", !didThink { didThink = true; onEvent(.thinking) }
            } else if type == "content_block_delta", let delta = root["delta"] as? [String: Any] {
                let kind = delta["type"] as? String ?? ""; let index = root["index"] as? Int ?? 0
                if kind == "text_delta", let part = delta["text"] as? String { text += part; onEvent(.text(part)) }
                if kind == "input_json_delta" { var call = calls[index] ?? ("", "", ""); call.arguments += delta["partial_json"] as? String ?? ""; calls[index] = call }
                if kind == "thinking_delta", !didThink { didThink = true; onEvent(.thinking) }
            } else if type == "message_delta" {
                if let delta = root["delta"] as? [String: Any] { finish = delta["stop_reason"] as? String ?? finish }
                if let raw = root["usage"] as? [String: Any], let object = try? JSONValue(any: raw).objectValue { usage = object }
            }
        }
        for try await line in bytes.lines { try Task.checkCancellation(); if let event = parser.consume(line: line) { consume(event.data) } }
        if let event = parser.finish() { consume(event.data) }
        let toolCalls = calls.sorted { $0.key < $1.key }.map { _, item -> ToolCall in
            let raw = (try? JSONSerialization.jsonObject(with: Data((item.arguments.isEmpty ? "{}" : item.arguments).utf8))) as? [String: Any] ?? [:]
            return ToolCall(id: item.id, name: item.name, arguments: (try? JSONValue(any: raw).objectValue) ?? [:])
        }
        return ModelResponse(content: text, reasoning: "", toolCalls: toolCalls, finishReason: finish, usage: usage)
    }

    private func headers(_ request: inout URLRequest, apiKey: String) {
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
    }
}
