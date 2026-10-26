import Foundation
import UIKit

actor TelemetryClient {
    private let endpoint = URL(string: "https://ophone-telemetry-api.ooorrrt66.workers.dev/v1/app-open")!
    private let session: URLSession
    private let keychain: KeychainStore
    init(session: URLSession = .shared, keychain: KeychainStore) { self.session = session; self.keychain = keychain }

    func reportLaunch() async {
        do {
            let installID: String
            if let existing = try await keychain.get("install-id") { installID = existing }
            else { installID = UUID().uuidString.lowercased(); try await keychain.set(installID, for: "install-id") }
            let locale = Locale.current
            let payload: [String: Any] = [
                "install_id": installID,
                "platform": "ios",
                "device_model": DeviceInformation.machineIdentifier,
                "device_family": UIDevice.current.model,
                "system_name": UIDevice.current.systemName,
                "system_version": UIDevice.current.systemVersion,
                "language": locale.language.languageCode?.identifier ?? "",
                "region": locale.region?.identifier ?? "",
                "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
                "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
            ]
            var request = URLRequest(url: endpoint); request.httpMethod = "POST"; request.timeoutInterval = 10
            request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            _ = try await session.data(for: request)
        } catch { }
    }
}

enum DeviceInformation {
    static var machineIdentifier: String {
        var systemInfo = utsname(); uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }
}
