import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load the bundled icon directly so the Dock does not retain a cached placeholder.
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }
        UpdateManager.shared.start()
        ShortcutSettings.shared.activateGlobalShortcut()
        statusItemController = StatusItemController(
            model: .shared,
            updates: .shared,
            shortcuts: .shared
        )
        UserDefaults.standard.register(defaults: ["showDockIcon": true])
        let showDockIcon = UserDefaults.standard.bool(forKey: "showDockIcon")
        NSApplication.shared.setActivationPolicy(showDockIcon ? .regular : .accessory)
    }

    func applicationDidUpdate(_ notification: Notification) {
        guard let mainMenu = NSApplication.shared.mainMenu else { return }
        // SwiftUI can rebuild menus when window focus changes. Recheck after updates
        // and hide empty headings without removing SwiftUI's menu objects.
        for item in mainMenu.items.dropFirst() {
            guard let submenu = item.submenu else { continue }
            let isEmpty = !submenu.items.contains { !$0.isSeparatorItem && !$0.isHidden }
            if isEmpty && !item.isHidden {
                item.isHidden = true
                hiddenEmptyMenus.insert(ObjectIdentifier(item))
            } else if !isEmpty && hiddenEmptyMenus.remove(ObjectIdentifier(item)) != nil {
                item.isHidden = false
            }
        }
    }

    private var hiddenEmptyMenus: Set<ObjectIdentifier> = []

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
