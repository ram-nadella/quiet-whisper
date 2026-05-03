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

    var model: WhisperModelKind {
        didSet { UserDefaults.standard.set(model.rawValue, forKey: Keys.model) }
    }

    var autoPunct: Bool {
        didSet { UserDefaults.standard.set(autoPunct, forKey: Keys.autoPunct) }
    }

    var dark: Bool {
        didSet { UserDefaults.standard.set(dark, forKey: Keys.dark) }
    }

    var sidebarOpen: Bool {
        didSet { UserDefaults.standard.set(sidebarOpen, forKey: Keys.sidebar) }
    }

    var density: EditorDensity {
        didSet { UserDefaults.standard.set(density.rawValue, forKey: Keys.density) }
    }

    init() {
        let d = UserDefaults.standard

        if let raw = d.string(forKey: Keys.model), let m = WhisperModelKind(rawValue: raw) {
            self.model = m
        } else {
            self.model = .small
        }

        // Bool values: object(forKey:) returns nil if unset so we can
        // distinguish "default" from an explicit false.
        self.autoPunct   = (d.object(forKey: Keys.autoPunct) as? Bool) ?? true
        self.dark        = (d.object(forKey: Keys.dark) as? Bool) ?? false
        self.sidebarOpen = (d.object(forKey: Keys.sidebar) as? Bool) ?? false

        if let raw = d.string(forKey: Keys.density), let dens = EditorDensity(rawValue: raw) {
            self.density = dens
        } else {
            self.density = .regular
        }
    }
}
