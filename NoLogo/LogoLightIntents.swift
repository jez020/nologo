import AppIntents

struct TurnLogoLightOnIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn Logo Light On"
    static let description = IntentDescription("Turns on this Mac’s logo light. Complete setup in NoLogo first.")
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult {
        try await LogoLightIntentAction.setEnabled(true)
        return .result()
    }
}

struct TurnLogoLightOffIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn Logo Light Off"
    static let description = IntentDescription("Turns off this Mac’s logo light. Complete setup in NoLogo first.")
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult {
        try await LogoLightIntentAction.setEnabled(false)
        return .result()
    }
}

struct NoLogoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TurnLogoLightOnIntent(),
            phrases: ["Turn on the logo light with \(.applicationName)"],
            shortTitle: "Turn Logo Light On",
            systemImageName: "lightbulb.fill"
        )
        AppShortcut(
            intent: TurnLogoLightOffIntent(),
            phrases: ["Turn off the logo light with \(.applicationName)"],
            shortTitle: "Turn Logo Light Off",
            systemImageName: "lightbulb"
        )
    }
}

private enum LogoLightIntentAction {
    @MainActor
    static func setEnabled(_ enabled: Bool) async throws {
        do {
            try await LogoLightModel.shared.setEnabled(enabled)
        } catch {
            throw LogoLightIntentError(message: error.localizedDescription)
        }
    }
}

private struct LogoLightIntentError: Error, CustomLocalizedStringResourceConvertible {
    let message: String

    var localizedStringResource: LocalizedStringResource {
        "Couldn’t change the logo light: \(message)"
    }
}
