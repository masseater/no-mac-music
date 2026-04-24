import Foundation

struct TargetAppConfig: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var bundleIdentifier: String
    var isBuiltIn: Bool
    var playPauseScript: String
    var nextScript: String
    var previousScript: String

    init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String = "",
        isBuiltIn: Bool = false,
        playPauseScript: String = "",
        nextScript: String = "",
        previousScript: String = ""
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.isBuiltIn = isBuiltIn
        self.playPauseScript = playPauseScript
        self.nextScript = nextScript
        self.previousScript = previousScript
    }
}

extension TargetAppConfig {
    static let noneID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    static let none = TargetAppConfig(
        id: noneID,
        name: "None",
        bundleIdentifier: "",
        isBuiltIn: true
    )

    // Presets whose AppleScript scripting dictionaries are documented to support
    // playpause / next track / previous track (or equivalent). Verified via
    // vendor docs / community references (see SPEC.md references).

    static let spotify = preset(
        idString: "11111111-1111-1111-1111-111111111111",
        name: "Spotify",
        bundleID: "com.spotify.client",
        scriptAppName: "Spotify"
    )

    static let appleMusic = preset(
        idString: "22222222-2222-2222-2222-222222222222",
        name: "Apple Music",
        bundleID: "com.apple.Music",
        scriptAppName: "Music"
    )

    static let appleTV = preset(
        idString: "33333333-3333-3333-3333-333333333333",
        name: "Apple TV",
        bundleID: "com.apple.TV",
        scriptAppName: "TV"
    )

    static let swinsian = preset(
        idString: "55555555-5555-5555-5555-555555555555",
        name: "Swinsian",
        bundleID: "com.swinsian.Swinsian",
        scriptAppName: "Swinsian"
    )

    static let vox = preset(
        idString: "99999999-9999-9999-9999-999999999999",
        name: "Vox",
        bundleID: "com.coppertino.Vox",
        scriptAppName: "Vox"
    )

    // VLC uses `play`, `next`, `previous` instead of the standard triplet.
    static let vlc = TargetAppConfig(
        id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
        name: "VLC",
        bundleIdentifier: "org.videolan.vlc",
        isBuiltIn: true,
        playPauseScript: "tell application \"VLC\" to play",
        nextScript: "tell application \"VLC\" to next",
        previousScript: "tell application \"VLC\" to previous"
    )

    static let allPresets: [TargetAppConfig] = [
        .spotify, .appleMusic, .appleTV, .swinsian, .vox, .vlc
    ]

    static let alwaysOn: [TargetAppConfig] = [.none]

    var displayLabel: String {
        isBuiltIn ? name : "\(name) (custom)"
    }

    static func scriptTemplate(for appName: String) -> (playPause: String, next: String, previous: String) {
        let escaped = appName.replacingOccurrences(of: "\"", with: "\\\"")
        return (
            playPause: "tell application \"\(escaped)\" to playpause",
            next: "tell application \"\(escaped)\" to next track",
            previous: "tell application \"\(escaped)\" to previous track"
        )
    }

    private static func preset(idString: String, name: String, bundleID: String, scriptAppName: String) -> TargetAppConfig {
        let t = scriptTemplate(for: scriptAppName)
        return TargetAppConfig(
            id: UUID(uuidString: idString)!,
            name: name,
            bundleIdentifier: bundleID,
            isBuiltIn: true,
            playPauseScript: t.playPause,
            nextScript: t.next,
            previousScript: t.previous
        )
    }
}
