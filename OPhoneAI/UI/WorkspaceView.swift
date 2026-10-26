import SwiftUI

struct WorkspaceView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var items: [JSONObject] = []
    @State private var filename = "note.txt"
    @State private var text = ""
    @State private var status = ""
    var body: some View {
        List {
            Section("Create or replace a text file") {
                TextField("Relative path", text: $filename).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextEditor(text: $text).frame(minHeight: 100)
                Button("Save") { Task { await save() } }
            }
            Section("Files") {
                if items.isEmpty { Text("The workspace is empty.").foregroundStyle(.secondary) }
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Button { Task { await read(item.string("path")) } } label: {
                        HStack { Image(systemName: item.bool("directory") ? "folder" : "doc"); VStack(alignment: .leading) { Text(item.string("path")); Text("\(Int(item.number("size"))) bytes").font(.caption).foregroundStyle(.secondary) } }
                    }.disabled(item.bool("directory"))
                }
            }
            if !status.isEmpty { Section { Text(status).font(.caption).textSelection(.enabled) } }
        }.navigationTitle("Workspace").task { await reload() }
    }
    private func reload() async { do { items = try await environment.workspace.list(recursive: true) } catch { status = error.localizedDescription } }
    private func save() async { do { _ = try await environment.workspace.write(path: filename, text: text); status = "Saved \(filename)."; await reload() } catch { status = error.localizedDescription } }
    private func read(_ path: String) async { do { filename = path; text = try await environment.workspace.read(path: path); status = "Loaded \(path)." } catch { status = error.localizedDescription } }
}
