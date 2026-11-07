import AppKit
import Foundation
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
enum DebugLogGenerator {
    private struct DebugLog: Encodable {
        let schemaVersion = 2
        let generatedAt: Date
        let app: AppDetails
        let system: SystemDetails
        let logoControl: LogoControlDetails
        let preferences: PreferenceDetails
        let updates: UpdateDetails
        let recentEvents: [DebugEventLogger.Event]
    }

    private struct AppDetails: Encodable {
        let version: String
        let build: String
        let buildConfiguration: String
        let activationPolicy: String
    }

    private struct SystemDetails: Encodable {
        let macOSVersion: String
        let architecture: String
        let modelIdentifier: String
        let isSupported: Bool
    }

    private struct LogoControlDetails: Encodable {
        let helperInstalled: Bool
        let helperDirectoryPresent: Bool
        let launchDaemonPresent: Bool
        let helperProtocolVersion: Int
        let connectionState: String
    }

    private struct PreferenceDetails: Encodable {
        let showsDockIcon: Bool
        let completedOnboarding: Bool
        let loginItemStatus: String
        let usesDefaultShortcut: Bool
    }

    private struct UpdateDetails: Encodable {
        let canCheckForUpdates: Bool
        let configurationState: String
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
                build: bundleValue(for: "CFBundleVersion"),
                buildConfiguration: buildConfiguration,
                activationPolicy: activationPolicy
            ),
            system: SystemDetails(
                macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                architecture: architecture,
                modelIdentifier: DeviceCompatibility.modelIdentifier ?? "unavailable",
                isSupported: model.supported
            ),
            logoControl: LogoControlDetails(
                helperInstalled: model.helperInstalled,
                helperDirectoryPresent: FileManager.default.fileExists(
                    atPath: LogoLightHelperConfiguration.installationDirectory
                ),
                launchDaemonPresent: FileManager.default.fileExists(
                    atPath: LogoLightHelperConfiguration.launchDaemonPath
                ),
                helperProtocolVersion: LogoLightHelperConfiguration.protocolVersion,
                connectionState: connectionState(for: model.isEnabled)
            ),
            preferences: PreferenceDetails(
                showsDockIcon: showsDockIcon,
                completedOnboarding: completedOnboarding,
                loginItemStatus: loginItemStatus,
                usesDefaultShortcut: usesDefaultShortcut
            ),
            updates: UpdateDetails(
                canCheckForUpdates: UpdateManager.shared.canCheckForUpdates,
                configurationState: UpdateManager.shared.configurationMessage == nil
                    ? "configured" : "unavailable"
            ),
            recentEvents: DebugEventLogger.events
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

    private static var loginItemStatus: String {
        switch SMAppService.mainApp.status {
        case .notRegistered: "not_registered"
        case .enabled: "enabled"
        case .requiresApproval: "requires_approval"
        case .notFound: "not_found"
        @unknown default: "unknown"
        }
    }

    private static var activationPolicy: String {
        switch NSApplication.shared.activationPolicy() {
        case .regular: "regular"
        case .accessory: "accessory"
        case .prohibited: "prohibited"
        @unknown default: "unknown"
        }
    }

    private static var buildConfiguration: String {
        #if DEBUG
        "debug"
        #else
        "release"
        #endif
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
