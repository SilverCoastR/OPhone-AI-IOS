# Remote provider catalog

The optional catalog is a UTF-8 JSON array. Each entry has the following shape:

```json
[
  {
    "id": "deepseek",
    "name": "DeepSeek",
    "company": "DeepSeek",
    "protocolKind": "openai_chat",
    "baseURL": "https://api.deepseek.com",
    "models": ["deepseek-chat", "deepseek-reasoner"],
    "editableBaseURL": false,
    "supportsThinking": true
  }
]
```

Validation requires a short lowercase provider ID, an HTTPS URL with a host, a known `protocolKind`, and safe model identifiers. Failure, an empty list, invalid data, responses over 512 KiB, and non-HTTPS addresses all fall back to the bundled catalog.

Supported native protocols are:

- `openai_chat`: OpenAI-compatible Chat Completions and SSE function calls.
- `anthropic_messages`: Anthropic Messages, content blocks, `tool_use`, and `tool_result`.

Adding a server entry can expose another provider only when it uses an existing compatible protocol. Wire-protocol differences, authentication differences, Responses API semantics, Realtime, or provider-specific tools require a native application update.
