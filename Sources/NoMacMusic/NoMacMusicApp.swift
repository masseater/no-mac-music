import AppKit
import SwiftUI

@main
struct NoMacMusicApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(AppMetadata.displayName) {
            MainView()
                .environmentObject(appDelegate.core)
        }
        .defaultSize(width: 320, height: 400)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
                .environmentObject(appDelegate.core)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let core = AppCore()
    private var statusController: StatusItemController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        statusController = StatusItemController(
            core: core,
            showMainWindow: { [weak self] in self?.showMainWindow() },
            openSettings: { Self.openSettingsWindow() }
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow() }
        return true
    }

    private func showMainWindow() {
        for window in NSApp.windows
        where window.canBecomeMain && window.title == AppMetadata.displayName {
            window.makeKeyAndOrderFront(nil)
            return
        }
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
            return
        }
    }

    private static func openSettingsWindow() {
        // SwiftUI registers a `showSettingsWindow:` action on macOS 13+.
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
