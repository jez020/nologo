import SwiftUI
import AppKit
import ServiceManagement
import Observation

@MainActor
@Observable
private final class LoginSettings {
    private(set) var status = SMAppService.mainApp.status
    private(set) var isUpdating = false
    var errorMessage: String?
    var showsError = false

    var opensAtLogin: Bool {
        get { status == .enabled || status == .requiresApproval }
        set {
            guard !isUpdating, newValue != opensAtLogin else { return }
            isUpdating = true
            Task {
                defer {
                    refresh()
                    isUpdating = false
                }
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try await SMAppService.mainApp.unregister()
                    }
                } catch {
                    errorMessage = error.localizedDescription
                    showsError = true
                }
            }
        }
    }

    func refresh() {
        // macOS owns this preference; it can change outside the app.
        status = SMAppService.mainApp.status
    }
}

private struct LoginSettingsSection: View {
    @State private var loginSettings = LoginSettings()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Section("Startup") {
            Toggle("Open at Login", isOn: $loginSettings.opensAtLogin)
                .disabled(loginSettings.isUpdating)

            if loginSettings.status == .requiresApproval {
                Text("Allow NoLogo in System Settings to open automatically when you log in.")
                    .foregroundStyle(.secondary)
                Button("Open Login Items Settings…") {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }
        }
        .onAppear { loginSettings.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { loginSettings.refresh() }
        }
        .alert("Couldn’t Change Open at Login", isPresented: $loginSettings.showsError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(loginSettings.errorMessage ?? "Please try again.")
        }
    }
}

struct SettingsView: View {
    var model: LogoLightModel = .shared
    @AppStorage("showDockIcon") private var showDockIcon = true
    @State private var updates = UpdateManager.shared
    @State private var shortcuts = ShortcutSettings.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmsRemoval = false
    @State private var showsError = false
    @State private var errorMessage = ""

    var body: some View {
        Form {
            Section("Info") {
                LabeledContent("App", value: "NoLogo")
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                LabeledContent("Build", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—")
            }

            Section("Updates") {
                Button("Check for Updates…") { updates.checkForUpdates() }
                    .disabled(!updates.canCheckForUpdates)
                if let message = updates.configurationMessage {
                    Text(message).foregroundStyle(.secondary)
                }
            }

            LoginSettingsSection()

            Section("App appearance") {
                Toggle("Show in Dock", isOn: $showDockIcon)
                Text("When hidden, use the menu bar lightbulb to open NoLogo, access Settings, or quit.")
                    .foregroundStyle(.secondary)
            }

            Section("Logo-control helper") {
                LabeledContent("Status", value: model.helperInstalled ? "Installed" : "Not installed")
                Text("The helper lets you control the logo without repeated password prompts.")
                    .foregroundStyle(.secondary)

                Button("Remove Helper…", role: .destructive) {
                    confirmsRemoval = true
                }
                .disabled(!model.helperInstalled || model.isBusy)

                if model.isBusy {
                    ProgressView().controlSize(.small)
                }
            }

            Section("Keyboard shortcut") {
                LabeledContent("Toggle Logo Illumination", value: shortcuts.binding.label)
                HStack {
                    Button(shortcuts.isRecording ? "Cancel" : "Record Shortcut…") {
                        if shortcuts.isRecording {
                            shortcuts.stopRecording()
                        } else {
                            shortcuts.startRecording()
                        }
                    }
                    Button("Restore Default") { shortcuts.restoreDefault() }
                        .disabled(shortcuts.binding == .standard && !shortcuts.isRecording)
                }
                Text(shortcuts.isRecording || !shortcuts.message.isEmpty
                     ? shortcuts.message
                     : "Works in any app while NoLogo is running, even with its Dock icon hidden. Complete helper setup first.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .task { await model.refresh() }
        .onChange(of: showDockIcon) { _, show in
            NSApplication.shared.setActivationPolicy(show ? .regular : .accessory)
        }
        .onDisappear { shortcuts.stopRecording() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { shortcuts.stopRecording() }
        }
        .confirmationDialog("Remove the logo-control helper?", isPresented: $confirmsRemoval) {
            Button("Remove Helper", role: .destructive) {
                Task {
                    do { try await model.removeHelper() }
                    catch {
                        errorMessage = error.localizedDescription
                        showsError = true
                    }
                }
            }
        } message: {
            Text("macOS will ask for administrator approval. The logo’s current setting stays unchanged.")
        }
        .alert("Couldn’t Remove Helper", isPresented: $showsError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}
