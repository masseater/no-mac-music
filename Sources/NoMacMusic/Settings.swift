import Foundation

enum TargetApp: String, CaseIterable {
    case none
    case spotify

    var displayName: String {
        switch self {
        case .none: return "None"
        case .spotify: return "Spotify"
        }
    }
}

final class Settings {
    static let shared = Settings()

    private enum Key {
        static let enabled = "enabled"
        static let targetApp = "targetApp"
        static let killMusicOnLaunch = "killMusicOnLaunch"
        static let loginItemEnabled = "loginItemEnabled"
    }

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            Key.enabled: true,
            Key.targetApp: TargetApp.spotify.rawValue,
            Key.killMusicOnLaunch: true,
            Key.loginItemEnabled: false
        ])
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    var targetApp: TargetApp {
        get { TargetApp(rawValue: defaults.string(forKey: Key.targetApp) ?? "") ?? .spotify }
        set { defaults.set(newValue.rawValue, forKey: Key.targetApp) }
    }

    var killMusicOnLaunch: Bool {
        get { defaults.bool(forKey: Key.killMusicOnLaunch) }
        set { defaults.set(newValue, forKey: Key.killMusicOnLaunch) }
    }

    var loginItemEnabled: Bool {
        get { defaults.bool(forKey: Key.loginItemEnabled) }
        set { defaults.set(newValue, forKey: Key.loginItemEnabled) }
    }
}
