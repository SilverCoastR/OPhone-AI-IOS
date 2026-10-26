import SwiftUI

struct AuditView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var entries: [AuditEntry] = []
    var body: some View {
        List(entries) { entry in
            VStack(alignment: .leading, spacing: 4) {
                HStack { Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.octagon.fill").foregroundStyle(entry.success ? .green : .red); Text(entry.tool).font(.headline); Spacer(); Text(entry.createdAt, style: .time).font(.caption) }
                Text(entry.detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }.overlay { if entries.isEmpty { Text("No tool calls have been recorded.").foregroundStyle(.secondary) } }.navigationTitle("Audit log").task { entries = (try? await environment.audit.list()) ?? [] }
    }
}
