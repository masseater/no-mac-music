import AppKit
import Combine

@MainActor
final class StatusItemController: NSObject {
    private let core: AppCore
    private let statusItem: NSStatusItem
    private var cancellables = Set<AnyCancellable>()
    private weak var openSettings: AnyObject?
    private let showMainWindowHandler: () -> Void
    private let openSettingsHandler: () -> Void

    init(
        core: AppCore,
        showMainWindow: @escaping () -> Void,
        openSettings: @escaping () -> Void
    ) {
        self.core = core
        self.showMainWindowHandler = showMainWindow
        self.openSettingsHandler = openSettings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureButton()
        rebuildMenu()
        observeCore()
    }

    private func configureButton() {
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "nosign", accessibilityDescription: AppMetadata.displayName) {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "NMM"
            }
            button.toolTip = AppMetadata.displayName
        }
    }

    private func observeCore() {
        Publishers.MergeMany([
            core.$isEnabled.map { _ in () }.eraseToAnyPublisher(),
            core.$selectedTargetID.map { _ in () }.eraseToAnyPublisher(),
            core.$customConfigs.map { _ in () }.eraseToAnyPublisher(),
            core.$killMusicOnLaunch.map { _ in () }.eraseToAnyPublisher(),
            core.$loginItemEnabled.map { _ in () }.eraseToAnyPublisher(),
            core.$hasAccessibilityPermission.map { _ in () }.eraseToAnyPublisher(),
            core.$hasInputMonitoringPermission.map { _ in () }.eraseToAnyPublisher()
        ])
        .receive(on: RunLoop.main)
        .sink { [weak self] in self?.rebuildMenu() }
        .store(in: &cancellables)
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.target = self
        enabledItem.state = core.isEnabled ? .on : .off
        menu.addItem(enabledItem)

        menu.addItem(.separator())

        let targetHeader = NSMenuItem(title: "Target App", action: nil, keyEquivalent: "")
        targetHeader.isEnabled = false
        menu.addItem(targetHeader)

        for config in core.allConfigs {
            let item = NSMenuItem(title: config.displayLabel, action: #selector(selectTarget(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = config.id
            item.state = (config.id == core.selectedTargetID) ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let killItem = NSMenuItem(title: "Kill Music.app on Launch", action: #selector(toggleKillMusic), keyEquivalent: "")
        killItem.target = self
        killItem.state = core.killMusicOnLaunch ? .on : .off
        menu.addItem(killItem)

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = core.loginItemEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        if !core.hasAccessibilityPermission || !core.hasInputMonitoringPermission {
            let warning = NSMenuItem(title: "Permissions required", action: nil, keyEquivalent: "")
            warning.isEnabled = false
            menu.addItem(warning)
        }

        let mainItem = NSMenuItem(title: "Show Main Window", action: #selector(showMainWindow), keyEquivalent: "0")
        mainItem.target = self
        menu.addItem(mainItem)

        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit \(AppMetadata.displayName)", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func toggleEnabled() { core.isEnabled.toggle() }

    @objc private func selectTarget(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        core.selectedTargetID = id
    }

    @objc private func toggleKillMusic() { core.killMusicOnLaunch.toggle() }

    @objc private func toggleLoginItem() { core.loginItemEnabled.toggle() }

    @objc private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        showMainWindowHandler()
    }

    @objc private func openPreferences() {
        NSApp.activate(ignoringOtherApps: true)
        openSettingsHandler()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
