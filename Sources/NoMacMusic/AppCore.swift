import AppKit
import ApplicationServices
import Combine
import Foundation
import IOKit.hid

@MainActor
final class AppCore: ObservableObject {
    private enum Key {
        static let enabled = "enabled"
        static let selectedTargetID = "selectedTargetID"
        static let customConfigs = "customConfigs"
        static let killMusicOnLaunch = "killMusicOnLaunch"
    }

    @Published var isEnabled: Bool {
        didSet {
            guard oldValue != isEnabled else { return }
            defaults.set(isEnabled, forKey: Key.enabled)
            applyEnabled(isEnabled)
        }
    }

    @Published var killMusicOnLaunch: Bool {
        didSet {
            guard oldValue != killMusicOnLaunch else { return }
            defaults.set(killMusicOnLaunch, forKey: Key.killMusicOnLaunch)
            applyKillMusic(killMusicOnLaunch)
        }
    }

    @Published var loginItemEnabled: Bool {
        didSet {
            guard oldValue != loginItemEnabled else { return }
            do {
                try LoginItem.setEnabled(loginItemEnabled)
            } catch {
                lastError = "Failed to update login item: \(error.localizedDescription)"
                let actual = LoginItem.isEnabled
                if actual != loginItemEnabled {
                    loginItemEnabled = actual
                }
            }
        }
    }

    @Published var customConfigs: [TargetAppConfig] {
        didSet {
            persistCustomConfigs()
            // If selected was removed, fall back to None
            if !allConfigs.contains(where: { $0.id == selectedTargetID }) {
                selectedTargetID = TargetAppConfig.noneID
            }
            refreshController()
        }
    }

    @Published var selectedTargetID: UUID {
        didSet {
            guard oldValue != selectedTargetID else { return }
            defaults.set(selectedTargetID.uuidString, forKey: Key.selectedTargetID)
            refreshController()
        }
    }

    @Published private(set) var hasAccessibilityPermission: Bool = false
    @Published private(set) var hasInputMonitoringPermission: Bool = false
    @Published var lastError: String?

    var installedPresets: [TargetAppConfig] {
        TargetAppConfig.allPresets.filter { Self.isInstalled($0) }
    }

    var allConfigs: [TargetAppConfig] {
        TargetAppConfig.alwaysOn + installedPresets + customConfigs
    }

    static func isInstalled(_ cfg: TargetAppConfig) -> Bool {
        guard !cfg.bundleIdentifier.isEmpty else { return false }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: cfg.bundleIdentifier) != nil
    }

    var selectedConfig: TargetAppConfig {
        allConfigs.first { $0.id == selectedTargetID } ?? .none
    }

    private let defaults: UserDefaults
    private let mediaKeyTap = MediaKeyTap()
    private let musicKiller = MusicAppKiller()
    private var controller: TargetAppController = NullTargetAppController()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.enabled: true,
            Key.selectedTargetID: TargetAppConfig.noneID.uuidString,
            Key.killMusicOnLaunch: true
        ])

        self.isEnabled = defaults.bool(forKey: Key.enabled)
        self.killMusicOnLaunch = defaults.bool(forKey: Key.killMusicOnLaunch)
        self.loginItemEnabled = LoginItem.isEnabled
        let loadedCustoms = Self.loadCustomConfigs(from: defaults)
        self.customConfigs = loadedCustoms

        let storedID = defaults.string(forKey: Key.selectedTargetID).flatMap(UUID.init(uuidString:))
        let installedPresetIDs = TargetAppConfig.allPresets
            .filter { Self.isInstalled($0) }
            .map(\.id)
        let knownIDs = Set(
            TargetAppConfig.alwaysOn.map(\.id)
            + installedPresetIDs
            + loadedCustoms.map(\.id)
        )
        self.selectedTargetID = storedID.flatMap { knownIDs.contains($0) ? $0 : nil } ?? TargetAppConfig.noneID

        refreshController()
        refreshAccessibilityPermission(prompt: true)
        refreshInputMonitoringPermission(prompt: true)
        applyEnabled(isEnabled)
        applyKillMusic(killMusicOnLaunch)
    }

    deinit {
        mediaKeyTap.stop()
        musicKiller.stop()
    }

    // MARK: Target config CRUD

    func addCustomConfig(_ config: TargetAppConfig) {
        var cfg = config
        cfg.isBuiltIn = false
        if cfg.id == TargetAppConfig.noneID {
            cfg.id = UUID()
        }
        customConfigs.append(cfg)
        selectedTargetID = cfg.id
    }

    func updateCustomConfig(_ config: TargetAppConfig) {
        guard !config.isBuiltIn else { return }
        if let idx = customConfigs.firstIndex(where: { $0.id == config.id }) {
            customConfigs[idx] = config
            if selectedTargetID == config.id {
                refreshController()
            }
        }
    }

    func removeCustomConfig(id: UUID) {
        customConfigs.removeAll { $0.id == id }
    }

    // MARK: Accessibility

    func refreshAccessibilityPermission(prompt: Bool = false) {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
        ] as CFDictionary
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(options)
    }

    func refreshInputMonitoringPermission(prompt: Bool = false) {
        let granted: Bool
        if prompt {
            granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        } else {
            granted = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        }
        hasInputMonitoringPermission = granted
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func openInputMonitoringSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }

    func reapplyState() {
        applyEnabled(isEnabled)
        applyKillMusic(killMusicOnLaunch)
    }

    // MARK: Private

    private func refreshController() {
        controller = TargetAppControllerFactory.make(for: selectedConfig)
    }

    private func applyEnabled(_ enabled: Bool) {
        if enabled {
            do {
                try mediaKeyTap.start { [weak self] command in
                    Task { @MainActor in
                        self?.controller.send(command)
                    }
                }
                refreshAccessibilityPermission()
                refreshInputMonitoringPermission()
            } catch {
                lastError = """
                Failed to start media key capture.
                Grant both Accessibility and Input Monitoring in System Settings > Privacy & Security, then re-enable.
                """
                isEnabled = false
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

    private func persistCustomConfigs() {
        do {
            let data = try JSONEncoder().encode(customConfigs)
            defaults.set(data, forKey: Key.customConfigs)
        } catch {
            FileHandle.standardError.write(Data("[\(AppMetadata.displayName)] failed to persist custom configs: \(error)\n".utf8))
        }
    }

    private static func loadCustomConfigs(from defaults: UserDefaults) -> [TargetAppConfig] {
        guard let data = defaults.data(forKey: Key.customConfigs) else { return [] }
        do {
            return try JSONDecoder().decode([TargetAppConfig].self, from: data)
        } catch {
            return []
        }
    }
}
