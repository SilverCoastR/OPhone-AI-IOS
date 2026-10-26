import SwiftUI

struct ConversationListView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var environment: AppEnvironment
    var body: some View {
        NavigationStack {
            List {
                ForEach(environment.conversations) { conversation in
                    Button {
                        Task { await environment.selectConversation(conversation.id); dismiss() }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(conversation.title).font(.headline).lineLimit(2)
                            Text("\(conversation.messages.count) messages · \(conversation.updatedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                        }
                    }.buttonStyle(.plain)
                }.onDelete { offsets in for index in offsets { Task { await environment.deleteConversation(environment.conversations[index].id) } } }
            }.navigationTitle("Conversations").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
}
