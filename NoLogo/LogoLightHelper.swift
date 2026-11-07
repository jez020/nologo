import Foundation

@objc protocol LogoLightHelperProtocol {
    func ping(reply: @escaping (Int) -> Void)
    func readEnabled(reply: @escaping (Bool, String?) -> Void)
    func toggle(reply: @escaping (Bool, String?) -> Void)
}

enum LogoLightHelperConfiguration {
    static let serviceName = "com.jez020.nologo.helper"
    static let installationDirectory = "/Library/PrivilegedHelperTools/com.jez020.nologo.helper"
    static let launchDaemonPath = "/Library/LaunchDaemons/com.jez020.nologo.helper.plist"
    static let protocolVersion = 2

    // Both peers must be this app, signed by this project's development team.
    // Update this requirement if the app's bundle identifier or signing team changes.
    static let signingRequirement = """
    anchor apple generic and identifier "com.jez020.nologo" and certificate leaf[subject.OU] = "GF5ZH9C37W"
    """
}

final class LogoLightHelper: NSObject, NSXPCListenerDelegate, LogoLightHelperProtocol {
    private let commandQueue = DispatchQueue(label: "com.jez020.nologo.helper.commands")

    static func run() -> Never {
        guard geteuid() == 0 else { exit(EXIT_FAILURE) }
        let helper = LogoLightHelper()
        let listener = NSXPCListener(machServiceName: LogoLightHelperConfiguration.serviceName)
        listener.setConnectionCodeSigningRequirement(LogoLightHelperConfiguration.signingRequirement)
        listener.delegate = helper
        listener.resume()
        withExtendedLifetime((helper, listener)) {
            RunLoop.current.run()
        }
        exit(EXIT_SUCCESS)
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: LogoLightHelperProtocol.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    func ping(reply: @escaping (Int) -> Void) {
        reply(LogoLightHelperConfiguration.protocolVersion)
    }

    func readEnabled(reply: @escaping (Bool, String?) -> Void) {
        commandQueue.async {
            do { reply(try Self.currentSetting(), nil) }
            catch { reply(false, error.localizedDescription) }
        }
    }

    func toggle(reply: @escaping (Bool, String?) -> Void) {
        commandQueue.async {
            do {
                let enabled = try !Self.currentSetting()
                let process = Process()
                let output = Pipe()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
                process.arguments = enabled
                    ? ["delete", "com.apple.CoreBrightness", "LEBacklightMode"]
                    : ["write", "com.apple.CoreBrightness", "LEBacklightMode", "-int", "0"]
                process.environment = ["HOME": "/var/root", "USER": "root", "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
                process.standardOutput = output
                process.standardError = output
                try process.run()
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else {
                    throw NSError(domain: "LogoLight", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: String(decoding: data, as: UTF8.self)
                    ])
                }
                let actual = try Self.currentSetting()
                guard actual == enabled else {
                    throw NSError(domain: "LogoLight", code: 2, userInfo: [
                        NSLocalizedDescriptionKey: "The logo setting did not change. Please try again."
                    ])
                }
                reply(actual, nil)
            } catch {
                reply(false, error.localizedDescription)
            }
        }
    }

    private static func currentSetting() throws -> Bool {
        guard DeviceCompatibility.isSupported else {
            throw NSError(domain: "LogoLight", code: 3, userInfo: [
                NSLocalizedDescriptionKey: DeviceCompatibility.unsupportedMessage
            ])
        }
        let domain = "com.apple.CoreBrightness" as CFString
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
            throw NSError(domain: "LogoLight", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Couldn’t read the current logo setting."
            ])
        }
        let value = CFPreferencesCopyValue(
            "LEBacklightMode" as CFString, domain,
            kCFPreferencesCurrentUser, kCFPreferencesAnyHost
        )
        guard let value else { return true }
        guard let mode = value as? NSNumber, mode.intValue == 0 else {
            throw NSError(domain: "LogoLight", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "The logo has an unrecognized illumination mode."
            ])
        }
        return false
    }
}
