import Foundation

@MainActor
enum DebugEventLogger {
    struct Event: Encodable {
        let timestamp: Date
        let category: String
        let action: String
        let outcome: String
        let detail: String?
    }

    private static let maximumEventCount = 100
    private(set) static var events: [Event] = []

    static func record(
        category: String,
        action: String,
        outcome: String,
        detail: String? = nil
    ) {
        events.append(Event(
            timestamp: Date(),
            category: category,
            action: action,
            outcome: outcome,
            detail: detail
        ))

        if events.count > maximumEventCount {
            events.removeFirst(events.count - maximumEventCount)
        }
    }

    static func sanitizedErrorCategory(for error: Error) -> String {
        if case LogoLightController.ControlError.cancelled = error {
            return "cancelled"
        }
        if error is LogoLightController.ControlError {
            return "logo_control_error"
        }
        return "system_error"
    }
}
