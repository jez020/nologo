import AppKit
import Foundation
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
enum DebugLogGenerator {
    private struct DebugLog: Encodable {
        let schemaVersion = 1
        let generatedAt: Date
        let app: AppDetails
        let system: SystemDetails
        let logoControl: LogoControlDetails
        let preferences: PreferenceDetails
    }

    private struct AppDetails: Encodable {
        let version: String
        let build: String
    }

    private struct SystemDetails: Encodable {
        let macOSVersion: String
        let architecture: String
        let modelIdentifier: String
        let isSupported: Bool
    }

    private struct LogoControlDetails: Encodable {
        let helperInstalled: Bool
        let connectionState: String
    }

    private struct PreferenceDetails: Encodable {
        let showsDockIcon: Bool
        let completedOnboarding: Bool
        let opensAtLogin: Bool
        let usesDefaultShortcut: Bool
    }

    static func save(
        model: LogoLightModel,
        showsDockIcon: Bool,
        completedOnboarding: Bool,
        usesDefaultShortcut: Bool
    ) throws -> Bool {
        let log = DebugLog(
            generatedAt: Date(),
            app: AppDetails(
                version: bundleValue(for: "CFBundleShortVersionString"),
                build: bundleValue(for: "CFBundleVersion")
            ),
            system: SystemDetails(
                macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                architecture: architecture,
                modelIdentifier: DeviceCompatibility.modelIdentifier ?? "unavailable",
                isSupported: model.supported
            ),
            logoControl: LogoControlDetails(
                helperInstalled: model.helperInstalled,
                connectionState: connectionState(for: model.isEnabled)
            ),
            preferences: PreferenceDetails(
                showsDockIcon: showsDockIcon,
                completedOnboarding: completedOnboarding,
                opensAtLogin: SMAppService.mainApp.status == .enabled,
                usesDefaultShortcut: usesDefaultShortcut
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(log)

        let panel = NSSavePanel()
        panel.title = "Save Debug Log"
        panel.prompt = "Save"
        panel.message = "This log contains technical app and system state only. It excludes names, paths, serial numbers, network data, and shortcut keys."
        panel.nameFieldStringValue = "NoLogo-Debug-Log.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let destination = panel.url else {
            return false
        }
        try data.write(to: destination, options: .atomic)
        return true
    }

    private static func bundleValue(for key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "unavailable"
    }

    private static func connectionState(for isEnabled: Bool?) -> String {
        switch isEnabled {
        case true: "connected_on"
        case false: "connected_off"
        case nil: "unavailable"
        }
    }

    private static var architecture: String {
        #if arch(arm64)
        "arm64"
        #elseif arch(x86_64)
        "x86_64"
        #else
        "unknown"
        #endif
    }
}
