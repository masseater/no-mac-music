import AppKit
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
    func send(_ command: MediaCommand) {}
}

struct AppleScriptController: TargetAppController {
    private static let queue = DispatchQueue(label: "com.masseater.NoMacMusic.applescript")

    let config: TargetAppConfig

    func send(_ command: MediaCommand) {
        let script: String
        switch command {
        case .playPause: script = config.playPauseScript
        case .next: script = config.nextScript
        case .previous: script = config.previousScript
        }
        guard !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Self.queue.async { Self.run(source: script) }
    }

    private static func run(source: String) {
        guard let script = NSAppleScript(source: source) else { return }
        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            FileHandle.standardError.write(Data("[NoMacMusic] AppleScript error: \(errorInfo)\n".utf8))
        }
    }
}

enum TargetAppControllerFactory {
    static func make(for config: TargetAppConfig) -> TargetAppController {
        if config.id == TargetAppConfig.noneID { return NullTargetAppController() }
        return AppleScriptController(config: config)
    }
}
