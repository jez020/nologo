import SwiftUI
import AppKit

@main
enum AppEntry {
    static func main() {
        if CommandLine.arguments.contains("--logo-light-helper") {
            LogoLightHelper.run()
        } else {
            MyApp.main()
        }
    }
}

struct MyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = LogoLightModel.shared
    @State private var updates = UpdateManager.shared
    @State private var shortcuts = ShortcutSettings.shared

    var body: some Scene {
        WindowGroup("Logo Light", id: "main") {
            ContentView(model: model)
        }

        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { updates.checkForUpdates() }
                    .disabled(!updates.canCheckForUpdates)
            }
            CommandMenu("Light") {
                Button("Toggle Logo Light") {
                    Task {
                        do { _ = try await model.toggle() }
                        catch { NSApplication.shared.presentError(error) }
                    }
                }
                .disabled(!model.supported || !model.helperInstalled || model.isBusy || shortcuts.isRecording)
            }
        }

        Settings {
            SettingsView(model: model)
        }

        MenuBarExtra("Logo Light", systemImage: model.isEnabled == true ? "lightbulb.fill" : "lightbulb") {
            MenuBarContentView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
