import Foundation

enum MediaCommand {
    case playPause
    case next
    case previous
}

protocol TargetAppController {
    func send(_ command: MediaCommand)
}

struct NullTargetAppController: TargetAppController {
    func send(_ command: MediaCommand) {
        // intentionally ignore
    }
}

enum TargetAppControllerFactory {
    static func make(for app: TargetApp) -> TargetAppController {
        switch app {
        case .none:
            return NullTargetAppController()
        case .spotify:
            return SpotifyController()
        }
    }
}
