import AppKit
import ApplicationServices
import CoreGraphics
import Observation

@MainActor
@Observable
final class KeyboardCleaningModel {
    enum State: Equatable {
        case unlocked
        case locked
        case permissionRequired
        case failed(String)
    }

    private(set) var state: State = .unlocked
    private(set) var unlockProgress = 0.0
    private(set) var leftCommandPressed = false
    private(set) var rightCommandPressed = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var cursorHiddenByCleaning = false
    private var unlockTask: Task<Void, Never>?
    private var notificationObservers: [NSObjectProtocol] = []

    init() {
        observeAutomaticUnlockEvents()
    }

    var isLocked: Bool {
        state == .locked
    }

    var accessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    func lock() {
        guard !isLocked else { return }

        guard requestAccessibilityAccess() else {
            state = .permissionRequired
            return
        }

        let mask = Self.eventMask
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: keyboardCleaningEventCallback,
            userInfo: userInfo
        ) else {
            state = .failed("macOS did not allow input blocking. Confirm Accessibility access, then try again.")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        cursorHiddenByCleaning = CGDisplayHideCursor(CGMainDisplayID()) == .success
        resetUnlockGesture()
        state = .locked
    }

    func unlock() {
        unlockTask?.cancel()
        unlockTask = nil

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil

        if cursorHiddenByCleaning {
            CGDisplayShowCursor(CGMainDisplayID())
            cursorHiddenByCleaning = false
        }

        resetUnlockGesture()
        state = .unlocked
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    fileprivate func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard isLocked else {
            return Unmanaged.passUnretained(event)
        }

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return nil
        }

        if type == .flagsChanged {
            updateCommandState(for: event)
        }

        return nil
    }

    private func updateCommandState(for event: CGEvent) {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        // The tap suppresses this event before the session key-state API
        // observes it, so track each physical modifier transition directly.
        switch keyCode {
        case 55:
            leftCommandPressed.toggle()
        case 54:
            rightCommandPressed.toggle()
        default:
            return
        }

        if leftCommandPressed && rightCommandPressed {
            beginUnlockCountdown()
        } else {
            cancelUnlockCountdown()
        }
    }

    private func beginUnlockCountdown() {
        guard unlockTask == nil else { return }

        unlockTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let clock = ContinuousClock()
            let start = clock.now
            let duration = Duration.seconds(3)

            while !Task.isCancelled,
                  self.leftCommandPressed,
                  self.rightCommandPressed {
                let elapsed = start.duration(to: clock.now)
                let components = elapsed.components
                let elapsedSeconds = Double(components.seconds)
                    + Double(components.attoseconds) / 1_000_000_000_000_000_000
                self.unlockProgress = min(1, elapsedSeconds / 3)

                if elapsed >= duration {
                    self.unlock()
                    return
                }

                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func cancelUnlockCountdown() {
        unlockTask?.cancel()
        unlockTask = nil
        unlockProgress = 0
    }

    private func resetUnlockGesture() {
        leftCommandPressed = false
        rightCommandPressed = false
        unlockProgress = 0
    }

    private func requestAccessibilityAccess() -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func observeAutomaticUnlockEvents() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let workspaceNames: [Notification.Name] = [
            NSWorkspace.sessionDidResignActiveNotification,
            NSWorkspace.screensDidSleepNotification,
            NSWorkspace.willSleepNotification
        ]

        notificationObservers = workspaceNames.map { name in
            workspaceCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.unlock()
                }
            }
        }
    }

    // Capture every event type the session event stream exposes so
    // touch-derived gestures and system-defined controls are suppressed too.
    private static let eventMask = CGEventMask.max
}

nonisolated private func keyboardCleaningEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let model = Unmanaged<KeyboardCleaningModel>
        .fromOpaque(userInfo)
        .takeUnretainedValue()

    return MainActor.assumeIsolated {
        model.handleEvent(type: type, event: event)
    }
}
