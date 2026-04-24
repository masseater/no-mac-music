import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            TargetAppsTab()
                .tabItem { Label("Apps", systemImage: "play.rectangle") }
            PermissionsTab()
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .frame(width: 420, height: 360)
    }
}

private struct GeneralSettingsTab: View {
    @EnvironmentObject private var core: AppCore

    var body: some View {
        Form {
            Toggle("Intercept media keys", isOn: $core.isEnabled)
            Toggle("Kill Music.app automatically when it launches", isOn: $core.killMusicOnLaunch)
            Toggle("Launch NoMacMusic at login", isOn: $core.loginItemEnabled)
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct TargetAppsTab: View {
    @EnvironmentObject private var core: AppCore
    @State private var editing: TargetAppConfig?
    @State private var isAdding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Active target", selection: $core.selectedTargetID) {
                ForEach(core.allConfigs) { cfg in
                    Text(cfg.displayLabel).tag(cfg.id)
                }
            }
            .pickerStyle(.menu)

            Divider()

            HStack {
                Text("Custom apps")
                    .font(.headline)
                Spacer()
                Button {
                    isAdding = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }

            customList
        }
        .padding()
        .sheet(isPresented: $isAdding) {
            ConfigEditor(
                initial: TargetAppConfig(name: ""),
                mode: .add,
                onSave: { cfg in
                    core.addCustomConfig(cfg)
                    isAdding = false
                },
                onCancel: { isAdding = false }
            )
        }
        .sheet(item: $editing) { cfg in
            ConfigEditor(
                initial: cfg,
                mode: .edit,
                onSave: { updated in
                    core.updateCustomConfig(updated)
                    editing = nil
                },
                onCancel: { editing = nil }
            )
        }
    }

    @ViewBuilder
    private var customList: some View {
        if core.customConfigs.isEmpty {
            Text("No custom apps. Add one with + to target any AppleScript-compatible player.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 24)
        } else {
            List {
                ForEach(core.customConfigs) { cfg in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cfg.name).font(.body)
                            if !cfg.bundleIdentifier.isEmpty {
                                Text(cfg.bundleIdentifier)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("Edit") { editing = cfg }
                        Button(role: .destructive) {
                            core.removeCustomConfig(id: cfg.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .frame(minHeight: 140)
        }
    }
}

private struct PermissionsTab: View {
    @EnvironmentObject private var core: AppCore

    var body: some View {
        Form {
            Section("Accessibility") {
                permissionRow(granted: core.hasAccessibilityPermission, openSettings: core.openAccessibilitySettings) {
                    core.refreshAccessibilityPermission()
                    core.reapplyState()
                }
                Text("Required for AppleScript/menu control of the target app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Input Monitoring") {
                permissionRow(granted: core.hasInputMonitoringPermission, openSettings: core.openInputMonitoringSettings) {
                    core.refreshInputMonitoringPermission()
                    core.reapplyState()
                }
                Text("Required to intercept media keys at the HID layer before Music.app receives them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func permissionRow(granted: Bool, openSettings: @escaping () -> Void, recheck: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(granted ? Color.green : Color.red)
            Text(granted ? "Granted" : "Not granted")
            Spacer()
            Button("Open System Settings", action: openSettings)
            Button("Recheck", action: recheck)
        }
    }
}

private struct ConfigEditor: View {
    enum Mode { case add, edit }

    @State var config: TargetAppConfig
    let mode: Mode
    let onSave: (TargetAppConfig) -> Void
    let onCancel: () -> Void

    init(
        initial: TargetAppConfig,
        mode: Mode,
        onSave: @escaping (TargetAppConfig) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _config = State(initialValue: initial)
        self.mode = mode
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(mode == .add ? "Add custom app" : "Edit custom app")
                .font(.title2).bold()

            Form {
                HStack {
                    Button {
                        pickAppBundle()
                    } label: {
                        Label("Choose App…", systemImage: "app.badge")
                    }
                    Spacer()
                    Button("Fill AppleScript from name") {
                        let t = TargetAppConfig.scriptTemplate(for: config.name)
                        config.playPauseScript = t.playPause
                        config.nextScript = t.next
                        config.previousScript = t.previous
                    }
                    .disabled(config.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                TextField("Display name", text: $config.name)
                TextField("Bundle identifier (optional)", text: $config.bundleIdentifier)
                    .textFieldStyle(.roundedBorder)

                scriptField("Play / Pause AppleScript", text: $config.playPauseScript)
                scriptField("Next AppleScript", text: $config.nextScript)
                scriptField("Previous AppleScript", text: $config.previousScript)
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { onCancel() }
                Button(mode == .add ? "Add" : "Save") {
                    onSave(config)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(config.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 420, height: 460)
    }

    private func pickAppBundle() {
        let panel = NSOpenPanel()
        panel.title = "Choose Application"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url,
              let bundle = Bundle(url: url) else { return }

        let name = (bundle.infoDictionary?["CFBundleName"] as? String)
            ?? (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let bundleID = bundle.bundleIdentifier ?? ""

        config.name = name
        config.bundleIdentifier = bundleID
        let t = TargetAppConfig.scriptTemplate(for: name)
        if config.playPauseScript.isEmpty { config.playPauseScript = t.playPause }
        if config.nextScript.isEmpty { config.nextScript = t.next }
        if config.previousScript.isEmpty { config.previousScript = t.previous }
    }

    private func scriptField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextEditor(text: text)
                .font(.system(.callout, design: .monospaced))
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
    }
}
