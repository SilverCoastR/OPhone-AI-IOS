import SwiftUI
import UIKit

struct APIChatHomeView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var draft = ""
    @State private var showConversations = false
    @State private var showSettings = false
    @State private var showTools = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messages
                if environment.isRunning || !environment.progress.isEmpty { progressBar }
                composer
            }
            .navigationTitle(environment.currentConversation?.title ?? "OPhone AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { showConversations = true } label: { Image(systemName: "sidebar.left") } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { Task { await environment.newConversation() } } label: { Image(systemName: "square.and.pencil") }
                    Button { showTools = true } label: { Image(systemName: "wrench.and.screwdriver") }
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
        }
        .sheet(isPresented: $showConversations) { ConversationListView() }
        .sheet(isPresented: $showSettings) { NavigationStack { SettingsView() } }
        .sheet(isPresented: $showTools) { NavigationStack { ToolsView() } }
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(environment.currentConversation?.messages.filter { !$0.isInternal } ?? []) { message in
                        MessageBubble(message: message).id(message.id)
                    }
                    if !environment.streamingText.isEmpty { MessageBubble(message: ChatMessage(role: .assistant, content: environment.streamingText)).id("stream") }
                }.padding()
            }
            .onChange(of: environment.currentConversation?.messages.count) { _ in scroll(proxy) }
            .onChange(of: environment.streamingText) { _ in scroll(proxy) }
        }
    }
    private func scroll(_ proxy: ScrollViewProxy) {
        withAnimation {
            if !environment.streamingText.isEmpty { proxy.scrollTo("stream", anchor: .bottom) }
            else if let id = environment.currentConversation?.messages.last?.id { proxy.scrollTo(id, anchor: .bottom) }
        }
    }

    private var progressBar: some View {
        HStack(spacing: 10) {
            if environment.isRunning { ProgressView().controlSize(.small) }
            Text(environment.progress).font(.caption).lineLimit(1)
            Spacer()
            if environment.isRunning { Button("Stop", role: .destructive) { environment.stop() }.font(.caption.bold()) }
        }.padding(.horizontal).padding(.vertical, 8).background(.thinMaterial)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message OPhone AI", text: $draft, axis: .vertical).lineLimit(1...6).textFieldStyle(.roundedBorder)
            Button {
                let value = draft; draft = ""; environment.send(value)
            } label: { Image(systemName: "arrow.up.circle.fill").font(.system(size: 30)) }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || environment.isRunning)
        }.padding().background(.bar)
    }
}

private struct MessageBubble: View {
    @EnvironmentObject private var environment: AppEnvironment
    let message: ChatMessage
    var body: some View {
        HStack { if message.role == .user { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 6) {
                Text(attributed(message.content)).textSelection(.enabled)
                Text(message.createdAt, style: .time).font(.caption2).foregroundStyle(.secondary)
            }.padding(12).background(message.role == .user ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 15))
            .contextMenu {
                Button("Copy") { UIPasteboard.general.string = message.content }
                Button("Delete", role: .destructive) { Task { await environment.deleteMessage(message.id) } }
            }
            if message.role != .user { Spacer(minLength: 40) }
        }
    }
    private func attributed(_ text: String) -> AttributedString { (try? AttributedString(markdown: text)) ?? AttributedString(text) }
}
