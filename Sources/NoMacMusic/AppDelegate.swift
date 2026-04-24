import AppKit
import ApplicationServices
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings.shared
    private let mediaKeyTap = MediaKeyTap()
    private let musicKiller = MusicAppKiller()
    private var controller: TargetAppController = NullTargetAppController()

    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        buildStatusItem()
        rebuildMenu()
        refreshController()

        requestAccessibilityPermissionIfNeeded()
        applyEnabled(settings.isEnabled)
        applyKillMusic(settings.killMusicOnLaunch)
    }

    func applicationWillTerminate(_ notification: Notification) {
        mediaKeyTap.stop()
        musicKiller.stop()
    }

    // MARK: Status bar

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "nosign", accessibilityDescription: "NoMacMusic") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "NMM"
            }
            button.toolTip = "NoMacMusic"
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.target = self
        enabledItem.state = settings.isEnabled ? .on : .off
        menu.addItem(enabledItem)

        menu.addItem(.separator())

        let targetHeader = NSMenuItem(title: "Target App", action: nil, keyEquivalent: "")
        targetHeader.isEnabled = false
        menu.addItem(targetHeader)

        for app in TargetApp.allCases {
            let item = NSMenuItem(title: app.displayName, action: #selector(selectTargetApp(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = app.rawValue
            item.state = (app == settings.targetApp) ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let killItem = NSMenuItem(title: "Kill Music.app on Launch", action: #selector(toggleKillMusic), keyEquivalent: "")
        killItem.target = self
        killItem.state = settings.killMusicOnLaunch ? .on : .off
        menu.addItem(killItem)

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = settings.loginItemEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let accessibilityItem = NSMenuItem(
            title: "Open Accessibility Settings…",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit NoMacMusic", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: Actions

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
        applyEnabled(settings.isEnabled)
        rebuildMenu()
    }

    @objc private func selectTargetApp(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let app = TargetApp(rawValue: raw) else { return }
        settings.targetApp = app
        refreshController()
        rebuildMenu()
    }

    @objc private func toggleKillMusic() {
        settings.killMusicOnLaunch.toggle()
        applyKillMusic(settings.killMusicOnLaunch)
        rebuildMenu()
    }

    @objc private func toggleLoginItem() {
        let newValue = !settings.loginItemEnabled
        do {
            try LoginItem.setEnabled(newValue)
            settings.loginItemEnabled = newValue
        } catch {
            presentError("Failed to update login item: \(error.localizedDescription)")
        }
        rebuildMenu()
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: State application

    private func applyEnabled(_ enabled: Bool) {
        if enabled {
            do {
                try mediaKeyTap.start { [weak self] command in
                    self?.controller.send(command)
                }
            } catch {
                presentError("""
                Failed to start media key tap.
                Grant Accessibility permission in System Settings > Privacy & Security > Accessibility, then re-enable.
                """)
                settings.isEnabled = false
                rebuildMenu()
            }
        } else {
            mediaKeyTap.stop()
        }
    }

    private func applyKillMusic(_ enabled: Bool) {
        if enabled {
            musicKiller.start()
            musicKiller.terminateIfRunning()
        } else {
            musicKiller.stop()
        }
    }

    private func refreshController() {
        controller = TargetAppControllerFactory.make(for: settings.targetApp)
    }

    // MARK: Helpers

    private func requestAccessibilityPermissionIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func presentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "NoMacMusic"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
