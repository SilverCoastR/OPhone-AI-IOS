import Foundation

enum ModelRequestBuilder {
    static func openAIMessages(_ messages: [ChatMessage]) -> [[String: Any]] {
        messages.map { message in
            var row: [String: Any] = ["role": message.role == .progress ? "assistant" : message.role.rawValue, "content": message.content]
            if let callID = message.toolCallID { row["tool_call_id"] = callID }
            if !message.toolCalls.isEmpty {
                row["tool_calls"] = message.toolCalls.map { call in
                    ["id": call.id, "type": "function", "function": ["name": call.name, "arguments": jsonString(call.arguments)]]
                }
            }
            if let reasoning = message.reasoning, !reasoning.isEmpty { row["reasoning_content"] = reasoning }
            return row
        }
    }

    static func anthropicMessages(_ messages: [ChatMessage]) -> (system: String, messages: [[String: Any]]) {
        let system = messages.filter { $0.role == .system }.map(\.content).joined(separator: "\n\n")
        var rows: [[String: Any]] = []
        for message in messages where message.role != .system && message.role != .progress {
            let role = message.role == .assistant ? "assistant" : "user"
            var blocks: [[String: Any]] = []
            if message.role == .tool {
                blocks.append(["type": "tool_result", "tool_use_id": message.toolCallID ?? "", "content": message.content])
            } else {
                if !message.content.isEmpty { blocks.append(["type": "text", "text": message.content]) }
                for call in message.toolCalls { blocks.append(["type": "tool_use", "id": call.id, "name": call.name, "input": JSONValue.object(call.arguments).any]) }
            }
            if blocks.isEmpty { continue }
            if var last = rows.last, last["role"] as? String == role {
                var content = last["content"] as? [[String: Any]] ?? []
                content.append(contentsOf: blocks); last["content"] = content; rows[rows.count - 1] = last
            } else { rows.append(["role": role, "content": blocks]) }
        }
        return (system, rows)
    }

    static func jsonString(_ object: JSONObject) -> String {
        guard JSONSerialization.isValidJSONObject(JSONValue.object(object).any), let data = try? JSONSerialization.data(withJSONObject: JSONValue.object(object).any), let value = String(data: data, encoding: .utf8) else { return "{}" }
        return value
    }
}
