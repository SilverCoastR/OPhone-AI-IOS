import Foundation
import SwiftUI

@MainActor final class AppSettings: ObservableObject {
    private let defaults: UserDefaults
    @Published var selectedPlatform: ControlPlatform? { didSet { defaults.set(selectedPlatform?.rawValue, forKey: "selected-platform") } }
    @Published var telemetryEnabled: Bool { didSet { defaults.set(telemetryEnabled, forKey: "telemetry-enabled") } }
    @Published var remoteCatalogURL: String { didSet { defaults.set(remoteCatalogURL, forKey: "provider-catalog-url") } }
    @Published var colorScheme: String { didSet { defaults.set(colorScheme, forKey: "color-scheme") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selectedPlatform = defaults.string(forKey: "selected-platform").flatMap(ControlPlatform.init(rawValue:))
        telemetryEnabled = defaults.object(forKey: "telemetry-enabled") == nil ? true : defaults.bool(forKey: "telemetry-enabled")
        remoteCatalogURL = defaults.string(forKey: "provider-catalog-url") ?? ""
        colorScheme = defaults.string(forKey: "color-scheme") ?? "system"
    }

    var preferredColorScheme: ColorScheme? { colorScheme == "dark" ? .dark : colorScheme == "light" ? .light : nil }
}
