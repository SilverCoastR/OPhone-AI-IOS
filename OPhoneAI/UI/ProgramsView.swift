import SwiftUI

struct ProgramsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var programs: [SavedProgram] = []
    @State private var name = ""
    @State private var summary = ""
    @State private var source = "return input;"
    @State private var status = ""
    var body: some View {
        List {
            Section("Save program") {
                TextField("Name", text: $name); TextField("Purpose", text: $summary)
                TextEditor(text: $source).font(.system(.body, design: .monospaced)).frame(minHeight: 130)
                Button("Save") { Task { await save() } }
            }
            Section("Programs") {
                if programs.isEmpty { Text("No saved programs.").foregroundStyle(.secondary) }
                ForEach(programs) { program in
                    VStack(alignment: .leading) { Text(program.name).font(.headline); Text(program.summary).font(.caption).foregroundStyle(.secondary) }
                    .swipeActions { Button("Delete", role: .destructive) { Task { try? await environment.programs.delete(program.id); await reload() } } }
                }
            }
            if !status.isEmpty { Text(status).font(.caption) }
        }.navigationTitle("JavaScript programs").task { await reload() }
    }
    private func reload() async { programs = (try? await environment.programs.list()) ?? [] }
    private func save() async { do { _ = try await environment.programs.save(name: name, summary: summary, source: source); status = "Saved."; await reload() } catch { status = error.localizedDescription } }
}
