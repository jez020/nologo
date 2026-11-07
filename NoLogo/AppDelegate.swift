import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var appearanceObservation: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ notification: Notification) {
        DebugEventLogger.record(category: "app", action: "launch", outcome: "started")
        refreshApplicationIcon()
        appearanceObservation = NSApplication.shared.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.refreshApplicationIcon()
            }
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

    private func refreshApplicationIcon() {
        // The debug launcher can show AppKit's generic placeholder even though the
        // compiled Icon Composer resource is valid. Resolve the bundle icon through
        // Launch Services and refresh it whenever the system appearance changes.
        NSApplication.shared.applicationIconImage = NSWorkspace.shared.icon(
            forFile: Bundle.main.bundlePath
        )
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
