import Foundation

enum DeviceCompatibility {
    // PROLED XDR models released in November 2026.
    // Source: https://appledb.dev/device-selection/MacBook-Pro.html
    // Keep an explicit allowlist: newer identifiers do not imply logo-light support.
    static let supportedModels: Set<String> = [
        "Mac17,10", "Mac17,12", // 16-inch
        "Mac17,11", "Mac17,13"  // 14-inch
    ]

    static func supportsLogoLight(modelIdentifier: String?) -> Bool {
        guard let modelIdentifier else { return false }
        return supportedModels.contains(modelIdentifier)
    }

    static var modelIdentifier: String? {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 1 else { return nil }
        var bytes = [UInt8](repeating: 0, count: size)
        let result = bytes.withUnsafeMutableBytes {
            sysctlbyname("hw.model", $0.baseAddress, &size, nil, 0)
        }
        guard result == 0 else { return nil }
        return String(bytes: bytes.prefix { $0 != 0 }, encoding: .utf8)
    }

    static var isSupported: Bool {
        supportsLogoLight(modelIdentifier: modelIdentifier)
    }

    static let unsupportedMessage = "Logo Light requires a supported MacBook Pro with a PROLED XDR display."
}
