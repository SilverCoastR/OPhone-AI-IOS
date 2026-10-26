# Architecture

## Application shell

`OPhoneAIApp` owns one `AppEnvironment`. `RootView` opens the saved control platform directly or presents the first-run platform chooser. API providers share local conversations. ChatGPT Web uses its own persistent website session.

## Provider layer

`OpenAICompatibleTransport` implements SSE Chat Completions, including fragmented function-call assembly and DeepSeek reasoning fields. `AnthropicTransport` converts the provider-neutral local history to Messages content blocks and converts streamed `tool_use` blocks back to the common representation. `ProviderSettingsStore` keeps nonsecret settings in protected app files and keys in Keychain.

`RemoteProviderCatalog` may replace display names, HTTPS base URLs, protocol identifiers, and model suggestions. It cannot download Swift code or add a new wire protocol. A new protocol still requires a reviewed native adapter and an app release.

## Durable agent runtime

Every human message creates a deterministic task ID. `TaskController` persists task state, checkpoints, counters, deadlines, evidence summaries, and terminal reasons independently from UI state. `EventBus` stores structured feedback. `ExecutionReceiptStore` makes repeated delivery of the same `(task_id, call_id)` return the original result.

`DirectModelAgent` builds bounded model context, streams visible text, executes tool calls, feeds results back to the provider, and continues until the model finishes with evidence, waits for the user, fails, or is cancelled. Hidden reasoning is never copied between providers or displayed as progress.

## Tool kernel

`ToolKernel` is the only model-to-native dispatch path. For every call it:

1. Resolves the declared tool and capability.
2. Verifies task state and capability policy.
3. Returns a previous receipt for duplicate call IDs.
4. Executes a typed handler.
5. Updates task counters and stores audit and event evidence.
6. Persists the result as an execution receipt.

The iOS tool surface contains task state, events, memory, workspace files, public-host HTTPS, built-in browser operations, screenshots, and isolated JavaScript programs. It does not contain Accessibility automation, root, or shell entry points.

## Browser

The built-in browser uses a nonpersistent `WKWebsiteDataStore`, multi-tab state, and a viewport user script that preserves normal mobile layout and pinch zoom. Visible tabs register their `WKWebView` with `BrowserStore`, allowing structured page inspection, bounded DOM actions, JavaScript evaluation, and screenshots. ChatGPT Web uses a separate persistent WebKit data store.

## Persistence and privacy

JSON stores use atomic writes with complete file protection under Application Support. User workspace files live in `Documents/OPhoneAIWorkspace` so they can be exported with Files. Path normalization blocks traversal. Keys use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` and do not enter conversation or telemetry data.
