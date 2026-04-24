import AppKit
import Foundation

final class MusicAppKiller {
    static let musicBundleIdentifier = "com.apple.Music"

    private var observer: NSObjectProtocol?
    private var isEnabled = false

    func start() {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.handle(notification: note)
        }
        isEnabled = true
    }

    func stop() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
        isEnabled = false
    }

    func terminateIfRunning() {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: Self.musicBundleIdentifier) {
            app.terminate()
        }
    }

    private func handle(notification: Notification) {
        guard isEnabled else { return }
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        guard app.bundleIdentifier == Self.musicBundleIdentifier else { return }
        app.terminate()
    }
}
