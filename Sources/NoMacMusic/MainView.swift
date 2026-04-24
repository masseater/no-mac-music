import AppKit
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var core: AppCore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Intercept media keys", isOn: $core.isEnabled)
                        .toggleStyle(.switch)

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Target app").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $core.selectedTargetID) {
                            ForEach(core.allConfigs) { cfg in
                                Text(cfg.displayLabel).tag(cfg.id)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Toggle("Kill Music.app on launch", isOn: $core.killMusicOnLaunch)
                    Toggle("Launch at login", isOn: $core.loginItemEnabled)
                }
                .padding(.vertical, 2)
            }

            permissionBox

            Spacer(minLength: 0)

            HStack {
                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: {
                    Label("Preferences…", systemImage: "gearshape")
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(minWidth: 300, idealWidth: 320, minHeight: 360)
        .alert(
            AppMetadata.displayName,
            isPresented: Binding(
                get: { core.lastError != nil },
                set: { if !$0 { core.lastError = nil } }
            ),
            actions: { Button("OK", role: .cancel) { core.lastError = nil } },
            message: { Text(core.lastError ?? "") }
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "nosign")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(AppMetadata.displayName).font(.headline)
                Text("Route media keys to your player.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var permissionBox: some View {
        if !core.hasAccessibilityPermission {
            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text("Accessibility required")
                            .font(.subheadline).bold()
                    }
                    Text("Media keys can't be intercepted without Accessibility access.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("System Settings") { core.openAccessibilitySettings() }
                        Button("Recheck") {
                            core.refreshAccessibilityPermission()
                            core.reapplyState()
                        }
                    }
                    .controlSize(.small)
                }
                .padding(.vertical, 2)
            }
        }
    }
}
