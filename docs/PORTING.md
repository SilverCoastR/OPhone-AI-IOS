# Android-to-iOS port map

The iOS code is a native rewrite, not a Java compatibility layer. The table records how the Android architecture maps to iOS and which platform-specific parts were deliberately removed.

| Android area | iOS implementation | Result |
| --- | --- | --- |
| `PlatformActivity`, `PlatformPreference`, `PlatformSession` | `PlatformPickerView`, `AppSettings`, `AppEnvironment` | Rewritten; selection persists and switching stops active work. |
| `ApiChatActivity`, `ApiConversationStore`, chat assets | SwiftUI chat, `ConversationStore`, native Markdown rendering | Rewritten; local conversations, deletion, copy, provider handoff data. |
| `ModelProvider`, `ModelApiStore` | `ProviderDescriptor`, `ProviderSettingsStore`, Keychain | Rewritten; remote catalog is optional and validated. |
| `DeepSeekClient` | `OpenAICompatibleTransport` | Rewritten with SSE text, reasoning, usage and fragmented tool-call assembly. |
| `ClaudeClient` | `AnthropicTransport` | Rewritten with native Messages blocks and SSE events. |
| `DirectModelAgent`, `DirectModelPrompt` | `DirectModelAgent`, `AgentPrompt` | Rewritten for app-scoped iOS tools. |
| `AgentStore`, `TaskController`, `TaskProgress` | `FileStore`, `TaskController`, `AppEnvironment` | Rewritten with protected atomic JSON records. |
| `AgentEvents`, `ExecutionJournal` | `EventBus`, `ExecutionReceiptStore`, `AuditStore` | Rewritten with bounded durable stores and idempotent call results. |
| `LocalToolKernel`, `RiskPolicy` | `ToolKernel`, `CapabilityPolicy` | Rewritten; unsupported Android tools are absent. |
| `BrowserManager`, `BrowserActivity`, WebView runtime | `BrowserStore`, `BrowserTabContainer`, `BrowserView` | Rewritten with multiple tabs, DOM inspection/actions, JS, screenshots, viewport fitting and zoom. |
| `HttpTools` | `HTTPSService` | Rewritten; HTTPS public hosts, redacted headers and strict limits. |
| `Workspace`, `LocalFileProvider` | `WorkspaceService`, iOS Files sharing | Rewritten with traversal protection and file protection. |
| `ProgramWorkspace`, `ProgramRunner`, `ProgramService` | `ProgramStore`, `JavaScriptSandbox` | Rewritten with a nonpersistent WebKit execution context and timeout. |
| `MemoryStore`, `MemoryActivity` | `MemoryStore`, `MemoryView` | Rewritten. |
| `AuditLog`, `AuditActivity`, diagnostics | `AuditStore`, `AuditView`, structured errors/events | Rewritten without access to iOS system logs. |
| `ChatActivity`, `WebGpt` | `WebChatHomeView`, persistent `WebContainer` | Website session retained; Android composer injection is not reused. |
| Android Accessibility, overlay, package operations, intents | No iOS equivalent in this project | Removed by product decision. |
| `RootAccess`, `RootJobScript` | No iOS equivalent in this project | Removed by product decision. |
| `TerminalJobs`, Android shell, bundled Python | No iOS equivalent in this project | Removed by product decision. |
| Android services, boot receiver, exact alarms | Foreground Swift concurrency and ordinary iOS lifecycle | Android background behavior removed; iOS execution follows system lifecycle limits. |
| MediaProjection cross-app recording | No cross-app recorder | Removed with cross-app control. |
| APK updater and package installer | `UpdateChecker` opens an HTTPS release page | Rewritten for iOS distribution rules; the app does not self-install IPA files. |

## Source preservation

The Android working tree is read-only during this port. Its uncommitted current state was treated as the source of truth. No Java files, Android resources, local conversations, API keys, device identifiers, screenshots, build outputs, or private `net` documentation are copied into the iOS repository.
