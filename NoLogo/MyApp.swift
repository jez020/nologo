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
        WindowGroup("NoLogo", id: "main") {
            AppRootView(model: model)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            // NoLogo has no documents, editable content, toolbar, or sidebar.
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .saveItem) { }
            CommandGroup(replacing: .importExport) { }
            CommandGroup(replacing: .printItem) { }
            CommandGroup(replacing: .undoRedo) { }
            CommandGroup(replacing: .pasteboard) { }
            CommandGroup(replacing: .textEditing) { }
            CommandGroup(replacing: .textFormatting) { }
            CommandGroup(replacing: .toolbar) { }
            CommandGroup(replacing: .sidebar) { }
            CommandGroup(replacing: .windowArrangement) { }
            CommandGroup(replacing: .help) { }

            CommandGroup(replacing: .appInfo) {
                Button("About NoLogo") {
                    var options: [NSApplication.AboutPanelOptionKey: Any] = [:]
                    if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
                       let icon = NSImage(contentsOf: iconURL) {
                        options[.applicationIcon] = icon
                    }
                    NSApplication.shared.orderFrontStandardAboutPanel(options: options)
                }
            }
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { updates.checkForUpdates() }
                    .disabled(!updates.canCheckForUpdates)
            }
            CommandMenu("Light") {
                Button("Toggle Logo Illumination") {
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
        .windowResizability(.contentSize)
    }
}
