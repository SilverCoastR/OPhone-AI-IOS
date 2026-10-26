import SwiftUI

struct ToolsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var environment: AppEnvironment
    var body: some View {
        List {
            Section("Workbench") {
                Button { if environment.browser.tabs.isEmpty, let url = URL(string: "https://www.google.com") { _ = environment.browser.open(url) } else { environment.browser.isPresented = true } } label: { Label("Built-in browser", systemImage: "globe") }
                NavigationLink { WorkspaceView() } label: { Label("Workspace files", systemImage: "folder") }
                NavigationLink { ProgramsView() } label: { Label("JavaScript programs", systemImage: "curlybraces") }
            }
            Section("Agent data") {
                NavigationLink { MemoryView() } label: { Label("AI memory", systemImage: "brain") }
                NavigationLink { AuditView() } label: { Label("Audit log", systemImage: "list.bullet.clipboard") }
            }
            Section { Text("iOS edition intentionally excludes cross-app accessibility control, root access, and arbitrary shell commands.").font(.footnote).foregroundStyle(.secondary) }
        }.navigationTitle("Tools").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}
