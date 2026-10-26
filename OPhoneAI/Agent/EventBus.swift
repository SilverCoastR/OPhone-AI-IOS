import Foundation

actor EventBus {
    private let files: FileStore
    private let name = "events.json"
    init(files: FileStore) { self.files = files }

    @discardableResult func publish(taskID: String, type: String, source: String, level: String = "info", data: JSONObject = [:]) async -> AgentEvent {
        var events = (try? await files.load([AgentEvent].self, from: name, fallback: [])) ?? []
        let event = AgentEvent(id: "event-\(UUID().uuidString)", taskID: taskID, type: type, source: source, level: level, data: data)
        events.append(event)
        if events.count > 2_000 { events = Array(events.suffix(2_000)) }
        try? await files.save(events, to: name)
        return event
    }

    func query(taskID: String? = nil, after: Date? = nil, limit: Int = 50) async -> [AgentEvent] {
        let events = (try? await files.load([AgentEvent].self, from: name, fallback: [])) ?? []
        return events.filter { (taskID == nil || $0.taskID == taskID) && (after == nil || $0.createdAt > after!) }
            .suffix(max(1, min(200, limit))).reversed()
    }

    func acknowledge(_ ids: [String]) async {
        guard !ids.isEmpty else { return }
        var events = (try? await files.load([AgentEvent].self, from: name, fallback: [])) ?? []
        let now = Date(), wanted = Set(ids)
        for index in events.indices where wanted.contains(events[index].id) { events[index].acknowledgedAt = now }
        try? await files.save(events, to: name)
    }
}
