import SwiftUI

struct KeyboardCleaningView: View {
    let model: KeyboardCleaningModel

    var body: some View {
        VStack(spacing: 28) {
            KeyboardCleaningHeader(isLocked: model.isLocked)

            if model.isLocked {
                KeyboardCleaningLockedPanel(
                    progress: model.unlockProgress,
                    leftCommandPressed: model.leftCommandPressed,
                    rightCommandPressed: model.rightCommandPressed
                )
            } else {
                KeyboardCleaningSetupPanel(
                    state: model.state,
                    accessibilityGranted: model.accessibilityGranted,
                    lock: model.lock,
                    openAccessibilitySettings: model.openAccessibilitySettings
                )
            }

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: 640, maxHeight: .infinity, alignment: .top)
        .frame(maxWidth: .infinity)
        .navigationTitle("Keyboard Cleaning")
    }
}

private struct KeyboardCleaningHeader: View {
    let isLocked: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isLocked ? "lock.fill" : "keyboard")
                .font(.system(.largeTitle, design: .rounded, weight: .medium))
                .foregroundStyle(isLocked ? Color.orange : Color.accentColor)
                .accessibilityHidden(true)

            Text(isLocked ? "Input Locked" : "Keyboard Cleaning")
                .font(.largeTitle.bold())

            Text(
                isLocked
                    ? "Your keyboard and pointing devices are temporarily disabled."
                    : "Temporarily disable input while you clean your Mac."
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
    }
}

private struct KeyboardCleaningLockedPanel: View {
    let progress: Double
    let leftCommandPressed: Bool
    let rightCommandPressed: Bool

    var body: some View {
        VStack(spacing: 18) {
            Text("Hold both Command keys for 3 seconds to unlock.")
                .font(.headline)

            HStack(spacing: 16) {
                CommandKeyIndicator(title: "Left ⌘", isPressed: leftCommandPressed)
                CommandKeyIndicator(title: "Right ⌘", isPressed: rightCommandPressed)
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(maxWidth: 360)

            Text("Input also unlocks automatically when the display sleeps or your session signs out.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: 460)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct CommandKeyIndicator: View {
    let title: LocalizedStringResource
    let isPressed: Bool

    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(minWidth: 120)
            .background(
                isPressed ? Color.accentColor : Color.secondary.opacity(0.14),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .foregroundStyle(isPressed ? Color.white : Color.primary)
    }
}

private struct KeyboardCleaningSetupPanel: View {
    let state: KeyboardCleaningModel.State
    let accessibilityGranted: Bool
    let lock: () -> Void
    let openAccessibilitySettings: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Label(
                "Blocks keyboard, trackpad, mouse, and scrolling input.",
                systemImage: "hand.raised"
            )
            .font(.headline)

            Text("Before locking, make sure both Command keys are accessible and working.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if case .permissionRequired = state {
                KeyboardCleaningPermissionNotice(openSettings: openAccessibilitySettings)
            } else if case .failed(let message) = state {
                Text(message)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button("Start Cleaning Mode", systemImage: "lock.fill", action: lock)
                .buttonStyle(.glassProminent)
                .controlSize(.large)

            if !accessibilityGranted {
                Text("Accessibility permission is required to block system-wide input.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: 460)
    }
}

private struct KeyboardCleaningPermissionNotice: View {
    let openSettings: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text("Allow this app in System Settings → Privacy & Security → Accessibility, then return and start cleaning mode again.")
                .multilineTextAlignment(.center)

            Button("Open Accessibility Settings", action: openSettings)
        }
        .padding()
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    KeyboardCleaningView(model: KeyboardCleaningModel())
}
