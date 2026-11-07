import Foundation

@MainActor
enum LogoLightController {
    enum ControlError: LocalizedError {
        case failed(String)
        case cancelled

        var errorDescription: String? {
            switch self {
            case .failed(let message): return message
            case .cancelled: return "Cancelled. No change was made."
            }
        }
    }

    static var isInstalled: Bool {
        // Either artifact must remain removable after a partial installation.
        FileManager.default.fileExists(atPath: LogoLightHelperConfiguration.installationDirectory)
            || FileManager.default.fileExists(atPath: LogoLightHelperConfiguration.launchDaemonPath)
    }

    static func checkConnection() async throws {
        _ = try await request(operation: .check)
    }

    static func readEnabled() async throws -> Bool {
        try await request(operation: .read)
    }

    static func toggle() async throws -> Bool {
        try await checkConnection()
        return try await request(operation: .toggle)
    }

    private enum Operation { case check, read, toggle }

    private static func request(operation: Operation) async throws -> Bool {
        guard DeviceCompatibility.isSupported else {
            throw ControlError.failed(DeviceCompatibility.unsupportedMessage)
        }
        let connection = NSXPCConnection(
            machServiceName: LogoLightHelperConfiguration.serviceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(with: LogoLightHelperProtocol.self)
        connection.setCodeSigningRequirement(LogoLightHelperConfiguration.signingRequirement)
        connection.resume()
        defer { connection.invalidate() }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            let pending = HelperReply(continuation: continuation)
            connection.invalidationHandler = {
                Task { @MainActor in
                    pending.finish(.failure(ControlError.failed("The helper disconnected. Try setting it up again.")))
                }
            }
            connection.interruptionHandler = {
                Task { @MainActor in
                    pending.finish(.failure(ControlError.failed("The helper was interrupted. Try again.")))
                }
            }
            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                Task { @MainActor in pending.finish(.failure(error)) }
            } as? LogoLightHelperProtocol
            guard let proxy else {
                pending.finish(.failure(ControlError.failed("Couldn’t connect to the helper.")))
                return
            }
            pending.timeout = Task { @MainActor in
                do {
                    try await Task.sleep(for: .seconds(10))
                    pending.finish(.failure(ControlError.failed("The helper didn’t respond. Remove it and run setup again.")))
                } catch { }
            }
            switch operation {
            case .read, .toggle:
                let reply: (Bool, String?) -> Void = { enabled, message in
                    Task { @MainActor in
                        pending.finish(message.map { .failure(ControlError.failed($0)) } ?? .success(enabled))
                    }
                }
                if operation == .read {
                    proxy.readEnabled(reply: reply)
                } else {
                    proxy.toggle(reply: reply)
                }
            case .check:
                proxy.ping { version in
                    Task { @MainActor in
                        pending.finish(version == LogoLightHelperConfiguration.protocolVersion
                            ? .success(true)
                            : .failure(ControlError.failed("The installed helper needs updating. Remove it and run setup again.")))
                    }
                }
            }
        }
    }

    static func install() async throws {
        guard DeviceCompatibility.isSupported else {
            throw ControlError.failed(DeviceCompatibility.unsupportedMessage)
        }
        try await authorize(installationCommand())
        try await checkConnection()
    }

    static func installationCommand() throws -> String {
        guard let executableName = Bundle.main.executableURL?.lastPathComponent else {
            throw ControlError.failed("Couldn’t locate this app’s executable.")
        }
        let destination = LogoLightHelperConfiguration.installationDirectory
        let executable = destination + "/Helper.app/Contents/MacOS/" + executableName
        let daemon: [String: Any] = [
            "Label": LogoLightHelperConfiguration.serviceName,
            "ProgramArguments": [executable, "--logo-light-helper"],
            "MachServices": [LogoLightHelperConfiguration.serviceName: true],
            "UserName": "root",
            "EnvironmentVariables": ["HOME": "/var/root", "USER": "root"],
            "AssociatedBundleIdentifiers": ["com.jez020.nologo"]
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: daemon, format: .xml, options: 0)
        let plist = String(decoding: plistData, as: UTF8.self)

        // Stage in a root-owned directory and verify the copied signature before
        // launchd can execute anything. Never execute code from a user-writable path.
        let script = """
        set -eu
        destination=\(shellQuote(destination))
        plist_path=\(shellQuote(LogoLightHelperConfiguration.launchDaemonPath))
        if [ -e "$destination" ] || [ -e "$plist_path" ]; then
            echo 'A helper is already installed. Remove Helper, then run setup again.' >&2
            exit 1
        fi
        /usr/bin/install -d -o root -g wheel -m 755 /Library/PrivilegedHelperTools /Library/LaunchDaemons
        staging=$(/usr/bin/mktemp -d /Library/PrivilegedHelperTools/.logo-light.XXXXXX)
        published=0
        cleanup() {
            /bin/rm -rf "$staging"
            if [ "$published" = 1 ]; then
                /bin/rm -rf "$destination"
                /bin/rm -f "$plist_path"
            fi
        }
        trap cleanup EXIT
        /usr/bin/ditto \(shellQuote(Bundle.main.bundlePath)) "$staging/Helper.app"
        /usr/bin/codesign --verify --deep --strict -R \(shellQuote("=" + LogoLightHelperConfiguration.signingRequirement)) "$staging/Helper.app"
        /usr/sbin/chown -R root:wheel "$staging"
        /bin/chmod -R go-w "$staging"
        /bin/chmod 755 "$staging"
        /bin/mv "$staging" "$destination"
        published=1
        /usr/bin/printf '%s' \(shellQuote(plist)) > "$plist_path"
        /usr/sbin/chown root:wheel "$plist_path"
        /bin/chmod 644 "$plist_path"
        /bin/launchctl bootstrap system "$plist_path"
        published=0
        """
        return script
    }

    static func uninstall() async throws {
        let script = """
        set -eu
        if /bin/launchctl print system/\(LogoLightHelperConfiguration.serviceName) >/dev/null 2>&1; then
            /bin/launchctl bootout system/\(LogoLightHelperConfiguration.serviceName)
        fi
        /bin/rm -f \(shellQuote(LogoLightHelperConfiguration.launchDaemonPath))
        /bin/rm -rf \(shellQuote(LogoLightHelperConfiguration.installationDirectory))
        """
        try await authorize(script)
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func authorize(_ command: String) async throws {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        let script = """
        try
            do shell script "\(escaped)" with administrator privileges
            return "completed"
        on error errorMessage number errorNumber
            if errorNumber is -128 then
                return "cancelled"
            end if
            error errorMessage number errorNumber
        end try
        """
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // Drain output while osascript is running; waiting for termination first
            // can deadlock when an installation error fills the pipe.
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let output = Pipe()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", script]
                process.standardOutput = output
                process.standardError = output
                do {
                    try process.run()
                    let data = output.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    let message = String(decoding: data, as: UTF8.self)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if process.terminationStatus != 0 {
                        continuation.resume(throwing: ControlError.failed(message))
                    } else if message == "cancelled" {
                        continuation.resume(throwing: ControlError.cancelled)
                    } else {
                        continuation.resume()
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// XPC reply, error, timeout, and invalidation can race. Resume exactly once.
@MainActor
private final class HelperReply {
    private var continuation: CheckedContinuation<Bool, Error>?
    var timeout: Task<Void, Never>?

    init(continuation: CheckedContinuation<Bool, Error>) {
        self.continuation = continuation
    }

    func finish(_ result: Result<Bool, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        timeout?.cancel()
        timeout = nil
        continuation.resume(with: result)
    }
}
