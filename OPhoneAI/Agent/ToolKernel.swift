import Foundation

actor ToolKernel {
    private struct RegisteredTool: @unchecked Sendable {
        var definition: ToolDefinition
        var capability: AppCapability?
        var mutating: Bool
        var handler: @Sendable (JSONObject, ToolContext) async throws -> JSONObject
    }

    private let tasks: TaskController
    private let events: EventBus
    private let memory: MemoryStore
    private let audit: AuditStore
    private let workspace: WorkspaceService
    private let network: HTTPSService
    private let programs: ProgramStore
    private let policy: CapabilityPolicy
    private let receipts: ExecutionReceiptStore
    private let browser: BrowserStore
    private let javaScript: JavaScriptSandbox
    private var tools: [String: RegisteredTool] = [:]
    private var didRegister = false

    init(tasks: TaskController, events: EventBus, memory: MemoryStore, audit: AuditStore, workspace: WorkspaceService, network: HTTPSService, programs: ProgramStore, policy: CapabilityPolicy, receipts: ExecutionReceiptStore, browser: BrowserStore, javaScript: JavaScriptSandbox) {
        self.tasks = tasks; self.events = events; self.memory = memory; self.audit = audit; self.workspace = workspace; self.network = network; self.programs = programs; self.policy = policy; self.receipts = receipts; self.browser = browser; self.javaScript = javaScript
    }

    func definitions() -> [ToolDefinition] { ensureRegistered(); return tools.values.map(\.definition).sorted { $0.name < $1.name } }

    func execute(name: String, arguments: JSONObject, context: ToolContext) async -> JSONObject {
        ensureRegistered()
        guard let tool = tools[name] else { return failure("unknown_tool", "Unknown tool: \(name)") }
        if let existing = await receipts.get(taskID: context.taskID, callID: context.callID) { return existing.result }
        if let capability = tool.capability, !(await policy.enabled(capability)) { return failure("capability_disabled", "\(capability.title) is disabled in Settings.") }
        do {
            let task = try await tasks.task(context.taskID)
            if task.status.isTerminal && tool.mutating && !["task_status"].contains(name) { throw TaskError.alreadyTerminal }
            let result = try await tool.handler(arguments, context)
            await tasks.incrementTool(taskID: context.taskID, mutating: tool.mutating)
            await audit.record(taskID: context.taskID, tool: name, success: result.bool("ok", default: true), detail: "call \(context.callID)")
            await receipts.put(ExecutionReceipt(taskID: context.taskID, callID: context.callID, tool: name, result: result))
            return result
        } catch {
            let result = failure("tool_failed", error.localizedDescription)
            await audit.record(taskID: context.taskID, tool: name, success: false, detail: error.localizedDescription)
            await events.publish(taskID: context.taskID, type: "tool_failed", source: name, level: "error", data: ["message": .string(error.localizedDescription)])
            await receipts.put(ExecutionReceipt(taskID: context.taskID, callID: context.callID, tool: name, result: result))
            return result
        }
    }

    private func register(_ definition: ToolDefinition, capability: AppCapability? = nil, mutating: Bool = false, handler: @escaping @Sendable (JSONObject, ToolContext) async throws -> JSONObject) {
        tools[definition.name] = RegisteredTool(definition: definition, capability: capability, mutating: mutating, handler: handler)
    }

    private func ensureRegistered() { if !didRegister { didRegister = true; registerTools() } }

    private func registerTools() {
        register(def("task_status", "Read the durable task, its recent events, and counters.", object([:]))) { [tasks, events] args, context in
            let task = try await tasks.task(context.taskID), recent = await events.query(taskID: context.taskID, limit: Int(args.number("event_limit", default: 20)))
            return ["ok": .bool(true), "task": try value(task), "events": try value(recent)]
        }
        register(def("task_checkpoint", "Persist progress and the next action so work can resume after interruption.", object(["summary": string(), "next_action": string(), "completed_steps": array(string()), "remaining_steps": array(string()), "blockers": array(string())], required: ["summary", "next_action"])), mutating: true) { [tasks] args, context in
            let checkpoint = TaskCheckpoint(summary: args.string("summary"), nextAction: args.string("next_action"), completedSteps: strings(args.array("completed_steps")), remainingSteps: strings(args.array("remaining_steps")), blockers: strings(args.array("blockers")))
            return ["ok": .bool(true), "task": try value(await tasks.checkpoint(taskID: context.taskID, checkpoint: checkpoint))]
        }
        register(def("task_finish", "Finish only after the requested result has app-scoped evidence.", object(["summary": string(), "evidence": object([:])], required: ["summary", "evidence"])), mutating: true) { [tasks] args, context in
            guard let evidence = args.object("evidence") else { throw TaskError.evidenceRequired }
            return ["ok": .bool(true), "task": try value(await tasks.finish(taskID: context.taskID, summary: args.string("summary"), evidence: evidence))]
        }
        register(def("task_wait_for_user", "Pause and ask the user for information or an iOS confirmation.", object(["question": string()], required: ["question"])), mutating: true) { [tasks] args, context in
            return ["ok": .bool(true), "task": try value(await tasks.waitForUser(taskID: context.taskID, reason: args.string("question")))]
        }
        register(def("event_query", "Read structured runtime events for the current task.", object(["limit": number()]))) { [events] args, context in
            ["ok": .bool(true), "events": try value(await events.query(taskID: context.taskID, limit: Int(args.number("limit", default: 50))))]
        }
        register(def("memory_search", "Search user-visible local AI memory.", object(["query": string(), "limit": number()], required: ["query"])), capability: .memory) { [memory] args, _ in
            ["ok": .bool(true), "entries": try value(await memory.search(args.string("query"), limit: Int(args.number("limit", default: 20))))]
        }
        register(def("memory_save", "Save a preference, fact, playbook, or failure note to local memory.", object(["category": string(), "text": string(), "tags": array(string())], required: ["category", "text"])), capability: .memory, mutating: true) { [memory] args, _ in
            ["ok": .bool(true), "entry": try value(await memory.save(category: args.string("category"), text: args.string("text"), tags: strings(args.array("tags"))))]
        }
        register(def("memory_delete", "Delete a local memory entry by UUID.", object(["id": string()], required: ["id"])), capability: .memory, mutating: true) { [memory] args, _ in
            guard let id = UUID(uuidString: args.string("id")) else { throw StoreError.invalidValue }; try await memory.delete(id); return ["ok": .bool(true)]
        }
        register(def("workspace_list", "List files inside the app's private OPhoneAIWorkspace directory.", object(["path": string(), "recursive": boolean()])), capability: .workspaceRead) { [workspace] args, _ in
            ["ok": .bool(true), "items": .array(try await workspace.list(path: args.string("path"), recursive: args.bool("recursive")).map(JSONValue.object))]
        }
        register(def("workspace_read", "Read one UTF-8 file from the private workspace.", object(["path": string()], required: ["path"])), capability: .workspaceRead) { [workspace] args, _ in
            ["ok": .bool(true), "text": .string(try await workspace.read(path: args.string("path")))]
        }
        register(def("workspace_write", "Write or append UTF-8 text inside the private workspace.", object(["path": string(), "text": string(), "append": boolean()], required: ["path", "text"])), capability: .workspaceWrite, mutating: true) { [workspace] args, _ in
            try await workspace.write(path: args.string("path"), text: args.string("text"), append: args.bool("append"))
        }
        register(def("workspace_delete", "Delete a workspace file or directory.", object(["path": string()], required: ["path"])), capability: .workspaceWrite, mutating: true) { [workspace] args, _ in
            try await workspace.delete(path: args.string("path")); return ["ok": .bool(true)]
        }
        register(def("http_request", "Make a bounded HTTPS request to a public host.", object(["url": string(), "method": string(), "headers": object([:]), "body": string(), "timeout_seconds": number(), "max_bytes": number()], required: ["url"])), capability: .network, mutating: true) { [network] args, _ in try await network.request(arguments: args) }
        register(def("browser_open", "Open an HTTPS page in the built-in browser.", object(["url": string()], required: ["url"])), capability: .browser, mutating: true) { [browser] args, _ in
            guard let url = URL(string: args.string("url")), url.scheme == "https" else { throw ModelTransportError.invalidURL }
            let tab = await browser.open(url); return ["ok": .bool(true), "tab_id": .string(tab.id.uuidString), "url": .string(url.absoluteString)]
        }
        register(def("browser_list", "List pages opened in the built-in browser.", object([:])), capability: .browser) { [browser] _, _ in
            let tabs = await browser.tabs; return ["ok": .bool(true), "tabs": try value(tabs)]
        }
        register(def("browser_inspect", "Read the visible built-in browser page, links, and form controls. The tab must be visible.", object(["tab_id": string()])), capability: .browser) { [browser] args, _ in
            try await browser.inspect(args.string("tab_id").isEmpty ? nil : args.string("tab_id"))
        }
        register(def("browser_click", "Click a control index returned by browser_inspect.", object(["tab_id": string(), "index": number()], required: ["index"])), capability: .browser, mutating: true) { [browser] args, _ in
            try await browser.click(tab: args.string("tab_id").isEmpty ? nil : args.string("tab_id"), index: Int(args.number("index")))
        }
        register(def("browser_fill", "Fill an input index on the visible page and dispatch input/change events.", object(["tab_id": string(), "index": number(), "text": string()], required: ["index", "text"])), capability: .browser, mutating: true) { [browser] args, _ in
            try await browser.fill(tab: args.string("tab_id").isEmpty ? nil : args.string("tab_id"), index: Int(args.number("index")), text: args.string("text"))
        }
        register(def("browser_evaluate", "Evaluate bounded JavaScript in a visible built-in browser tab.", object(["tab_id": string(), "source": string()], required: ["source"])), capability: .browser, mutating: true) { [browser] args, _ in
            ["ok": .bool(true), "result": try await browser.evaluate(tab: args.string("tab_id").isEmpty ? nil : args.string("tab_id"), source: args.string("source"))]
        }
        register(def("browser_screenshot", "Capture a visible browser tab to the private workspace.", object(["tab_id": string(), "path": string()])), capability: .browser, mutating: true) { [browser, workspace] args, _ in
            let data = try await browser.screenshot(tab: args.string("tab_id").isEmpty ? nil : args.string("tab_id")); let path = args.string("path", default: "screenshots/page-\(UUID().uuidString).png"); return try await workspace.writeData(path: path, data: data)
        }
        register(def("browser_close", "Close a built-in browser tab.", object(["tab_id": string()], required: ["tab_id"])), capability: .browser, mutating: true) { [browser] args, _ in
            guard let id = UUID(uuidString: args.string("tab_id")) else { throw StoreError.invalidValue }; await browser.close(id); return ["ok": .bool(true)]
        }
        register(def("program_save", "Save a reusable JavaScript function body. It receives an input variable and must return JSON-compatible output.", object(["name": string(), "summary": string(), "source": string()], required: ["name", "source"])), capability: .javaScript, mutating: true) { [programs] args, _ in
            ["ok": .bool(true), "program": try value(await programs.save(name: args.string("name"), summary: args.string("summary"), source: args.string("source")))]
        }
        register(def("program_list", "List saved JavaScript utilities.", object([:])), capability: .javaScript) { [programs] _, _ in ["ok": .bool(true), "programs": try value(await programs.list())] }
        register(def("program_run", "Run a saved JavaScript utility in an isolated nonpersistent WebKit context.", object(["id": string(), "input": object([:])], required: ["id"])), capability: .javaScript, mutating: true) { [programs, javaScript] args, _ in
            let program = try await programs.program(args.string("id")); let result = try await javaScript.run(source: program.source, input: args["input"] ?? .object([:])); return ["ok": .bool(true), "result": result]
        }
    }
}

private func failure(_ code: String, _ message: String) -> JSONObject { ["ok": .bool(false), "error": .string(code), "message": .string(message)] }
private func value<T: Encodable>(_ value: T) throws -> JSONValue { try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value)) }
private func strings(_ values: [JSONValue]?) -> [String] { (values ?? []).compactMap(\.stringValue) }
private func string() -> JSONValue { .object(["type": .string("string")]) }
private func number() -> JSONValue { .object(["type": .string("number")]) }
private func boolean() -> JSONValue { .object(["type": .string("boolean")]) }
private func array(_ item: JSONValue) -> JSONValue { .object(["type": .string("array"), "items": item]) }
private func object(_ properties: JSONObject, required: [String] = []) -> JSONValue { .object(["type": .string("object"), "properties": .object(properties), "required": .array(required.map(JSONValue.string)), "additionalProperties": .bool(false)]) }
private func def(_ name: String, _ summary: String, _ parameters: JSONValue) -> ToolDefinition { ToolDefinition(name: name, summary: summary, parameters: parameters.objectValue ?? [:]) }
