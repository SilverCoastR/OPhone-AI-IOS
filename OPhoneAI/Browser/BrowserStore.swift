import Combine
import Foundation
import UIKit
import WebKit

struct BrowserTab: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var title: String
    var url: URL
    var createdAt = Date()
}

@MainActor final class BrowserStore: ObservableObject {
    @Published private(set) var tabs: [BrowserTab] = []
    @Published var selectedID: UUID?
    @Published var isPresented = false
    private var webViews: [UUID: WKWebView] = [:]

    @discardableResult func open(_ url: URL) -> BrowserTab {
        let tab = BrowserTab(title: url.host ?? url.absoluteString, url: url)
        tabs.append(tab); selectedID = tab.id; isPresented = true; return tab
    }
    func close(_ id: UUID) { tabs.removeAll { $0.id == id }; webViews[id] = nil; if selectedID == id { selectedID = tabs.last?.id } }
    func navigate(_ id: UUID, to url: URL) { guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }; tabs[index].url = url }
    func attach(_ webView: WKWebView, to id: UUID) { webViews[id] = webView }
    func detach(_ id: UUID) { webViews[id] = nil }
    func update(_ id: UUID, title: String?, url: URL?) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        if let title, !title.isEmpty { tabs[index].title = title }; if let url { tabs[index].url = url }
    }

    func inspect(_ rawID: String?) async throws -> JSONObject {
        let (id, webView) = try resolve(rawID)
        let script = """
        (() => ({
          title: document.title || '', url: location.href,
          text: (document.body && document.body.innerText || '').slice(0, 30000),
          links: Array.from(document.querySelectorAll('a[href]')).slice(0,100).map((e,i)=>({index:i,text:(e.innerText||e.getAttribute('aria-label')||'').trim().slice(0,200),href:e.href})),
          controls: Array.from(document.querySelectorAll('button,input,textarea,select,[role=button]')).slice(0,150).map((e,i)=>({index:i,tag:e.tagName.toLowerCase(),type:e.type||'',text:(e.innerText||e.value||e.getAttribute('aria-label')||e.placeholder||'').trim().slice(0,200),disabled:!!e.disabled}))
        }))()
        """
        let result = try await webView.evaluateJavaScript(script)
        guard let object = try JSONValue(any: result).objectValue else { throw ModelTransportError.invalidResponse }
        return ["ok": .bool(true), "tab_id": .string(id.uuidString), "page": .object(object)]
    }

    func click(tab rawID: String?, index: Int) async throws -> JSONObject {
        let (_, webView) = try resolve(rawID)
        let script = """
        (()=>{const a=Array.from(document.querySelectorAll('button,input,textarea,select,[role=button]'));const e=a[\(index)];if(!e)return {ok:false,error:'target_not_found'};e.scrollIntoView({block:'center'});e.click();return {ok:true,tag:e.tagName.toLowerCase()};})()
        """
        return try await resultObject(webView.evaluateJavaScript(script))
    }

    func fill(tab rawID: String?, index: Int, text: String) async throws -> JSONObject {
        let (_, webView) = try resolve(rawID)
        let encoded = String(data: try JSONEncoder().encode(text), encoding: .utf8) ?? "\"\""
        let script = """
        (()=>{const a=Array.from(document.querySelectorAll('input,textarea,[contenteditable=true]'));const e=a[\(index)];if(!e)return {ok:false,error:'target_not_found'};e.focus();const v=\(encoded);if(e.isContentEditable)e.textContent=v;else{const s=Object.getOwnPropertyDescriptor(Object.getPrototypeOf(e),'value')?.set;s?s.call(e,v):e.value=v;}e.dispatchEvent(new Event('input',{bubbles:true}));e.dispatchEvent(new Event('change',{bubbles:true}));return {ok:true};})()
        """
        return try await resultObject(webView.evaluateJavaScript(script))
    }

    func evaluate(tab rawID: String?, source: String) async throws -> JSONValue {
        guard source.utf8.count <= 32 * 1_024 else { throw JavaScriptSandbox.SandboxError.sourceTooLarge }
        let (_, webView) = try resolve(rawID); let result = try await webView.evaluateJavaScript(source)
        return result == nil ? .null : try JSONValue(any: result as Any)
    }

    func screenshot(tab rawID: String?) async throws -> Data {
        let (_, webView) = try resolve(rawID); let image = try await webView.takeSnapshot(configuration: nil)
        guard let data = image.pngData() else { throw ModelTransportError.invalidResponse }; return data
    }

    private func resolve(_ rawID: String?) throws -> (UUID, WKWebView) {
        let id = rawID.flatMap(UUID.init(uuidString:)) ?? selectedID
        guard let id, let webView = webViews[id] else { throw BrowserError.tabNotVisible }; return (id, webView)
    }
    private func resultObject(_ value: Any?) async throws -> JSONObject { guard let value, let object = try JSONValue(any: value).objectValue else { throw ModelTransportError.invalidResponse }; return object }
}

enum BrowserError: LocalizedError { case tabNotVisible; var errorDescription: String? { "Open the requested tab in the built-in browser before inspecting or operating its DOM." } }
