import AppKit
import Carbon

@MainActor
final class GlobalShortcut {
    static let shared = GlobalShortcut()
    private var handler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?

    func register(_ binding: ShortcutSettings.Binding) -> Bool {
        unregister()
        if handler == nil {
            var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let result = InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                Task { @MainActor in
                    guard !ShortcutSettings.shared.isRecording else { return }
                    do { _ = try await LogoLightModel.shared.toggle() }
                    catch {
                        NSApplication.shared.presentError(error)
                    }
                }
                return noErr
            }, 1, &type, nil, &handler)
            guard result == noErr else { return false }
        }
        guard let keyCode = binding.keyCode ?? Self.legacyKeyCodes[binding.key] else { return false }
        var modifiers: UInt32 = 0
        if binding.command { modifiers |= UInt32(cmdKey) }
        if binding.option { modifiers |= UInt32(optionKey) }
        if binding.control { modifiers |= UInt32(controlKey) }
        if binding.shift { modifiers |= UInt32(shiftKey) }
        let identifier = EventHotKeyID(signature: 0x4C4F474F, id: 1)
        return RegisterEventHotKey(UInt32(keyCode), modifiers, identifier,
                                   GetApplicationEventTarget(), 0, &hotKey) == noErr
    }

    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
    }

    // Migrate shortcuts saved before physical key codes were recorded.
    private static let legacyKeyCodes: [String: UInt16] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
        "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
        "5": 23, "9": 25, "7": 26, "8": 28, "0": 29, "o": 31, "u": 32,
        "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46
    ]
}
