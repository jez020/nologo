import Foundation
import Observation

@MainActor
@Observable
final class LogoLightModel {
    static let shared = LogoLightModel()

    private(set) var isBusy = false
    private(set) var isEnabled: Bool?
    private(set) var helperInstalled = LogoLightController.isInstalled
    private(set) var status = "Checking this Mac…"
    let supported = DeviceCompatibility.isSupported

    var buttonTitle: String {
        if !supported { return "Unsupported Mac" }
        if !helperInstalled { return "Set Up Logo Control" }
        guard let isEnabled else { return "Retry Connection" }
        return isEnabled ? "Turn Light Off" : "Turn Light On"
    }

    func refresh() async {
        guard !isBusy else { return }
        DebugEventLogger.record(category: "logo_control", action: "refresh", outcome: "started")
        isBusy = true
        defer { isBusy = false }
        helperInstalled = LogoLightController.isInstalled
        guard supported else {
            isEnabled = nil
            status = DeviceCompatibility.unsupportedMessage
            DebugEventLogger.record(category: "logo_control", action: "refresh", outcome: "unsupported")
            return
        }
        guard helperInstalled else {
            isEnabled = nil
            status = "Approve setup once to control the logo light."
            DebugEventLogger.record(category: "logo_control", action: "refresh", outcome: "helper_missing")
            return
        }
        do {
            try await LogoLightController.checkConnection()
            updateState(try await LogoLightController.readEnabled())
            DebugEventLogger.record(category: "logo_control", action: "refresh", outcome: "succeeded")
        } catch {
            isEnabled = nil
            status = "Couldn’t connect. Open Settings to remove the old helper, then set up again."
            DebugEventLogger.record(
                category: "logo_control",
                action: "refresh",
                outcome: "failed",
                detail: DebugEventLogger.sanitizedErrorCategory(for: error)
            )
        }
    }

    func primaryAction() async throws {
        guard !isBusy else { return }
        if helperInstalled && isEnabled != nil {
            _ = try await toggle()
        } else if helperInstalled {
            await refresh()
        } else {
            guard supported else {
                throw LogoLightController.ControlError.failed(DeviceCompatibility.unsupportedMessage)
            }
            isBusy = true
            defer {
                helperInstalled = LogoLightController.isInstalled
                isBusy = false
            }
            do {
                status = "Waiting for setup approval…"
                DebugEventLogger.record(category: "helper", action: "install", outcome: "started")
                try await LogoLightController.install()
                updateState(try await LogoLightController.readEnabled())
                DebugEventLogger.record(category: "helper", action: "install", outcome: "succeeded")
            } catch {
                status = "Setup did not complete."
                DebugEventLogger.record(
                    category: "helper",
                    action: "install",
                    outcome: "failed",
                    detail: DebugEventLogger.sanitizedErrorCategory(for: error)
                )
                throw error
            }
        }
    }

    // All entry points share busy handling and update the visible state.
    func toggle() async throws -> Bool {
        try await changeSetting(to: nil)
    }

    func setEnabled(_ enabled: Bool) async throws {
        _ = try await changeSetting(to: enabled)
    }

    private func changeSetting(to requested: Bool?) async throws -> Bool {
        guard supported else {
            throw LogoLightController.ControlError.failed(DeviceCompatibility.unsupportedMessage)
        }
        guard !isBusy else {
            throw LogoLightController.ControlError.failed("NoLogo is busy. Try again in a moment.")
        }
        helperInstalled = LogoLightController.isInstalled
        guard helperInstalled else {
            throw LogoLightController.ControlError.failed("Open NoLogo and complete setup before controlling the light.")
        }
        isBusy = true
        let action = requested == nil ? "toggle" : "set"
        DebugEventLogger.record(category: "logo_control", action: action, outcome: "started")
        defer { isBusy = false }
        do {
            status = "Changing logo illumination…"
            let enabled: Bool
            if let requested {
                enabled = try await LogoLightController.setEnabled(requested)
            } else {
                enabled = try await LogoLightController.toggle()
            }
            updateState(enabled)
            DebugEventLogger.record(
                category: "logo_control",
                action: action,
                outcome: "succeeded",
                detail: enabled ? "on" : "off"
            )
            return enabled
        } catch {
            isEnabled = nil
            status = "Couldn’t confirm the light’s setting. Retry the connection."
            DebugEventLogger.record(
                category: "logo_control",
                action: action,
                outcome: "failed",
                detail: DebugEventLogger.sanitizedErrorCategory(for: error)
            )
            throw error
        }
    }

    func removeHelper() async throws {
        guard !isBusy else { return }
        DebugEventLogger.record(category: "helper", action: "remove", outcome: "started")
        isBusy = true
        defer {
            helperInstalled = LogoLightController.isInstalled
            isBusy = false
        }
        do {
            try await LogoLightController.uninstall()
            DebugEventLogger.record(category: "helper", action: "remove", outcome: "succeeded")
        } catch {
            DebugEventLogger.record(
                category: "helper",
                action: "remove",
                outcome: "failed",
                detail: DebugEventLogger.sanitizedErrorCategory(for: error)
            )
            throw error
        }
        isEnabled = nil
        status = supported ? "Approve setup once to control the logo light."
            : DeviceCompatibility.unsupportedMessage
    }

    private func updateState(_ enabled: Bool) {
        isEnabled = enabled
        status = enabled ? "Logo illumination is on." : "Logo illumination is off."
    }
}
