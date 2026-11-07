import SwiftUI
import AppKit

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
            Section("Updates") {
                Button("Check for Updates…") { updates.checkForUpdates() }
                    .disabled(!updates.canCheckForUpdates)
                if let message = updates.configurationMessage {
                    Text(message).foregroundStyle(.secondary)
                }
            }

            Section("App appearance") {
                Toggle("Show in Dock", isOn: $showDockIcon)
                Text("When hidden, use the menu bar lightbulb to open Logo Light, access Settings, or quit.")
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
                LabeledContent("Toggle Logo Light", value: shortcuts.binding.label)
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
                     : "Works in any app while Logo Light is running, even with its Dock icon hidden. Complete helper setup first.")
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
