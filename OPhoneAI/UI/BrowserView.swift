import SwiftUI

struct BrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var browser: BrowserStore
    @State private var address = ""
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("https://", text: $address).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder).onSubmit(openAddress)
                Button(action: openAddress) { Image(systemName: "arrow.right.circle.fill") }
                Button { if let url = URL(string: "https://www.google.com") { _ = browser.open(url) } } label: { Image(systemName: "plus") }
            }.padding(10).background(.bar)
            if browser.tabs.isEmpty {
                VStack(spacing: 12) { Image(systemName: "globe").font(.largeTitle); Text("No browser tabs").font(.headline); Text("Open a page from Tools or ask the agent to use browser_open.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center) }.padding()
            }
            else if let tab = selectedTab {
                BrowserTabContainer(tab: tab, browser: browser).id(tab.id)
            }
            if browser.tabs.count > 1 {
                Picker("Tab", selection: $browser.selectedID) { ForEach(browser.tabs) { tab in Text(tab.title).lineLimit(1).tag(Optional(tab.id)) } }.pickerStyle(.menu).padding(.horizontal)
            }
        }
        .navigationTitle("Browser").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Done") { browser.isPresented = false; dismiss() } }
            ToolbarItem(placement: .primaryAction) { if let id = browser.selectedID { Button(role: .destructive) { browser.close(id) } label: { Image(systemName: "trash") } } }
        }
        .onAppear { address = selectedTab?.url.absoluteString ?? "" }
        .onChange(of: browser.selectedID) { _ in address = selectedTab?.url.absoluteString ?? "" }
    }
    private var selectedTab: BrowserTab? { browser.tabs.first { $0.id == browser.selectedID } ?? browser.tabs.last }
    private func openAddress() { var value = address.trimmingCharacters(in: .whitespacesAndNewlines); if !value.contains("://") { value = "https://" + value }; guard let url = URL(string: value), url.scheme == "https" else { return }; if let id = browser.selectedID { browser.navigate(id, to: url) } else { _ = browser.open(url) } }
}
