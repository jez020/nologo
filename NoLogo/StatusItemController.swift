import AppKit
import Observation
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let model: LogoLightModel
    private let updates: UpdateManager
    private let shortcuts: ShortcutSettings
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?

    init(
        model: LogoLightModel = .shared,
        updates: UpdateManager = .shared,
        shortcuts: ShortcutSettings = .shared
    ) {
        self.model = model
        self.updates = updates
        self.shortcuts = shortcuts
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleStatusItemClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Left-click to toggle the logo light. Right-click for options."
        }

        observeModel()
    }

    @objc private func handleStatusItemClick() {
        if NSApplication.shared.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            toggleLight()
        }
    }

    private func observeModel() {
        withObservationTracking {
            _ = model.isEnabled
            _ = model.isBusy
            _ = model.helperInstalled
            _ = model.supported
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeModel()
            }
        }

        updateStatusIcon()
    }

    private func updateStatusIcon() {
        let symbolName = model.isEnabled == true ? "lightbulb.fill" : "lightbulb"
        statusItem.button?.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "NoLogo"
        )
    }

    private func showMenu() {
        let menu = NSMenu()

        let stateItem = NSMenuItem(title: stateTitle, action: nil, keyEquivalent: "")
        stateItem.image = NSImage(
            systemSymbolName: model.isEnabled == true ? "lightbulb.fill" : "lightbulb",
            accessibilityDescription: nil
        )
        menu.addItem(stateItem)
        menu.addItem(.separator())

        let onItem = menuItem(
            title: "Turn Logo Light On",
            action: #selector(turnLightOn),
            symbolName: "lightbulb.fill"
        )
        onItem.isEnabled = canControlLight && model.isEnabled != true
        menu.addItem(onItem)

        let offItem = menuItem(
            title: "Turn Logo Light Off",
            action: #selector(turnLightOff),
            symbolName: "lightbulb"
        )
        offItem.isEnabled = canControlLight && model.isEnabled != false
        menu.addItem(offItem)

        let toggleItem = menuItem(
            title: "Toggle Logo Light",
            action: #selector(toggleLight),
            symbolName: "lightbulb.min"
        )
        toggleItem.isEnabled = canControlLight && !shortcuts.isRecording
        menu.addItem(toggleItem)

        let shortcutItem = NSMenuItem(
            title: "Keyboard Shortcut: \(shortcuts.binding.label)",
            action: nil,
            keyEquivalent: ""
        )
        shortcutItem.isEnabled = false
        menu.addItem(shortcutItem)
        menu.addItem(.separator())

        menu.addItem(menuItem(
            title: "Open NoLogo",
            action: #selector(openMainWindow),
            symbolName: "macwindow"
        ))
        menu.addItem(menuItem(
            title: "Settings…",
            action: #selector(openSettingsWindow),
            symbolName: "gearshape"
        ))

        let updateItem = menuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates),
            symbolName: "arrow.trianglehead.2.clockwise.rotate.90"
        )
        updateItem.isEnabled = updates.canCheckForUpdates
        menu.addItem(updateItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit NoLogo",
            action: #selector(quit),
            keyEquivalent: "q"
        ))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private var canControlLight: Bool {
        model.supported && model.helperInstalled && model.isEnabled != nil && !model.isBusy
    }

    private var stateTitle: String {
        guard model.supported else { return "Logo Light: Unsupported Mac" }
        guard model.helperInstalled else { return "Logo Light: Setup Required" }
        guard let isEnabled = model.isEnabled else { return "Logo Light: Unavailable" }
        return isEnabled ? "Logo Light: On" : "Logo Light: Off"
    }

    private func menuItem(title: String, action: Selector, symbolName: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        return item
    }

    @objc private func toggleLight() {
        performLightChange { model in
            _ = try await model.toggle()
        }
    }

    @objc private func turnLightOn() {
        performLightChange { model in
            try await model.setEnabled(true)
        }
    }

    @objc private func turnLightOff() {
        performLightChange { model in
            try await model.setEnabled(false)
        }
    }

    private func performLightChange(
        _ action: @escaping @MainActor (LogoLightModel) async throws -> Void
    ) {
        Task { @MainActor in
            do {
                try await action(model)
            } catch {
                NSApplication.shared.presentError(error)
            }
        }
    }

    @objc private func openMainWindow() {
        NSApplication.shared.activate()

        if let window = NSApplication.shared.windows.first(where: { $0.title == "NoLogo" }) {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "NoLogo"
        window.contentViewController = NSHostingController(rootView: ContentView(model: model))
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        mainWindow = window
    }

    @objc private func openSettingsWindow() {
        NSApplication.shared.activate()

        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 620),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "NoLogo Settings"
        window.contentViewController = NSHostingController(rootView: SettingsView(model: model))
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        settingsWindow = window
    }

    @objc private func checkForUpdates() {
        updates.checkForUpdates()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
