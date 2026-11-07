import SwiftUI
import AppKit
import Observation

@MainActor
@Observable
final class ShortcutSettings {
    static let shared = ShortcutSettings()
    private static let defaultsKey = "logoLight.keyboardShortcut"

    struct Binding: Codable, Equatable {
        var key: String
        var command: Bool
        var option: Bool
        var control: Bool
        var shift: Bool
        var keyCode: UInt16? = nil

        static let standard = Binding(key: "l", command: true, option: false, control: false, shift: true)

        var isValid: Bool {
            let allowed = "abcdefghijklmnopqrstuvwxyz0123456789"
            guard key.count == 1, allowed.contains(key), command || option || control else { return false }
            // Preserve common application and text-editing commands.
            if command && !option && !control {
                let reserved = shift ? ["z", "s", "w", "q"] : ["q", "w", "h", "m", "c", "v", "x", "a", "z", "s", "o", "n", "f"]
                if reserved.contains(key) { return false }
            }
            return true
        }

        var shortcut: KeyboardShortcut {
            var modifiers: EventModifiers = []
            if command { modifiers.insert(.command) }
            if option { modifiers.insert(.option) }
            if control { modifiers.insert(.control) }
            if shift { modifiers.insert(.shift) }
            return KeyboardShortcut(KeyEquivalent(Character(key)), modifiers: modifiers)
        }

        var label: String {
            (control ? "⌃" : "") + (option ? "⌥" : "") +
            (shift ? "⇧" : "") + (command ? "⌘" : "") + key.uppercased()
        }
    }

    private(set) var binding: Binding
    private(set) var isRecording = false
    private(set) var message = ""
    @ObservationIgnored private var monitor: Any?

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode(Binding.self, from: data),
           saved.isValid {
            binding = saved
        } else {
            binding = .standard
        }
    }

    func startRecording() {
        stopRecording()
        GlobalShortcut.shared.unregister()
        isRecording = true
        message = "Press a letter or number with Command, Option, or Control. Escape cancels."
        // Consume the event before menu commands run, so recording never toggles the light.
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, self.isRecording else { return event }
                if event.keyCode == 53 {
                    self.stopRecording()
                    return nil
                }
                guard !event.isARepeat else { return nil }
                let flags = event.modifierFlags
                let candidate = Binding(
                    // charactersIgnoringModifiers still applies Shift (for example, 1 becomes !).
                    key: event.characters(byApplyingModifiers: [])?.lowercased() ?? "",
                    command: flags.contains(.command),
                    option: flags.contains(.option),
                    control: flags.contains(.control),
                    shift: flags.contains(.shift),
                    keyCode: event.keyCode
                )
                guard candidate.isValid else {
                    self.message = "Choose a letter or number with Command, Option, or Control. Common app shortcuts are reserved."
                    return nil
                }
                self.stopRecording()
                self.save(candidate)
                return nil
            }
        }
        if monitor == nil {
            stopRecording()
            message = "Couldn’t start recording. Please try again."
        }
    }

    func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
        message = ""
        activateGlobalShortcut()
    }

    func activateGlobalShortcut() {
        if !GlobalShortcut.shared.register(binding) {
            message = "This shortcut is unavailable or used by another app. Record a different combination."
        }
    }

    func restoreDefault() {
        stopRecording()
        save(.standard)
    }

    private func save(_ value: Binding) {
        guard value.isValid, let data = try? JSONEncoder().encode(value) else { return }
        guard GlobalShortcut.shared.register(value) else {
            _ = GlobalShortcut.shared.register(binding)
            message = "That shortcut could not be registered. Your previous shortcut was kept."
            return
        }
        message = ""
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        binding = value
    }
}
