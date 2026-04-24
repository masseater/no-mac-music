import AppKit
import Foundation

struct SpotifyController: TargetAppController {
    private static let queue = DispatchQueue(label: "com.masseater.NoMacMusic.spotify")

    func send(_ command: MediaCommand) {
        let script: String
        switch command {
        case .playPause:
            script = "tell application \"Spotify\" to playpause"
        case .next:
            script = "tell application \"Spotify\" to next track"
        case .previous:
            script = "tell application \"Spotify\" to previous track"
        }

        SpotifyController.queue.async {
            Self.run(script: script)
        }
    }

    private static func run(script source: String) {
        guard let script = NSAppleScript(source: source) else { return }
        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            FileHandle.standardError.write(Data("[NoMacMusic] AppleScript error: \(errorInfo)\n".utf8))
        }
    }
}
