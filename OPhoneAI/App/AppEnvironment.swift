import Combine
import Foundation

@MainActor final class AppEnvironment: ObservableObject {
    let settings: AppSettings
    var browser: BrowserStore
    let capabilityPolicy: CapabilityPolicy
    let providerSettings: ProviderSettingsStore
    let memory: MemoryStore
    let audit: AuditStore
    let programs: ProgramStore
    let workspace: WorkspaceService

    @Published var providers = ProviderDescriptor.bundled
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?
    @Published var isRunning = false
    @Published var progress = ""
    @Published var streamingText = ""
    @Published var lastError: String?

    private let files: FileStore
    private let keys: KeychainStore
    private let conversationStore: ConversationStore
    private let taskController: TaskController
    private let agent: DirectModelAgent
    private let telemetry: TelemetryClient
    private var runTask: Task<Void, Never>?

    init() {
        let settings = AppSettings(), browser = BrowserStore(), capabilityPolicy = CapabilityPolicy()
        let files = FileStore(), keys = KeychainStore()
        let conversationStore = ConversationStore(files: files)
        let events = EventBus(files: files)
        let taskController = TaskController(files: files, events: events)
        let memory = MemoryStore(files: files), audit = AuditStore(files: files), programs = ProgramStore(files: files), workspace = WorkspaceService()
        let providerSettings = ProviderSettingsStore(files: files, keychain: keys)
        let kernel = ToolKernel(tasks: taskController, events: events, memory: memory, audit: audit, workspace: workspace, network: HTTPSService(), programs: programs, policy: capabilityPolicy, receipts: ExecutionReceiptStore(files: files), browser: browser, javaScript: JavaScriptSandbox())
        self.settings = settings; self.browser = browser; self.capabilityPolicy = capabilityPolicy
        self.files = files; self.keys = keys; self.conversationStore = conversationStore; self.taskController = taskController
        self.memory = memory; self.audit = audit; self.programs = programs; self.workspace = workspace; self.providerSettings = providerSettings
        self.agent = DirectModelAgent(conversations: conversationStore, tasks: taskController, kernel: kernel, settings: providerSettings)
        self.telemetry = TelemetryClient(keychain: keys)
    }

    func start() async {
        let remoteURL = URL(string: settings.remoteCatalogURL)
        providers = await RemoteProviderCatalog().load(remoteURL: remoteURL)
        do {
            let provider = settings.selectedPlatform?.rawValue ?? "deepseek"
            _ = try await conversationStore.bootstrap(provider: provider)
            try await refreshConversations()
        } catch { lastError = error.localizedDescription }
        if settings.telemetryEnabled { await telemetry.reportLaunch() }
    }

    func refreshConversations() async throws {
        conversations = try await conversationStore.list(); currentConversation = try await conversationStore.active()
    }

    func choosePlatform(_ platform: ControlPlatform) async {
        stop(); settings.selectedPlatform = platform
        if platform.isAPI { _ = try? await conversationStore.bootstrap(provider: platform.rawValue); try? await refreshConversations() }
    }

    func leavePlatform() { stop(); settings.selectedPlatform = nil }

    func newConversation() async { guard let platform = settings.selectedPlatform else { return }; _ = try? await conversationStore.create(provider: platform.rawValue); try? await refreshConversations() }
    func selectConversation(_ id: String) async { try? await conversationStore.select(id); try? await refreshConversations() }
    func deleteConversation(_ id: String) async { let provider = settings.selectedPlatform?.rawValue ?? "api"; _ = try? await conversationStore.delete(id, provider: provider); try? await refreshConversations() }
    func deleteMessage(_ id: UUID) async { guard let conversation = currentConversation else { return }; try? await conversationStore.deleteMessage(id, in: conversation.id); try? await refreshConversations() }

    func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isRunning, let conversation = currentConversation, let platform = settings.selectedPlatform, let provider = providers.first(where: { $0.id == platform.rawValue }) else { return }
        let message = ChatMessage(role: .user, content: text, provider: provider.id)
        isRunning = true; progress = "Starting"; streamingText = ""; lastError = nil
        runTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.conversationStore.append(message, to: conversation.id); try await self.refreshConversations()
                try await self.agent.run(conversationID: conversation.id, userMessage: message, provider: provider) { [weak self] update in
                    Task { @MainActor in self?.apply(update) }
                }
            } catch is CancellationError { }
            catch { self.lastError = error.localizedDescription }
            self.isRunning = false; self.progress = ""; self.streamingText = ""; try? await self.refreshConversations()
        }
    }

    func stop() { runTask?.cancel(); runTask = nil; isRunning = false; progress = "Stopped"; streamingText = "" }

    private func apply(_ update: AgentRunUpdate) {
        switch update {
        case let .status(value): progress = value
        case let .text(part): streamingText += part; progress = "Responding"
        case .thinking: progress = "Thinking"
        case let .tool(name): progress = "Using \(name)"
        case let .finished(status): progress = status.rawValue
        }
    }
}
