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
        isBusy = true
        defer { isBusy = false }
        helperInstalled = LogoLightController.isInstalled
        guard supported else {
            isEnabled = nil
            status = DeviceCompatibility.unsupportedMessage
            return
        }
        guard helperInstalled else {
            isEnabled = nil
            status = "Approve setup once to control the logo light."
            return
        }
        do {
            try await LogoLightController.checkConnection()
            updateState(try await LogoLightController.readEnabled())
        } catch {
            isEnabled = nil
            status = "Couldn’t connect. Open Settings to remove the old helper, then set up again."
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
                try await LogoLightController.install()
                updateState(try await LogoLightController.readEnabled())
            } catch {
                status = "Setup did not complete."
                throw error
            }
        }
    }

    // Shared by the button and keyboard command. Never request setup from a toggle.
    func toggle() async throws -> Bool {
        guard supported else {
            throw LogoLightController.ControlError.failed(DeviceCompatibility.unsupportedMessage)
        }
        guard !isBusy else {
            throw LogoLightController.ControlError.failed("Logo Light is busy. Try again in a moment.")
        }
        helperInstalled = LogoLightController.isInstalled
        guard helperInstalled else {
            throw LogoLightController.ControlError.failed("Open Logo Light and complete setup before toggling the light.")
        }
        isBusy = true
        defer { isBusy = false }
        do {
            status = "Changing logo illumination…"
            let enabled = try await LogoLightController.toggle()
            updateState(enabled)
            return enabled
        } catch {
            isEnabled = nil
            status = "Couldn’t confirm the light’s setting. Retry the connection."
            throw error
        }
    }

    func removeHelper() async throws {
        guard !isBusy else { return }
        isBusy = true
        defer {
            helperInstalled = LogoLightController.isInstalled
            isBusy = false
        }
        try await LogoLightController.uninstall()
        isEnabled = nil
        status = supported ? "Approve setup once to control the logo light."
            : DeviceCompatibility.unsupportedMessage
    }

    private func updateState(_ enabled: Bool) {
        isEnabled = enabled
        status = enabled ? "Logo illumination is on." : "Logo illumination is off."
    }
}
