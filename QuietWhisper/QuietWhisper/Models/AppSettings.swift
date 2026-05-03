import Foundation
import Observation

/// User-facing app settings, persisted to UserDefaults so they share between
/// views without requiring a SwiftUI environment hop. We do not use
/// `@AppStorage` because we want a single observable instance the whole app
/// can read/mutate.
@Observable
final class AppSettings {
    private enum Keys {
        static let model      = "qw.model"
        static let autoPunct  = "qw.autoPunct"
        static let dark       = "qw.dark"
        static let sidebar    = "qw.sidebar"
        static let density    = "qw.density"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var model: WhisperModelKind {
        didSet { defaults.set(model.rawValue, forKey: Keys.model) }
    }

    var autoPunct: Bool {
        didSet { defaults.set(autoPunct, forKey: Keys.autoPunct) }
    }

    var dark: Bool {
        didSet { defaults.set(dark, forKey: Keys.dark) }
    }

    var sidebarOpen: Bool {
        didSet { defaults.set(sidebarOpen, forKey: Keys.sidebar) }
    }

    var density: EditorDensity {
        didSet { defaults.set(density.rawValue, forKey: Keys.density) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let raw = defaults.string(forKey: Keys.model), let m = WhisperModelKind(rawValue: raw) {
            self.model = m
        } else {
            self.model = .small
        }

        // Bool values: object(forKey:) returns nil if unset so we can
        // distinguish "default" from an explicit false.
        self.autoPunct   = (defaults.object(forKey: Keys.autoPunct) as? Bool) ?? true
        self.dark        = (defaults.object(forKey: Keys.dark) as? Bool) ?? false
        self.sidebarOpen = (defaults.object(forKey: Keys.sidebar) as? Bool) ?? false

        if let raw = defaults.string(forKey: Keys.density), let dens = EditorDensity(rawValue: raw) {
            self.density = dens
        } else {
            self.density = .regular
        }

        QWLog.settings.notice("settings: loaded model=\(self.model.rawValue, privacy: .public) autoPunct=\(self.autoPunct, privacy: .public) dark=\(self.dark, privacy: .public) sidebarOpen=\(self.sidebarOpen, privacy: .public) density=\(self.density.rawValue, privacy: .public)")
    }
}
