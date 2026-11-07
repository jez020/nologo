import AppKit
import Observation
#if canImport(Sparkle)
import Sparkle
#elseif !DEBUG
#error("Add the Sparkle package product to NoLogo before building a release.")
#endif

@MainActor
@Observable
final class UpdateManager {
    static let shared = UpdateManager()

    private(set) var canCheckForUpdates = false
    private(set) var configurationMessage: String?
    #if canImport(Sparkle)
    @ObservationIgnored private var controller: SPUStandardUpdaterController?
    @ObservationIgnored private var observation: NSKeyValueObservation?

    #endif

    func start() {
        #if canImport(Sparkle)
        guard controller == nil else { return }
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              Data(base64Encoded: key)?.count == 32 else {
            configurationMessage = "Updates are not configured for this build."
            return
        }

        let controller = SPUStandardUpdaterController(
            startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil
        )
        self.controller = controller
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { _, change in
            let enabled = change.newValue ?? false
            Task { @MainActor [weak self] in
                self?.canCheckForUpdates = enabled
            }
        }
        controller.startUpdater()
        #else
        configurationMessage = "Updates require the Sparkle package in this development build."
        #endif
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        NSApplication.shared.activate()
        #if canImport(Sparkle)
        controller?.checkForUpdates(nil)
        #endif
    }
}
