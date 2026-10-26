import SwiftUI

struct MemoryView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var entries: [MemoryEntry] = []
    var body: some View {
        List {
            if entries.isEmpty { Text("No saved AI memory.").foregroundStyle(.secondary) }
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.category).font(.caption.bold()).foregroundStyle(.secondary)
                    Text(entry.text).textSelection(.enabled)
                    if !entry.tags.isEmpty { Text(entry.tags.joined(separator: " · ")).font(.caption2).foregroundStyle(.tertiary) }
                }.swipeActions { Button("Delete", role: .destructive) { Task { try? await environment.memory.delete(entry.id); await reload() } } }
            }
        }.navigationTitle("AI memory").task { await reload() }
    }
    private func reload() async { entries = (try? await environment.memory.list()) ?? [] }
}
